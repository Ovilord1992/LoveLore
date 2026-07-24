/**
 * Тесты zod-валидации GameConfig и истории/отката (спека 2.4).
 * Валидация — чистые функции; история/rollback — mock-prisma (паттерн iap.test.ts).
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const mocks = vi.hoisted(() => {
  type ConfigRow = {
    id: string;
    version: number;
    economy: unknown;
    ads: unknown;
    iap: unknown;
    vip: unknown;
    daily: unknown;
    achievements: unknown;
    localization: unknown;
    experiments: unknown;
    segments: unknown;
  };
  type HistoryRow = { id: string; version: number; data: unknown; changedBy: string; createdAt: Date };

  const state = {
    config: null as ConfigRow | null,
    history: [] as HistoryRow[],
  };

  function resetState() {
    state.config = null;
    state.history = [];
  }

  const randomUuid = () =>
    (globalThis as unknown as { crypto: { randomUUID: () => string } }).crypto.randomUUID();

  const prismaMock: any = {
    gameConfig: {
      findUnique: async () => state.config,
      upsert: async ({ update, create }: any) => {
        if (state.config) {
          for (const key of ['version', 'economy', 'ads', 'iap', 'vip', 'daily', 'achievements', 'localization', 'experiments', 'segments']) {
            if (update[key] !== undefined) (state.config as any)[key] = update[key];
          }
          return state.config;
        }
        state.config = { id: 'singleton', ...create };
        return state.config;
      },
    },
    configHistory: {
      create: async ({ data }: any) => {
        if (state.history.some((h) => h.version === data.version)) {
          const err = new Error('Unique constraint failed') as Error & { code: string };
          err.code = 'P2002';
          throw err;
        }
        const row = { id: randomUuid(), createdAt: new Date(), ...data };
        state.history.push(row);
        return row;
      },
      findUnique: async ({ where }: any) =>
        state.history.find((h) => h.version === where.version) ?? null,
      findMany: async () => [...state.history].sort((a, b) => b.version - a.version),
    },
    $transaction: async (fn: any) => fn(prismaMock),
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

import { validateGameConfigInput } from '../config/schema';
import { saveConfigWithHistory, rollbackConfig } from '../config/service';

const validConfig = {
  economy: { maxTickets: 5, ticketRefillMinutes: 30, legacySyncCap: 1000 },
  ads: { maxAdsPerDay: 5, rewardAmount: 3, rewardedAdUnitIdAndroid: '', rewardedAdUnitIdIos: '' },
  iap: {
    diamonds_20: { diamonds: 20 },
    vip_monthly: { vipDays: 30 },
    products: [{ id: 'diamonds_20', usdCents: 199 }],
  },
  vip: { dailyDiamonds: 5, unlimitedTickets: true },
  daily: [{ day: 1, diamonds: 5, tickets: 0, label: '5' }],
  achievements: [{ id: 'first_story', title: 'Первая история', diamondReward: 10 }],
  localization: { ru: { app_title: 'Amoria' } },
};

describe('Config — zod-валидация', () => {
  let warnSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
  });
  afterEach(() => {
    warnSpy.mockRestore();
  });

  it('принимает валидный полный конфиг', () => {
    const r = validateGameConfigInput(validConfig);
    expect(r.ok).toBe(true);
  });

  it('принимает частичный конфиг (только одна секция)', () => {
    const r = validateGameConfigInput({ economy: { maxTickets: 7 } });
    expect(r.ok).toBe(true);
  });

  it('отклоняет нечисловой economy.maxTickets', () => {
    const r = validateGameConfigInput({ economy: { maxTickets: 'five' } });
    expect(r.ok).toBe(false);
    if (r.ok) return;
    expect(r.errors[0]!.message).toMatch(/economy\.maxTickets/);
  });

  it('отклоняет daily не-массив', () => {
    const r = validateGameConfigInput({ daily: { day: 1 } });
    expect(r.ok).toBe(false);
  });

  it('отклоняет битый iap.products', () => {
    const r = validateGameConfigInput({ iap: { products: [{ usdCents: 199 }] } });
    expect(r.ok).toBe(false);
  });

  it('отклоняет отрицательный usdCents и битую награду продукта', () => {
    expect(validateGameConfigInput({ iap: { products: [{ id: 'x', usdCents: -1 }] } }).ok).toBe(false);
    expect(validateGameConfigInput({ iap: { diamonds_20: { diamonds: 'many' } } }).ok).toBe(false);
  });

  it('неизвестные ключи внутри секции — warning, не отклонение', () => {
    const r = validateGameConfigInput({ economy: { maxTickets: 5, superNewField: 42 } });
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.warnings.some((w) => w.includes('economy.superNewField'))).toBe(true);
    expect(warnSpy).toHaveBeenCalled();
  });

  it('неизвестный top-level ключ — warning', () => {
    const r = validateGameConfigInput({ economy: {}, notASection: {} });
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.warnings.some((w) => w.includes('notASection'))).toBe(true);
  });
});

describe('Config — experiments/segments (спека 4.6)', () => {
  const validExperiments = [
    {
      id: 'price_test_1',
      enabled: true,
      variants: [
        { key: 'control', weight: 50, overrides: {} },
        { key: 'cheap', weight: 50, overrides: { 'economy.premiumChoiceBaseCost': 10 } },
      ],
    },
  ];
  const validSegments = [
    {
      id: 'ios_vip',
      conditions: { platform: 'ios', vip: true },
      overrides: { 'ads.maxAdsPerDay': 0 },
    },
  ];

  it('принимает валидные experiments и segments', () => {
    const r = validateGameConfigInput({ experiments: validExperiments, segments: validSegments });
    expect(r.ok).toBe(true);
  });

  it('принимает installedAfter/installedBefore как ISO-строки', () => {
    const r = validateGameConfigInput({
      segments: [
        {
          id: 'newcomers',
          conditions: { installedAfter: '2026-07-01T00:00:00Z', installedBefore: '2026-08-01T00:00:00Z' },
          overrides: {},
        },
      ],
    });
    expect(r.ok).toBe(true);
  });

  it('отклоняет вес варианта <= 0 и нецелый вес', () => {
    const withWeight = (weight: number) => [
      { id: 'e1', enabled: true, variants: [{ key: 'a', weight, overrides: {} }] },
    ];
    expect(validateGameConfigInput({ experiments: withWeight(0) }).ok).toBe(false);
    expect(validateGameConfigInput({ experiments: withWeight(-5) }).ok).toBe(false);
    expect(validateGameConfigInput({ experiments: withWeight(1.5) }).ok).toBe(false);
  });

  it('отклоняет дубликаты id экспериментов', () => {
    const r = validateGameConfigInput({
      experiments: [
        { id: 'dup', variants: [{ key: 'a', weight: 1 }] },
        { id: 'dup', variants: [{ key: 'a', weight: 1 }] },
      ],
    });
    expect(r.ok).toBe(false);
    if (r.ok) return;
    expect(r.errors.some((e) => e.message.includes('duplicate experiment id'))).toBe(true);
  });

  it('отклоняет дубликаты key вариантов внутри эксперимента', () => {
    const r = validateGameConfigInput({
      experiments: [
        {
          id: 'e1',
          variants: [
            { key: 'same', weight: 50 },
            { key: 'same', weight: 50 },
          ],
        },
      ],
    });
    expect(r.ok).toBe(false);
    if (r.ok) return;
    expect(r.errors.some((e) => e.message.includes('duplicate variant key'))).toBe(true);
  });

  it('отклоняет эксперимент без вариантов и без id', () => {
    expect(validateGameConfigInput({ experiments: [{ id: 'e1', variants: [] }] }).ok).toBe(false);
    expect(validateGameConfigInput({ experiments: [{ variants: [{ key: 'a', weight: 1 }] }] }).ok).toBe(false);
  });

  it('отклоняет неизвестную платформу, не-bool vip и битую дату сегмента', () => {
    expect(
      validateGameConfigInput({ segments: [{ id: 's1', conditions: { platform: 'windows' } }] }).ok
    ).toBe(false);
    expect(
      validateGameConfigInput({ segments: [{ id: 's1', conditions: { vip: 'yes' } }] }).ok
    ).toBe(false);
    expect(
      validateGameConfigInput({ segments: [{ id: 's1', conditions: { installedAfter: 'not-a-date' } }] }).ok
    ).toBe(false);
  });

  it('отклоняет дубликаты id сегментов', () => {
    const r = validateGameConfigInput({
      segments: [
        { id: 'dup', overrides: {} },
        { id: 'dup', overrides: {} },
      ],
    });
    expect(r.ok).toBe(false);
  });

  it('experiments/segments сохраняются и попадают в снапшот истории', async () => {
    resetState();
    await saveConfigWithHistory({ experiments: validExperiments, segments: validSegments }, 'admin-1');
    expect(state.config!.experiments).toEqual(validExperiments);
    expect(state.config!.segments).toEqual(validSegments);
    expect((state.history[0]!.data as any).experiments).toEqual(validExperiments);
    expect((state.history[0]!.data as any).segments).toEqual(validSegments);
  });
});

describe('Config — история и rollback', () => {
  beforeEach(resetState);

  it('каждый save пишет снапшот с инкрементом версии', async () => {
    const v1 = await saveConfigWithHistory({ economy: { maxTickets: 5 } }, 'admin-1');
    expect(v1.version).toBe(1);
    const v2 = await saveConfigWithHistory({ economy: { maxTickets: 9 } }, 'admin-1');
    expect(v2.version).toBe(2);

    expect(state.history).toHaveLength(2);
    expect(state.history[0]!.version).toBe(1);
    expect((state.history[0]!.data as any).economy).toEqual({ maxTickets: 5 });
    expect((state.history[1]!.data as any).economy).toEqual({ maxTickets: 9 });
    expect(state.history[1]!.changedBy).toBe('admin-1');
  });

  it('rollback копирует снапшот с новой версией', async () => {
    await saveConfigWithHistory({ economy: { maxTickets: 5 }, ads: { maxAdsPerDay: 3 } }, 'admin-1');
    await saveConfigWithHistory({ economy: { maxTickets: 99 } }, 'admin-1');

    const result = await rollbackConfig(1, 'admin-2');
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.version).toBe(3);
    expect(result.rolledBackTo).toBe(1);

    // GameConfig вернулся к данным версии 1, но с версией 3.
    expect(state.config!.version).toBe(3);
    expect(state.config!.economy).toEqual({ maxTickets: 5 });
    expect(state.config!.ads).toEqual({ maxAdsPerDay: 3 });
    // Откат сам записан в историю.
    expect(state.history).toHaveLength(3);
    expect(state.history[2]!.changedBy).toBe('admin-2');
  });

  it('rollback на несуществующую версию → version_not_found', async () => {
    await saveConfigWithHistory({ economy: {} }, 'admin-1');
    const result = await rollbackConfig(42, 'admin-1');
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toBe('version_not_found');
  });
});
