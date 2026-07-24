/**
 * Тесты тика планировщика авторелиза глав: главы с isReleased=false и
 * releasedAt<=now релизятся, releasedChapters пересчитывается, кеш инвалидируется.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

const mocks = vi.hoisted(() => {
  type ChapterRow = {
    id: string;
    novelId: string;
    number: number;
    isReleased: boolean;
    releasedAt: Date | null;
  };

  const state = {
    chapters: [] as ChapterRow[],
    novels: new Map<string, { id: string; releasedChapters: number }>(),
  };

  function resetState() {
    state.chapters = [];
    state.novels = new Map();
  }

  const prismaMock: any = {
    chapter: {
      findMany: async ({ where }: any) => {
        const lte: Date | undefined = where?.releasedAt?.lte;
        return state.chapters
          .filter(
            (c) =>
              c.isReleased === where.isReleased &&
              c.releasedAt !== null &&
              (lte === undefined || c.releasedAt <= lte)
          )
          .map((c) => ({ id: c.id, novelId: c.novelId, number: c.number }));
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const c of state.chapters) {
          if (where.id?.in && !where.id.in.includes(c.id)) continue;
          if (data.isReleased !== undefined) c.isReleased = data.isReleased;
          count++;
        }
        return { count };
      },
      count: async ({ where }: any) =>
        state.chapters.filter((c) => c.novelId === where.novelId && c.isReleased === where.isReleased)
          .length,
    },
    novel: {
      update: async ({ where, data }: any) => {
        const n = state.novels.get(where.id) ?? { id: where.id, releasedChapters: 0 };
        if (data.releasedChapters !== undefined) n.releasedChapters = data.releasedChapters;
        state.novels.set(where.id, n);
        return n;
      },
    },
    $transaction: async (fn: any) => fn(prismaMock),
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));
vi.mock('../utils/zip-cache', () => ({ invalidateNovelZipCache: vi.fn() }));

import { releaseDueChaptersTick } from '../scheduler';
import { invalidateNovelZipCache } from '../utils/zip-cache';

beforeEach(() => {
  resetState();
  vi.mocked(invalidateNovelZipCache).mockClear();
});

describe('Scheduler — releaseDueChaptersTick', () => {
  it('релизит главы с наступившим releasedAt и пересчитывает releasedChapters', async () => {
    const past = new Date(Date.now() - 60_000);
    const future = new Date(Date.now() + 86400_000);
    state.chapters = [
      { id: 'c1', novelId: 'novel_a', number: 1, isReleased: true, releasedAt: past },
      { id: 'c2', novelId: 'novel_a', number: 2, isReleased: false, releasedAt: past },
      { id: 'c3', novelId: 'novel_a', number: 3, isReleased: false, releasedAt: future },
      { id: 'c4', novelId: 'novel_b', number: 1, isReleased: false, releasedAt: null }, // не запланирована
    ];

    const released = await releaseDueChaptersTick();

    expect(released).toEqual([{ novelId: 'novel_a', number: 2 }]);
    expect(state.chapters.find((c) => c.id === 'c2')!.isReleased).toBe(true);
    expect(state.chapters.find((c) => c.id === 'c3')!.isReleased).toBe(false);
    expect(state.chapters.find((c) => c.id === 'c4')!.isReleased).toBe(false);
    // releasedChapters: c1 + c2
    expect(state.novels.get('novel_a')!.releasedChapters).toBe(2);
    // Кеш released-ZIP инвалидирован только для затронутой новеллы.
    expect(invalidateNovelZipCache).toHaveBeenCalledTimes(1);
    expect(invalidateNovelZipCache).toHaveBeenCalledWith('novel_a');
  });

  it('группирует по новеллам и инвалидирует каждую', async () => {
    const past = new Date(Date.now() - 1000);
    state.chapters = [
      { id: 'a1', novelId: 'novel_a', number: 1, isReleased: false, releasedAt: past },
      { id: 'b1', novelId: 'novel_b', number: 1, isReleased: false, releasedAt: past },
    ];

    const released = await releaseDueChaptersTick();
    expect(released).toHaveLength(2);
    expect(invalidateNovelZipCache).toHaveBeenCalledWith('novel_a');
    expect(invalidateNovelZipCache).toHaveBeenCalledWith('novel_b');
  });

  it('no-op при отсутствии глав к релизу', async () => {
    state.chapters = [
      { id: 'c1', novelId: 'n', number: 1, isReleased: false, releasedAt: new Date(Date.now() + 3600_000) },
    ];
    const released = await releaseDueChaptersTick();
    expect(released).toEqual([]);
    expect(invalidateNovelZipCache).not.toHaveBeenCalled();
  });
});
