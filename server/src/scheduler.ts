import prisma from './db';
import { logger } from './utils/logger';
import { invalidateNovelZipCache } from './utils/zip-cache';

/**
 * Планировщик авторелиза глав: главы с isReleased=false и releasedAt<=now
 * автоматически релизятся + пересчёт releasedChapters + инвалидация ZIP-кеша.
 * Тик вынесен в чистую функцию для тестов; запускается из index.ts (не в тестах).
 */

export interface ReleasedChapterInfo {
  novelId: string;
  number: number;
}

export async function releaseDueChaptersTick(now: Date = new Date()): Promise<ReleasedChapterInfo[]> {
  const due = await prisma.chapter.findMany({
    where: { isReleased: false, releasedAt: { lte: now } },
    select: { id: true, novelId: true, number: true },
  });
  if (due.length === 0) return [];

  const byNovel = new Map<string, { ids: string[]; numbers: number[] }>();
  for (const ch of due) {
    const group = byNovel.get(ch.novelId) ?? { ids: [], numbers: [] };
    group.ids.push(ch.id);
    group.numbers.push(ch.number);
    byNovel.set(ch.novelId, group);
  }

  for (const [novelId, group] of byNovel) {
    await prisma.$transaction(async (db) => {
      await db.chapter.updateMany({
        where: { id: { in: group.ids } },
        data: { isReleased: true },
      });
      const releasedCount = await db.chapter.count({
        where: { novelId, isReleased: true },
      });
      await db.novel.update({
        where: { id: novelId },
        data: { releasedChapters: releasedCount },
      });
    });
    invalidateNovelZipCache(novelId);
    logger.info({ novelId, chapters: group.numbers }, '[scheduler] auto-released chapters');
  }

  return due.map((ch) => ({ novelId: ch.novelId, number: ch.number }));
}

let tickRunning = false;

export function startChapterReleaseScheduler(intervalMs: number = 60_000): NodeJS.Timeout {
  const timer = setInterval(async () => {
    if (tickRunning) return; // защита от наложения тиков
    tickRunning = true;
    try {
      await releaseDueChaptersTick();
    } catch (err) {
      logger.error({ err }, '[scheduler] chapter release tick failed');
    } finally {
      tickRunning = false;
    }
  }, intervalMs);
  timer.unref();
  logger.info({ intervalMs }, '[scheduler] chapter release scheduler started');
  return timer;
}
