import AdmZip from 'adm-zip';
import path from 'path';

const MAX_UNCOMPRESSED_SIZE = 1024 * 1024 * 1024; // 1 GB

/** Защита от zip-bomb: проверяем суммарный распакованный размер архива */
function checkZipSize(zip: AdmZip): void {
  const entries = zip.getEntries();
  let total = 0;
  for (const entry of entries) {
    total += entry.header.size;
    if (total > MAX_UNCOMPRESSED_SIZE) {
      throw new Error(`ZIP exceeds max uncompressed size (${MAX_UNCOMPRESSED_SIZE} bytes)`);
    }
  }
}

/** Извлечь meta.json из ZIP-файла новеллы */
export function extractMetaFromZip(zipPath: string): Record<string, unknown> | null {
  const zip = new AdmZip(zipPath);
  checkZipSize(zip);
  try {
    const entries = zip.getEntries();

    // Ищем meta.json (может быть в корне или в подпапке)
    const metaEntry = entries.find(
      (e) => e.entryName === 'meta.json' || e.entryName.endsWith('/meta.json')
    );

    if (!metaEntry) return null;

    const content = metaEntry.getData().toString('utf-8');
    return JSON.parse(content);
  } catch {
    return null;
  }
}

/** Извлечь обложку из ZIP и сохранить в uploads/covers/ */
export function extractCoverFromZip(
  zipPath: string,
  coverFilename: string,
  outputDir: string
): string | null {
  const zip = new AdmZip(zipPath);
  checkZipSize(zip);
  try {
    const entries = zip.getEntries();

    // Ищем файл обложки (cover.png, cover.jpg, etc.)
    const coverEntry = entries.find(
      (e) =>
        e.entryName.includes('cover.') ||
        e.entryName.includes('обложка.')
    );

    if (!coverEntry) return null;

    const ext = path.extname(coverEntry.entryName);
    const outName = `${coverFilename}${ext}`;
    const outPath = path.join(outputDir, outName);

    const data = coverEntry.getData();
    require('fs').writeFileSync(outPath, data);

    return outName;
  } catch {
    return null;
  }
}

/** Извлечь информацию о главах из ZIP */
export function extractChaptersFromZip(
  zipPath: string
): { number: number; title: string }[] {
  const zip = new AdmZip(zipPath);
  checkZipSize(zip);
  try {
    const entries = zip.getEntries();
    const chapters: { number: number; title: string }[] = [];

    for (const entry of entries) {
      if (
        entry.entryName.includes('chapters/') &&
        entry.entryName.endsWith('.json') &&
        !entry.isDirectory
      ) {
        try {
          const content = JSON.parse(entry.getData().toString('utf-8'));
          const num = content.number ?? parseInt(entry.entryName.match(/(\d+)/)?.[1] || '0');
          chapters.push({
            number: num,
            title: content.title || `Глава ${num}`,
          });
        } catch {
          // skip invalid JSON
        }
      }
    }

    return chapters.sort((a, b) => a.number - b.number);
  } catch {
    return [];
  }
}

/** Извлечь JSON одной главы из ZIP */
export function extractChapterJsonFromZip(
  zipPath: string,
  chapterNumber: number
): string | null {
  try {
    const zip = new AdmZip(zipPath);
    const entries = zip.getEntries();

    const chapterEntry = entries.find(
      (e) =>
        e.entryName.includes(`chapters/chapter_${chapterNumber}.json`) ||
        e.entryName.includes(`chapters/ch${chapterNumber}.json`)
    );

    if (!chapterEntry) return null;
    return chapterEntry.getData().toString('utf-8');
  } catch {
    return null;
  }
}

/** Извлечь список доступных переводов из ZIP */
export function extractTranslationLanguagesFromZip(zipPath: string): string[] {
  try {
    const zip = new AdmZip(zipPath);
    const entries = zip.getEntries();
    const langs: string[] = [];

    for (const entry of entries) {
      if (
        entry.entryName.includes('translations/') &&
        entry.entryName.endsWith('.json') &&
        !entry.isDirectory
      ) {
        const fileName = entry.entryName.split('/').pop() || '';
        const lang = fileName.replace('.json', '');
        if (lang) langs.push(lang);
      }
    }

    return langs;
  } catch {
    return [];
  }
}

/** Извлечь перевод на конкретный язык из ZIP */
export function extractTranslationFromZip(
  zipPath: string,
  language: string
): string | null {
  try {
    const zip = new AdmZip(zipPath);
    const entries = zip.getEntries();

    const translationEntry = entries.find(
      (e) =>
        e.entryName === `translations/${language}.json` ||
        e.entryName.endsWith(`/translations/${language}.json`)
    );

    if (!translationEntry) return null;
    return translationEntry.getData().toString('utf-8');
  } catch {
    return null;
  }
}

