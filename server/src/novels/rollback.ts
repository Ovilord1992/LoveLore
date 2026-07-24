import fs from 'fs';
import path from 'path';
import prisma from '../db';
import { extractChaptersFromZip } from '../utils/zip';
import { invalidateNovelZipCache } from '../utils/zip-cache';
import { mergeChapterReleaseState } from '../utils/chapters';
import { archiveCurrentZip, resolveInUploads } from './archive';
import { logger } from '../utils/logger';

/**
 * Откат новеллы к версии из истории (спека 4.3): восстановление ZIP,
 * повторное извлечение глав с merge release-состояния (как при перезаливке),
 * version++ (история линейна, как у конфига), запись текущего состояния
 * в историю перед откатом, инвалидация ZIP-кеша.
 */

export type NovelRollbackResult =
  | {
      ok: true;
      rolledBackTo: number;
      novel: { id: string; version: number; chaptersCount: number; releasedChapters: number };
    }
  | { ok: false; error: 'novel_not_found' | 'version_not_found' };

export async function rollbackNovelToVersion(
  novelId: string,
  targetVersion: number
): Promise<NovelRollbackResult> {
  const novel = await prisma.novel.findUnique({ where: { id: novelId } });
  if (!novel || !novel.zipFilename) return { ok: false, error: 'novel_not_found' };

  const archive = await prisma.novelArchive.findUnique({
    where: { novelId_version: { novelId, version: targetVersion } },
  });
  if (!archive) return { ok: false, error: 'version_not_found' };

  const zipPath = resolveInUploads(path.join('packs', novel.zipFilename));
  const archivePath = resolveInUploads(archive.filePath);
  if (!zipPath || !archivePath || !fs.existsSync(archivePath)) {
    return { ok: false, error: 'version_not_found' };
  }

  // Читаем целевой архив ДО архивирования текущего: ротация истории могла бы
  // удалить файл целевой версии как самый старший.
  const archiveBuffer = fs.readFileSync(archivePath);

  // Текущее состояние — в историю перед откатом.
  if (fs.existsSync(zipPath)) {
    await archiveCurrentZip(novelId, novel.version, zipPath);
  }

  // Восстановление ZIP.
  fs.mkdirSync(path.dirname(zipPath), { recursive: true });
  fs.writeFileSync(zipPath, archiveBuffer);

  // Повторное извлечение глав + merge release-состояния (как при перезаливке).
  const chapterInfos = extractChaptersFromZip(zipPath);
  const existingChapters = await prisma.chapter.findMany({
    where: { novelId },
    select: { number: true, isReleased: true, releasedAt: true },
  });
  const merge = mergeChapterReleaseState(chapterInfos, existingChapters, false);

  for (const ch of merge.chapters) {
    await prisma.chapter.upsert({
      where: { novelId_number: { novelId, number: ch.number } },
      update: { title: ch.title },
      create: {
        novelId,
        number: ch.number,
        title: ch.title,
        isReleased: ch.isReleased,
        releasedAt: ch.releasedAt,
      },
    });
  }
  if (merge.removedNumbers.length > 0) {
    await prisma.chapter.deleteMany({
      where: { novelId, number: { in: merge.removedNumbers } },
    });
  }

  const updated = await prisma.novel.update({
    where: { id: novelId },
    data: {
      version: { increment: 1 },
      chaptersCount: merge.chapters.length,
      releasedChapters: merge.releasedCount,
      fileSize: fs.statSync(zipPath).size,
    },
    select: { id: true, version: true, chaptersCount: true, releasedChapters: true },
  });

  invalidateNovelZipCache(novelId);
  logger.info({ novelId, rolledBackTo: targetVersion, newVersion: updated.version }, '[novel-archive] rollback complete');

  return { ok: true, rolledBackTo: targetVersion, novel: updated };
}
