import JSZip from 'jszip';
import { saveAs } from 'file-saver';
import type { NovelProject } from '../types/novel';

/** Экспортировать проект как ZIP-пакет, готовый для Amoria */
export async function exportAsZip(project: NovelProject, images: Map<string, File>): Promise<void> {
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

  // Изображения: backgrounds/, sprites/, cg/
  for (const [path, file] of images) {
    zip.file(path, file);
  }

  // Генерируем ZIP
  const blob = await zip.generateAsync({ type: 'blob' });
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

/** Импортировать проект из ZIP-файла */
export async function importProjectFromZip(file: File): Promise<{ project: NovelProject; images: Map<string, File> }> {
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

  // Загрузить изображения
  const images = new Map<string, File>();
  const imageDirs = ['backgrounds/', 'sprites/', 'cg/'];

  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir) continue;
    const relative = path.startsWith(prefix) ? path.slice(prefix.length) : path;
    const isImage = imageDirs.some((d) => relative.startsWith(d)) &&
      /\.(png|jpg|jpeg|webp|gif)$/i.test(relative);
    // Также подхватить cover в корне
    const isCover = relative === 'cover.png' || relative === 'cover.jpg';
    if (isImage || isCover) {
      const blob = await entry.async('blob');
      const ext = relative.split('.').pop() || 'png';
      const mimeType = ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' : ext === 'webp' ? 'image/webp' : ext === 'gif' ? 'image/gif' : 'image/png';
      const f = new File([blob], relative.split('/').pop() || relative, { type: mimeType });
      images.set(relative, f);
    }
  }

  const project: NovelProject = {
    meta: { ...meta, totalChapters: chapters.length },
    characters,
    variables,
    chapters,
  };

  return { project, images };
}

/** Экспортировать проект как единый JSON */
export function exportAsJson(project: NovelProject): void {
  const json = JSON.stringify(project, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  saveAs(blob, `${project.meta.id}.json`);
}
