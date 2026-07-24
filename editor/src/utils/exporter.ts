import JSZip from 'jszip';
import { saveAs } from 'file-saver';
import type { NovelProject, NovelTranslation } from '../types/novel';
import { validateProject } from './validator';

/** Убрать пустые строки перевода из всех карт: пустой перевод НЕ должен попасть
 *  в бандл, иначе на клиенте `texts[original] ?? original` подменит оригинал
 *  пустышкой. Отсутствие ключа = корректный fallback на оригинал. */
export function sanitizeTranslation(t: NovelTranslation): NovelTranslation {
  const texts: Record<string, string> = {};
  for (const [k, v] of Object.entries(t.texts || {})) {
    if (v && v.trim()) texts[k] = v;
  }
  const characters: Record<string, { name?: string }> = {};
  for (const [k, v] of Object.entries(t.characters || {})) {
    if (v?.name && v.name.trim()) characters[k] = { name: v.name };
  }
  const chapters: Record<string, { title?: string }> = {};
  for (const [k, v] of Object.entries(t.chapters || {})) {
    if (v?.title && v.title.trim()) chapters[k] = { title: v.title };
  }
  const novel: { title?: string; description?: string } = {};
  if (t.novel?.title && t.novel.title.trim()) novel.title = t.novel.title;
  if (t.novel?.description && t.novel.description.trim()) novel.description = t.novel.description;
  return { meta: t.meta, novel, characters, chapters, texts };
}

/** Структурные ошибки, блокирующие экспорт/публикацию (без проверки ассетов). */
export function blockingErrors(project: NovelProject): string[] {
  return validateProject(project)
    .filter((e) => e.type === 'error')
    .map((e) => e.message);
}

/** Собрать ZIP-пакет новеллы (meta/characters/variables/chapters/translations
 *  + все ассеты: картинки И аудио). Общий код для экспорта в файл и публикации. */
export async function buildZipBlob(project: NovelProject, assets: Map<string, File>): Promise<Blob> {
  const zip = new JSZip();

  // meta.json — в корне ZIP
  zip.file('meta.json', JSON.stringify(project.meta, null, 2));

  // characters.json
  zip.file(
    'characters.json',
    JSON.stringify({ characters: project.characters }, null, 2)
  );

  // variables.json
  zip.file('variables.json', JSON.stringify(project.variables, null, 2));

  // chapters/
  for (const chapter of project.chapters) {
    zip.file(
      `chapters/${chapter.id}.json`,
      JSON.stringify(chapter, null, 2)
    );
  }

  // translations/ — пустые строки перевода вычищаем перед записью
  if (project.translations) {
    for (const [lang, translation] of Object.entries(project.translations)) {
      zip.file(
        `translations/${lang}.json`,
        JSON.stringify(sanitizeTranslation(translation), null, 2)
      );
    }
  }

  // Ассеты: backgrounds/, sprites/, cg/, emotions/, music/, sounds/, voice/
  for (const [path, file] of assets) {
    zip.file(path, file);
  }

  return zip.generateAsync({ type: 'blob' });
}

/** Экспортировать проект как ZIP-пакет, готовый для Amoria */
export async function exportAsZip(project: NovelProject, assets: Map<string, File>): Promise<void> {
  // Блокируем экспорт при структурных ошибках (битые ссылки, недостижимая
  // firstSceneId, пустой nextSceneId у выбора и т.п.). Ассеты здесь НЕ проверяем
  // (assets не передаём в валидатор) — их отсутствие не должно мешать экспорту
  // текстовой новеллы; про потерянные файлы предупреждает live-валидация.
  const blocking = blockingErrors(project);
  if (blocking.length > 0) {
    alert(
      `Экспорт заблокирован — исправьте ${blocking.length} ошиб(ку/ки):\n\n` +
      blocking.map((e) => '• ' + e).join('\n')
    );
    return;
  }

  const blob = await buildZipBlob(project, assets);
  saveAs(blob, `${project.meta.id}.zip`);
}

/** Импортировать проект из JSON-файла */
export function importProject(file: File): Promise<NovelProject> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const project = JSON.parse(e.target?.result as string) as NovelProject;
        resolve(project);
      } catch {
        reject(new Error('Невалидный JSON'));
      }
    };
    reader.onerror = () => reject(new Error('Ошибка чтения файла'));
    reader.readAsText(file);
  });
}

const IMAGE_DIRS = ['backgrounds/', 'sprites/', 'cg/', 'emotions/'];
const AUDIO_DIRS = ['music/', 'sounds/', 'voice/'];
const IMAGE_RE = /\.(png|jpg|jpeg|webp|gif)$/i;
const AUDIO_RE = /\.(mp3|ogg|wav|m4a|aac)$/i;

