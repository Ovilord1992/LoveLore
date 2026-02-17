import AdmZip from 'adm-zip';
import path from 'path';

/** Извлечь meta.json из ZIP-файла новеллы */
export function extractMetaFromZip(zipPath: string): Record<string, unknown> | null {
  try {
    const zip = new AdmZip(zipPath);
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
  try {
    const zip = new AdmZip(zipPath);
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
  try {
    const zip = new AdmZip(zipPath);
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