/** Добавить/обновить перевод в ZIP */
export function addTranslationToZip(
  zipPath: string,
  language: string,
  translationJson: string
): void {
  const zip = new AdmZip(zipPath);
  zip.addFile(`translations/${language}.json`, Buffer.from(translationJson, 'utf-8'));
  zip.writeZip(zipPath);
}

/**
 * Вставить/заменить JSON главы внутри ZIP (по образцу addTranslationToZip).
 * Учитывает возможную вложенную папку (кладёт рядом с meta.json).
 */
export function upsertChapterInZip(
  zipPath: string,
  chapterNumber: number,
  chapterJson: string
): void {
  const zip = new AdmZip(zipPath);
  checkZipSize(zip);
  const entries = zip.getEntries();
  const data = Buffer.from(chapterJson, 'utf-8');

  const existing = entries.find(
    (e) =>
      e.entryName === `chapters/chapter_${chapterNumber}.json` ||
      e.entryName.endsWith(`/chapters/chapter_${chapterNumber}.json`) ||
      e.entryName === `chapters/ch${chapterNumber}.json` ||
      e.entryName.endsWith(`/chapters/ch${chapterNumber}.json`)
  );

  if (existing) {
    const name = existing.entryName;
    zip.deleteFile(name);
    zip.addFile(name, data);
  } else {
    const metaEntry = entries.find(
      (e) => e.entryName === 'meta.json' || e.entryName.endsWith('/meta.json')
    );
    const prefix = metaEntry
      ? metaEntry.entryName.slice(0, metaEntry.entryName.length - 'meta.json'.length)
      : '';
    zip.addFile(`${prefix}chapters/chapter_${chapterNumber}.json`, data);
  }

  zip.writeZip(zipPath);
}

/** Извлечь все переводы (язык + содержимое) из ZIP. */
export function extractAllTranslationsFromZip(
  zipPath: string
): { language: string; content: string }[] {
  try {
    const zip = new AdmZip(zipPath);
    const entries = zip.getEntries();
    const out: { language: string; content: string }[] = [];

    for (const entry of entries) {
      if (
        entry.entryName.includes('translations/') &&
        entry.entryName.endsWith('.json') &&
        !entry.isDirectory
      ) {
        const fileName = entry.entryName.split('/').pop() || '';
        const lang = fileName.replace('.json', '');
        if (lang) out.push({ language: lang, content: entry.getData().toString('utf-8') });
      }
    }

    return out;
  } catch {
    return [];
  }
}

/**
 * Определить номер главы для entry вида `chapters/*.json`.
 * Возвращает null, если entry не является JSON-файлом главы.
 * readData вызывается лениво — только для entry, похожих на главу.
 */
function chapterNumberOfEntry(entryName: string, readData: () => Buffer): number | null {
  if (!entryName.includes('chapters/') || !entryName.endsWith('.json')) {
    return null;
  }
  try {
    const content = JSON.parse(readData().toString('utf-8'));
    if (typeof content.number === 'number') return content.number;
  } catch {
    // fall through to filename parsing
  }
  const m = entryName.match(/(\d+)/);
  return m ? parseInt(m[1], 10) : null;
}

/**
 * Пересобрать ZIP, оставив только выпущенные главы.
 *
 * Файлы `chapters/*.json`, номер которых отсутствует в releasedNumbers,
 * исключаются. Все прочие файлы (meta.json, обложка, спрайты, фоны,
 * переводы, выпущенные главы) сохраняются как есть. Возвращает буфер
 * пересобранного архива.
 */
export function buildReleasedZipBuffer(
  zipPath: string,
  releasedNumbers: Set<number>
): Buffer {
  const zip = new AdmZip(zipPath);
  checkZipSize(zip);
  const out = new AdmZip();

  for (const entry of zip.getEntries()) {
    if (entry.isDirectory) continue;
    const chapterNum = chapterNumberOfEntry(entry.entryName, () => entry.getData());
    if (chapterNum !== null && !releasedNumbers.has(chapterNum)) {
      continue; // невыпущенная глава — не включаем
    }
    out.addFile(entry.entryName, entry.getData());
  }

  return out.toBuffer();
}

/**
 * Есть ли в ZIP главы (`chapters/*.json`), номер которых отсутствует в releasedNumbers.
 * Используется для выбора быстрого пути (стриминг исходника) vs пересборки.
 */
export function zipHasUnreleasedChapters(
  zipPath: string,
  releasedNumbers: Set<number>
): boolean {
  const zip = new AdmZip(zipPath);
  checkZipSize(zip);
  for (const entry of zip.getEntries()) {
    if (entry.isDirectory) continue;
    const chapterNum = chapterNumberOfEntry(entry.entryName, () => entry.getData());
    if (chapterNum !== null && !releasedNumbers.has(chapterNum)) {
      return true;
    }
  }
  return false;
}
