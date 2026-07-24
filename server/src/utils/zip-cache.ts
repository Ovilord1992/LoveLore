import fs from 'fs';
import path from 'path';
import { buildReleasedZipBuffer } from './zip';
import { logger } from './logger';

/**
 * Файловый кеш пересобранных «released» ZIP-архивов (uploads/cache/).
 * Ключ — <novelId>-v<version>-r<releasedCount>.zip: любое изменение контента
 * (version++) или состава выпущенных глав меняет имя файла. Инвалидация
 * удаляет все файлы новеллы из кеша.
 */

const uploadDir = process.env.UPLOAD_DIR || './uploads';
const cacheDir = path.join(uploadDir, 'cache');

export function releasedZipCachePath(novelId: string, version: number, releasedCount: number): string {
  return path.join(cacheDir, `${novelId}-v${version}-r${releasedCount}.zip`);
}

/** Вернуть путь к кешированному released-ZIP, собрав его при отсутствии. */
export function getOrBuildReleasedZip(
  zipPath: string,
  novelId: string,
  version: number,
  releasedNumbers: Set<number>
): string {
  fs.mkdirSync(cacheDir, { recursive: true });
  const cachePath = releasedZipCachePath(novelId, version, releasedNumbers.size);
  if (fs.existsSync(cachePath)) return cachePath;

  const buffer = buildReleasedZipBuffer(zipPath, releasedNumbers);
  // Пишем во временный файл + rename, чтобы параллельные запросы не читали недописанный кеш.
  const tmpPath = `${cachePath}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tmpPath, buffer);
  fs.renameSync(tmpPath, cachePath);
  logger.info({ novelId, version, released: releasedNumbers.size }, '[zip-cache] built released zip');
  return cachePath;
}

/** Удалить из кеша все файлы новеллы (загрузка/перезаливка/релиз/upsert главы). */
export function invalidateNovelZipCache(novelId: string): void {
  try {
    if (!fs.existsSync(cacheDir)) return;
    for (const file of fs.readdirSync(cacheDir)) {
      if (file.startsWith(`${novelId}-v`)) {
        fs.unlinkSync(path.join(cacheDir, file));
      }
    }
  } catch (err) {
    logger.warn({ err, novelId }, '[zip-cache] invalidation failed');
  }
}
