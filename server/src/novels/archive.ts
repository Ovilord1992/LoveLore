import fs from 'fs';
import path from 'path';
import prisma from '../db';
import { logger } from '../utils/logger';

/**
 * История версий ZIP-архивов новелл (спека 4.3).
 *
 * Перед каждой перезаписью ZIP (перезаливка новеллы, upsert главы, откат)
 * текущий архив копируется в uploads/history/<novelId>/v<version>.zip +
 * строка NovelArchive. Храним последние MAX_ARCHIVE_VERSIONS версий —
 * старшие удаляются вместе с файлами.
 *
 * UPLOAD_DIR читается при вызове (не на уровне модуля) — для тестов.
 */

export const MAX_ARCHIVE_VERSIONS = 5;

function uploadRoot(): string {
  return path.resolve(process.env.UPLOAD_DIR || './uploads');
}

/** Относительный (от UPLOAD_DIR) путь файла архива — хранится в NovelArchive.filePath. */
export function archiveRelPath(novelId: string, version: number): string {
  return path.join('history', novelId, `v${version}.zip`);
}

/**
 * Абсолютный путь внутри UPLOAD_DIR с защитой от path traversal
 * (по образцу проверок в routes/novels.ts).
 */
export function resolveInUploads(relPath: string): string | null {
  const root = uploadRoot();
  const resolved = path.resolve(root, relPath);
  if (!resolved.startsWith(root + path.sep)) {
    logger.warn({ relPath }, '[novel-archive] path traversal detected — skipping');
    return null;
  }
  return resolved;
}

/**
 * Скопировать текущий ZIP новеллы в историю под номером version + запись
 * NovelArchive; отротировать историю до MAX_ARCHIVE_VERSIONS.
 * Возвращает false, если исходный файл отсутствует или путь небезопасен.
 */
export async function archiveCurrentZip(
  novelId: string,
  version: number,
  zipPath: string
): Promise<boolean> {
  if (!fs.existsSync(zipPath)) return false;

  const relPath = archiveRelPath(novelId, version);
  const destPath = resolveInUploads(relPath);
  if (!destPath) return false;

  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  fs.copyFileSync(zipPath, destPath);
  const sizeBytes = fs.statSync(destPath).size;

  await prisma.novelArchive.upsert({
    where: { novelId_version: { novelId, version } },
    update: { filePath: relPath, sizeBytes },
    create: { novelId, version, filePath: relPath, sizeBytes },
  });

  await pruneArchives(novelId);
  logger.info({ novelId, version, sizeBytes }, '[novel-archive] version archived');
  return true;
}

/** Удалить версии старше последних MAX_ARCHIVE_VERSIONS (строки + файлы). */
export async function pruneArchives(novelId: string): Promise<void> {
  const stale = await prisma.novelArchive.findMany({
    where: { novelId },
    orderBy: { version: 'desc' },
    skip: MAX_ARCHIVE_VERSIONS,
  });
  if (stale.length === 0) return;

  for (const row of stale) {
    const filePath = resolveInUploads(row.filePath);
    if (filePath && fs.existsSync(filePath)) {
      try {
        fs.unlinkSync(filePath);
      } catch (err) {
        logger.warn({ err, novelId, version: row.version }, '[novel-archive] failed to delete archive file');
      }
    }
  }
  await prisma.novelArchive.deleteMany({ where: { id: { in: stale.map((r) => r.id) } } });
}

/** Удалить всю историю новеллы (файлы; строки каскадятся с Novel). */
export function removeArchiveDir(novelId: string): void {
  const dir = resolveInUploads(path.join('history', novelId));
  if (!dir) return;
  try {
    fs.rmSync(dir, { recursive: true, force: true });
  } catch (err) {
    logger.warn({ err, novelId }, '[novel-archive] failed to remove history dir');
  }
}