function mimeFor(relative: string): string {
  const ext = (relative.split('.').pop() || '').toLowerCase();
  switch (ext) {
    case 'jpg': case 'jpeg': return 'image/jpeg';
    case 'webp': return 'image/webp';
    case 'gif': return 'image/gif';
    case 'png': return 'image/png';
    case 'mp3': return 'audio/mpeg';
    case 'ogg': return 'audio/ogg';
    case 'wav': return 'audio/wav';
    case 'm4a': return 'audio/mp4';
    case 'aac': return 'audio/aac';
    default: return 'application/octet-stream';
  }
}

/** Импортировать проект из ZIP-файла (включая картинки и аудио) */
export async function importProjectFromZip(file: File): Promise<{ project: NovelProject; assets: Map<string, File> }> {
  const zip = await JSZip.loadAsync(file);

  // Ищем meta.json — может быть в корне или в подпапке
  let prefix = '';
  if (!zip.file('meta.json')) {
    // Ищем в подпапках
    const metaEntry = Object.keys(zip.files).find((f) => f.endsWith('/meta.json') || f === 'meta.json');
    if (!metaEntry) throw new Error('meta.json не найден в ZIP');
    prefix = metaEntry.replace('meta.json', '');
  }

  const readJson = async (path: string) => {
    const entry = zip.file(prefix + path);
    if (!entry) return null;
    const text = await entry.async('text');
    return JSON.parse(text);
  };

  const meta = await readJson('meta.json');
  if (!meta) throw new Error('meta.json не найден');

  const charsData = await readJson('characters.json');
  const characters = charsData?.characters || [];

  const variables = (await readJson('variables.json')) || {};

  // Загрузить главы
  const chapters = [];
  const chaptersFolder = zip.folder(prefix + 'chapters');
  if (chaptersFolder) {
    const chapterFiles: string[] = [];
    chaptersFolder.forEach((relativePath, entry) => {
      if (!entry.dir && relativePath.endsWith('.json')) {
        chapterFiles.push(relativePath);
      }
    });
    chapterFiles.sort();
    for (const cf of chapterFiles) {
      const entry = zip.file(prefix + 'chapters/' + cf);
      if (entry) {
        const text = await entry.async('text');
        chapters.push(JSON.parse(text));
      }
    }
  }

  if (chapters.length === 0) throw new Error('Ни одной главы не найдено в ZIP');

  // Загрузить переводы
  const translations: Record<string, unknown> = {};
  const translationsFolder = zip.folder(prefix + 'translations');
  if (translationsFolder) {
    const translationFiles: string[] = [];
    translationsFolder.forEach((relativePath, entry) => {
      if (!entry.dir && relativePath.endsWith('.json')) {
        translationFiles.push(relativePath);
      }
    });
    for (const tf of translationFiles) {
      const entry = zip.file(prefix + 'translations/' + tf);
      if (entry) {
        const text = await entry.async('text');
        const lang = tf.replace('.json', '');
        translations[lang] = JSON.parse(text);
      }
    }
  }

  // Загрузить ассеты: картинки + аудио
  const assets = new Map<string, File>();

  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir) continue;
    const relative = path.startsWith(prefix) ? path.slice(prefix.length) : path;
    const isImage = IMAGE_DIRS.some((d) => relative.startsWith(d)) && IMAGE_RE.test(relative);
    const isAudio = AUDIO_DIRS.some((d) => relative.startsWith(d)) && AUDIO_RE.test(relative);
    // Также подхватить cover в корне
    const isCover = relative === 'cover.png' || relative === 'cover.jpg';
    if (isImage || isAudio || isCover) {
      const blob = await entry.async('blob');
      const f = new File([blob], relative.split('/').pop() || relative, { type: mimeFor(relative) });
      assets.set(relative, f);
    }
  }

  const project: NovelProject = {
    meta: { ...meta, chaptersCount: chapters.length },
    characters,
    variables,
    chapters,
    ...(Object.keys(translations).length > 0 ? { translations: translations as NovelProject['translations'] } : {}),
  };

  return { project, assets };
}

/** Экспортировать проект как единый JSON */
export function exportAsJson(project: NovelProject): void {
  const json = JSON.stringify(project, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  saveAs(blob, `${project.meta.id}.json`);
}

/** Скачать перевод одного языка как translations/<lang>.json */
export function exportTranslationFile(lang: string, translation: NovelTranslation): void {
  const json = JSON.stringify(sanitizeTranslation(translation), null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  saveAs(blob, `${lang}.json`);
}

/** Прочитать файл translations/<lang>.json (загрузка перевода). */
export function importTranslationFile(file: File): Promise<NovelTranslation> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const parsed = JSON.parse(e.target?.result as string) as Partial<NovelTranslation>;
        if (!parsed || typeof parsed !== 'object' || typeof parsed.texts !== 'object' || parsed.texts === null) {
          reject(new Error('Файл не похож на перевод: нет карты "texts"'));
          return;
        }
        resolve(parsed as NovelTranslation);
      } catch {
        reject(new Error('Невалидный JSON'));
      }
    };
    reader.onerror = () => reject(new Error('Ошибка чтения файла'));
    reader.readAsText(file);
  });
}
