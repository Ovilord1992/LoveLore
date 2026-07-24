/**
 * Тесты ретеншна и воронки (спека 4.4): форма ответа на мокнутом raw SQL,
 * d1/d7/d30 = null для неполных когорт.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

const mocks = vi.hoisted(() => {
  const state = {
    retentionRows: [] as unknown[],
    novelStartRows: [] as unknown[],
    funnelRows: [] as unknown[],
    queries: [] as { sql: string; values: unknown[] }[],
  };

  function resetState() {
    state.retentionRows = [];
    state.novelStartRows = [];
    state.funnelRows = [];
    state.queries = [];
  }

  const prismaMock: any = {
    // Tagged template: prisma.$queryRaw`...${x}...`
    $queryRaw: async (strings: TemplateStringsArray, ...values: unknown[]) => {
      const sql = strings.join('?');
      state.queries.push({ sql, values });
      if (sql.includes("'session_start'")) return state.retentionRows;
      if (sql.includes("'novel_start'")) return state.novelStartRows;
      if (sql.includes("'chapter_start'")) return state.funnelRows;
      return [];
    },
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

import { getRetentionCohorts, getNovelFunnel } from '../analytics/queries';

beforeEach(resetState);

describe('Analytics — retention (когорты)', () => {
  const NOW = new Date('2026-07-24T12:00:00Z');

  it('возвращает форму { date, installs, d1, d7, d30 } для полных когорт', async () => {
    state.retentionRows = [{ date: '2026-06-01', installs: 100, d1: 40, d7: 20, d30: 10 }];

    const cohorts = await getRetentionCohorts(60, NOW);
    expect(cohorts).toEqual([{ date: '2026-06-01', installs: 100, d1: 40, d7: 20, d30: 10 }]);
  });

  it('dN = null для неполных когорт (день date+N ещё не завершился)', async () => {
    state.retentionRows = [
      { date: '2026-06-20', installs: 80, d1: 30, d7: 15, d30: 5 }, // d30 → 07-20 < 07-24: полная
      { date: '2026-07-22', installs: 50, d1: 20, d7: 6, d30: 1 }, // d1 полная, d7/d30 — нет
      { date: '2026-07-23', installs: 30, d1: 12, d7: 0, d30: 0 }, // d1 = сегодня → null
    ];

    const cohorts = await getRetentionCohorts(30, NOW);
    expect(cohorts).toEqual([
      { date: '2026-06-20', installs: 80, d1: 30, d7: 15, d30: 5 },
      { date: '2026-07-22', installs: 50, d1: 20, d7: null, d30: null },
      { date: '2026-07-23', installs: 30, d1: null, d7: null, d30: null },
    ]);
  });

  it('передаёт окно since в SQL-запрос', async () => {
    await getRetentionCohorts(30, NOW);
    expect(state.queries).toHaveLength(1);
    const since = state.queries[0]!.values[0] as Date;
    expect(since.getTime()).toBe(NOW.getTime() - 30 * 24 * 60 * 60 * 1000);
  });

  it('пустая аналитика → пустой список когорт', async () => {
    expect(await getRetentionCohorts(30, NOW)).toEqual([]);
  });
});

describe('Analytics — funnel (воронка новеллы)', () => {
  it('возвращает { novelId, novelStarts, chapters[{chapter, starts, completes}] }', async () => {
    state.novelStartRows = [{ count: 12 }];
    state.funnelRows = [
      { chapter: 1, starts: 10, completes: 8 },
      { chapter: 2, starts: 7, completes: 5 },
    ];

    const funnel = await getNovelFunnel('n1');
    expect(funnel).toEqual({
      novelId: 'n1',
      novelStarts: 12,
      chapters: [
        { chapter: 1, starts: 10, completes: 8 },
        { chapter: 2, starts: 7, completes: 5 },
      ],
    });
  });

  it('фильтрует по novelId в обоих запросах', async () => {
    state.novelStartRows = [{ count: 0 }];
    await getNovelFunnel('novel-xyz');
    expect(state.queries).toHaveLength(2);
    for (const q of state.queries) {
      expect(q.values).toContain('novel-xyz');
    }
  });

  it('нет событий → novelStarts 0 и пустые chapters', async () => {
    const funnel = await getNovelFunnel('n1');
    expect(funnel).toEqual({ novelId: 'n1', novelStarts: 0, chapters: [] });
  });
});
