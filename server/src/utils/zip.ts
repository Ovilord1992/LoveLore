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
