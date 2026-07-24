/**
 * Тесты серверного леджера валюты (POST /v1/economy/transactions).
 *
 * Стратегия — mock-prisma через vi.hoisted, как в iap.test.ts:
 * покрываем валидационную матрицу по каждому reason (применяется/отклоняется),
 * идемпотентность ключей и клампы баланса.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

const mocks = vi.hoisted(() => {
  type LedgerRow = {
    id: string;
    userId: string;
    currency: string;
    delta: number;
    reason: string;
    refId: string | null;
    idempotencyKey: string;
    createdAt: Date;
  };
  type CurrencyRow = { userId: string; diamonds: number; tickets: number; lastTicketRefill: Date | null };
  type UserRow = { id: string; vipExpiresAt: Date | null };

  const state = {
    ledger: [] as LedgerRow[],
    currencies: new Map<string, CurrencyRow>(),
    users: new Map<string, UserRow>(),
  };

  function resetState() {
    state.ledger = [];
    state.currencies = new Map();
    state.users = new Map();
  }

  const randomUuid = () =>
    (globalThis as unknown as { crypto: { randomUUID: () => string } }).crypto.randomUUID();

  const matchLedger = (row: LedgerRow, where: any): boolean => {
    if (where.userId !== undefined && row.userId !== where.userId) return false;
    if (where.reason !== undefined && row.reason !== where.reason) return false;
    if (where.currency !== undefined && row.currency !== where.currency) return false;
    if (where.refId !== undefined && row.refId !== where.refId) return false;
    if (where.createdAt?.gte !== undefined && row.createdAt < where.createdAt.gte) return false;
    return true;
  };

  const prismaMock: any = {
    currencyLedger: {
      findUnique: async ({ where }: any) => {
        const w = where.userId_idempotencyKey;
        return (
          state.ledger.find((r) => r.userId === w.userId && r.idempotencyKey === w.idempotencyKey) ??
          null
        );
      },
      findFirst: async ({ where }: any) => state.ledger.find((r) => matchLedger(r, where)) ?? null,
      count: async ({ where }: any) => state.ledger.filter((r) => matchLedger(r, where)).length,
      create: async ({ data }: any) => {
        const dup = state.ledger.find(
          (r) => r.userId === data.userId && r.idempotencyKey === data.idempotencyKey
        );
        if (dup) {
          const err = new Error('Unique constraint failed') as Error & { code: string };
          err.code = 'P2002';
          throw err;
        }
        const row: LedgerRow = {
          id: randomUuid(),
          userId: data.userId,
          currency: data.currency,
          delta: data.delta,
          reason: data.reason,
          refId: data.refId ?? null,
          idempotencyKey: data.idempotencyKey,
          createdAt: new Date(),
        };
        state.ledger.push(row);
        return row;
      },
    },
    currencyData: {
      findUnique: async ({ where }: any) => state.currencies.get(where.userId) ?? null,
      create: async ({ data }: any) => {
        const row: CurrencyRow = {
          userId: data.userId,
          diamonds: data.diamonds ?? 50,
          tickets: data.tickets ?? 5,
          lastTicketRefill: data.lastTicketRefill ?? null,
        };
        state.currencies.set(data.userId, row);
        return row;
      },
      update: async ({ where, data }: any) => {
        const row = state.currencies.get(where.userId);
        if (!row) throw new Error('not found');
        if (typeof data.diamonds === 'number') row.diamonds = data.diamonds;
        if (typeof data.tickets === 'number') row.tickets = data.tickets;
        if (data.lastTicketRefill !== undefined) row.lastTicketRefill = data.lastTicketRefill;
        return row;
      },
    },
    user: {
      findUnique: async ({ where }: any) => state.users.get(where.id) ?? null,
    },
    gameConfig: {
      findUnique: async () => null,
    },
    $transaction: async (fn: any) => fn(prismaMock),
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

import {
  applyClientOperations,
  adminSetCurrency,
  extractEconomyRules,
  clampDelta,
  MAX_CURRENCY,
  type EconomyRules,
} from '../economy/ledger';

const U = 'user-1';

function makeRules(): EconomyRules {
  return extractEconomyRules({
    economy: { maxTickets: 5, ticketRefillMinutes: 30, legacySyncCap: 1000 },
    ads: { maxAdsPerDay: 2, rewardAmount: 3 },
    vip: { dailyDiamonds: 5 },
    daily: [
      { day: 1, diamonds: 5, tickets: 0 },
      { day: 2, diamonds: 0, tickets: 1 },
    ],
    achievements: [{ id: 'first_story', diamondReward: 10 }],
  });
}

let keyCounter = 0;
function op(partial: Record<string, unknown>): Record<string, unknown> {
  return { key: `key-${String(++keyCounter).padStart(8, '0')}`, ...partial };
}

function setCurrency(diamonds: number, tickets: number, lastTicketRefill: Date | null = null) {
  state.currencies.set(U, { userId: U, diamonds, tickets, lastTicketRefill });
}

async function applyOne(o: Record<string, unknown>) {
  const { results, balances } = await applyClientOperations(U, [o], makeRules());
  return { result: results[0]!, balances };
}

beforeEach(() => {
  resetState();
  keyCounter = 0;
});

describe('Economy — extractEconomyRules', () => {
  it('подставляет дефолты при пустом конфиге', () => {
    const rules = extractEconomyRules(null);
    expect(rules.maxTickets).toBe(5);
    expect(rules.legacySyncCap).toBe(1000);
    expect(rules.adRewardAmount).toBe(3);
  });

  it('фолбэк ads.rewardAmount → ads.diamondReward', () => {
    const rules = extractEconomyRules({ ads: { diamondReward: 7 } });
    expect(rules.adRewardAmount).toBe(7);
  });
});

describe('Economy — clampDelta', () => {
  it('клампит спенд до баланса (не ниже 0)', () => {
    expect(clampDelta(50, -100)).toBe(-50);
    expect(clampDelta(0, -10)).toBe(0);
    expect(clampDelta(50, -30)).toBe(-30);
  });

  it('клампит начисление до MAX_CURRENCY', () => {
    expect(clampDelta(MAX_CURRENCY, 10)).toBe(0);
    expect(clampDelta(MAX_CURRENCY - 3, 10)).toBe(3);
  });
});

describe('Economy — spend_choice / spend_wardrobe', () => {
  it('применяет спенд и уменьшает баланс', async () => {
    setCurrency(50, 5);
    const { result, balances } = await applyOne(
      op({ currency: 'diamonds', delta: -15, reason: 'spend_choice', refId: 'n1:scene_5:2' })
    );
    expect(result.status).toBe('applied');
    expect(balances.diamonds).toBe(35);
    expect(state.ledger[0]!.delta).toBe(-15);
  });

  it('клампит спенд при недостатке баланса (баланс не уходит в минус)', async () => {
    setCurrency(10, 5);
    const { result, balances } = await applyOne(
      op({ currency: 'diamonds', delta: -100, reason: 'spend_wardrobe' })
    );
    expect(result.status).toBe('applied');
    expect(balances.diamonds).toBe(0);
    expect(state.ledger[0]!.delta).toBe(-10);
  });

  it('отклоняет положительную дельту', async () => {
    setCurrency(50, 5);
    const { result } = await applyOne(op({ currency: 'diamonds', delta: 15, reason: 'spend_choice' }));
    expect(result.status).toBe('rejected');
    expect(state.ledger).toHaveLength(0);
  });
});

describe('Economy — ticket_entry', () => {
  it('применяет -1 билет', async () => {
    setCurrency(50, 3);
    const { result, balances } = await applyOne(op({ currency: 'tickets', delta: -1, reason: 'ticket_entry' }));
    expect(result.status).toBe('applied');
    expect(balances.tickets).toBe(2);
  });

  it('отклоняет delta != -1 и неверную валюту', async () => {
    setCurrency(50, 3);
    const r1 = await applyOne(op({ currency: 'tickets', delta: -2, reason: 'ticket_entry' }));
    expect(r1.result.status).toBe('rejected');
    const r2 = await applyOne(op({ currency: 'diamonds', delta: -1, reason: 'ticket_entry' }));
    expect(r2.result.status).toBe('rejected');
  });
});

describe('Economy — ticket_refill', () => {
  it('применяет +1 при балансе ниже max и давнем рефилле', async () => {
    setCurrency(50, 3, new Date(Date.now() - 60 * 60_000));
    const { result, balances } = await applyOne(op({ currency: 'tickets', delta: 1, reason: 'ticket_refill' }));
    expect(result.status).toBe('applied');
    expect(balances.tickets).toBe(4);
    // lastTicketRefill обновлён
    expect(state.currencies.get(U)!.lastTicketRefill!.getTime()).toBeGreaterThan(Date.now() - 5000);
  });

  it('отклоняет при tickets на максимуме', async () => {
    setCurrency(50, 5);
    const { result } = await applyOne(op({ currency: 'tickets', delta: 1, reason: 'ticket_refill' }));
    expect(result.status).toBe('rejected');
    expect(result.error).toMatch(/max/);
  });

  it('отклоняет слишком частый рефилл', async () => {
    setCurrency(50, 3, new Date(Date.now() - 60_000)); // минуту назад при интервале 30 мин
    const { result } = await applyOne(op({ currency: 'tickets', delta: 1, reason: 'ticket_refill' }));
    expect(result.status).toBe('rejected');
    expect(result.error).toMatch(/soon/);
  });

  it('отклоняет delta != +1', async () => {
    setCurrency(50, 0);
    const { result } = await applyOne(op({ currency: 'tickets', delta: 3, reason: 'ticket_refill' }));
    expect(result.status).toBe('rejected');
  });
});

describe('Economy — ad_reward', () => {
  it('применяет корректную сумму (ads.rewardAmount)', async () => {
    setCurrency(50, 5);
    const { result, balances } = await applyOne(op({ currency: 'diamonds', delta: 3, reason: 'ad_reward' }));
    expect(result.status).toBe('applied');
    expect(balances.diamonds).toBe(53);
  });

  it('отклоняет неверную сумму', async () => {
    setCurrency(50, 5);
    const { result } = await applyOne(op({ currency: 'diamonds', delta: 500, reason: 'ad_reward' }));
    expect(result.status).toBe('rejected');
  });

  it('отклоняет сверх maxAdsPerDay в UTC-сутки', async () => {
    setCurrency(50, 5);
    await applyOne(op({ currency: 'diamonds', delta: 3, reason: 'ad_reward' }));
    await applyOne(op({ currency: 'diamonds', delta: 3, reason: 'ad_reward' }));
    const { result } = await applyOne(op({ currency: 'diamonds', delta: 3, reason: 'ad_reward' }));
    expect(result.status).toBe('rejected');
    expect(result.error).toMatch(/limit/);
    expect(state.currencies.get(U)!.diamonds).toBe(56); // только 2 применились
  });
});

describe('Economy — daily_reward', () => {
  it('применяет сумму дня из конфига (refId = индекс дня)', async () => {
    setCurrency(50, 5);
    const { result, balances } = await applyOne(
      op({ currency: 'diamonds', delta: 5, reason: 'daily_reward', refId: '1' })
    );
    expect(result.status).toBe('applied');
    expect(balances.diamonds).toBe(55);
  });

  it('отклоняет повторный клейм в те же UTC-сутки', async () => {
    setCurrency(50, 5);
    await applyOne(op({ currency: 'diamonds', delta: 5, reason: 'daily_reward', refId: '1' }));
    const { result } = await applyOne(
      op({ currency: 'diamonds', delta: 5, reason: 'daily_reward', refId: '1' })
    );
    expect(result.status).toBe('rejected');
    expect(result.error).toMatch(/already/);
  });

  it('отклоняет сумму, не совпадающую с конфигом дня', async () => {
    setCurrency(50, 5);
    const { result } = await applyOne(
      op({ currency: 'diamonds', delta: 999, reason: 'daily_reward', refId: '1' })
    );
    expect(result.status).toBe('rejected');
  });

  it('отклоняет неизвестный день', async () => {
    setCurrency(50, 5);
    const { result } = await applyOne(
      op({ currency: 'diamonds', delta: 5, reason: 'daily_reward', refId: '42' })
    );
    expect(result.status).toBe('rejected');
  });
});

describe('Economy — achievement', () => {
  it('применяет награду ачивки один раз', async () => {
    setCurrency(50, 5);
    const first = await applyOne(
      op({ currency: 'diamonds', delta: 10, reason: 'achievement', refId: 'first_story' })
    );
    expect(first.result.status).toBe('applied');
    expect(first.balances.diamonds).toBe(60);

    const second = await applyOne(
      op({ currency: 'diamonds', delta: 10, reason: 'achievement', refId: 'first_story' })
    );
    expect(second.result.status).toBe('rejected');
    expect(second.result.error).toMatch(/already/);
  });

  it('отклоняет неизвестную ачивку и неверную сумму', async () => {
    setCurrency(50, 5);
    const r1 = await applyOne(op({ currency: 'diamonds', delta: 10, reason: 'achievement', refId: 'nope' }));
    expect(r1.result.status).toBe('rejected');
    const r2 = await applyOne(
      op({ currency: 'diamonds', delta: 999, reason: 'achievement', refId: 'first_story' })
    );
    expect(r2.result.status).toBe('rejected');
  });
});

describe('Economy — vip_daily', () => {
  it('отклоняет без активного VIP', async () => {
    setCurrency(50, 5);
    state.users.set(U, { id: U, vipExpiresAt: null });
    const { result } = await applyOne(op({ currency: 'diamonds', delta: 5, reason: 'vip_daily' }));
    expect(result.status).toBe('rejected');
    expect(result.error).toMatch(/VIP/);
  });

  it('применяет с активным VIP, повтор в сутки отклоняет', async () => {
    setCurrency(50, 5);
    state.users.set(U, { id: U, vipExpiresAt: new Date(Date.now() + 86400_000) });
    const first = await applyOne(op({ currency: 'diamonds', delta: 5, reason: 'vip_daily' }));
    expect(first.result.status).toBe('applied');
    const second = await applyOne(op({ currency: 'diamonds', delta: 5, reason: 'vip_daily' }));
    expect(second.result.status).toBe('rejected');
  });
});

describe('Economy — legacy_sync', () => {
  it('применяет один раз в пределах legacySyncCap', async () => {
    setCurrency(50, 5);
    const first = await applyOne(op({ currency: 'diamonds', delta: 800, reason: 'legacy_sync' }));
    expect(first.result.status).toBe('applied');
    expect(first.balances.diamonds).toBe(850);

    const second = await applyOne(op({ currency: 'diamonds', delta: 100, reason: 'legacy_sync' }));
    expect(second.result.status).toBe('rejected');
    expect(second.result.error).toMatch(/already/);
  });

  it('отклоняет сверх legacySyncCap', async () => {
    setCurrency(50, 5);
    const { result } = await applyOne(op({ currency: 'diamonds', delta: 5000, reason: 'legacy_sync' }));
    expect(result.status).toBe('rejected');
    expect(result.error).toMatch(/legacySyncCap/);
  });
});

describe('Economy — запрещённые/неизвестные reasons и форма', () => {
  it('отклоняет iap и admin_grant от клиента', async () => {
    setCurrency(50, 5);
    const r1 = await applyOne(op({ currency: 'diamonds', delta: 100, reason: 'iap' }));
    expect(r1.result.status).toBe('rejected');
    expect(r1.result.error).toMatch(/not allowed/);
    const r2 = await applyOne(op({ currency: 'diamonds', delta: 100, reason: 'admin_grant' }));
    expect(r2.result.status).toBe('rejected');
  });

  it('отклоняет неизвестный reason', async () => {
    setCurrency(50, 5);
    const { result } = await applyOne(op({ currency: 'diamonds', delta: 5, reason: 'hack_me' }));
    expect(result.status).toBe('rejected');
  });

  it('отклоняет битую форму (нет key / кривые delta и currency)', async () => {
    setCurrency(50, 5);
    const { results } = await applyClientOperations(
      U,
      [
        { currency: 'diamonds', delta: -5, reason: 'spend_choice' }, // нет key
        op({ currency: 'gold', delta: -5, reason: 'spend_choice' }),
        op({ currency: 'diamonds', delta: 1.5, reason: 'spend_choice' }),
        op({ currency: 'diamonds', delta: 0, reason: 'spend_choice' }),
      ],
      makeRules()
    );
    for (const r of results) expect(r.status).toBe('rejected');
    expect(state.ledger).toHaveLength(0);
  });
});

describe('Economy — идемпотентность', () => {
  it('повтор ключа возвращает applied без повторного списания', async () => {
    setCurrency(50, 5);
    const sameOp = op({ currency: 'diamonds', delta: -10, reason: 'spend_choice' });
    const first = await applyOne(sameOp);
    expect(first.result.status).toBe('applied');
    expect(first.balances.diamonds).toBe(40);

    const second = await applyOne(sameOp);
    expect(second.result.status).toBe('applied');
    expect(second.balances.diamonds).toBe(40); // баланс не изменился
    expect(state.ledger).toHaveLength(1);
  });

  it('дубликат ключа внутри одного батча применяется один раз', async () => {
    setCurrency(50, 5);
    const o = op({ currency: 'diamonds', delta: -10, reason: 'spend_choice' });
    const { results, balances } = await applyClientOperations(U, [o, { ...o }], makeRules());
    expect(results[0]!.status).toBe('applied');
    expect(results[1]!.status).toBe('applied');
    expect(balances.diamonds).toBe(40);
    expect(state.ledger).toHaveLength(1);
  });
});

describe('Economy — adminSetCurrency (admin_grant/admin_deduct)', () => {
  it('пишет grant при увеличении и deduct при уменьшении', async () => {
    setCurrency(50, 5);
    const balances = await adminSetCurrency(U, { diamonds: 200, tickets: 2 }, 'admin-1');
    expect(balances).toEqual({ diamonds: 200, tickets: 2 });

    const grant = state.ledger.find((r) => r.currency === 'diamonds');
    const deduct = state.ledger.find((r) => r.currency === 'tickets');
    expect(grant!.reason).toBe('admin_grant');
    expect(grant!.delta).toBe(150);
    expect(deduct!.reason).toBe('admin_deduct');
    expect(deduct!.delta).toBe(-3);
    expect(grant!.refId).toBe('admin-1');
  });

  it('не пишет строк при совпадении значений', async () => {
    setCurrency(50, 5);
    await adminSetCurrency(U, { diamonds: 50 }, 'admin-1');
    expect(state.ledger).toHaveLength(0);
  });
});
