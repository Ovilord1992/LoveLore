/**
 * Тесты промокодов (спека 4.5): успех, повтор → 409, истёк/исчерпан → 410,
 * неактивен → 404, гонка исчерпания, vipDays-продление, запись в леджер.
 * Mock-prisma через vi.hoisted (паттерн economy.test.ts).
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

const mocks = vi.hoisted(() => {
  type PromoRow = {
    id: string;
    code: string;
    diamonds: number;
    tickets: number;
    vipDays: number;
    maxRedemptions: number;
    redemptionsCount: number;
    expiresAt: Date | null;
    isActive: boolean;
    createdAt: Date;
  };
  type RedemptionRow = { id: string; codeId: string; userId: string; createdAt: Date };
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
    promos: [] as PromoRow[],
    redemptions: [] as RedemptionRow[],
    ledger: [] as LedgerRow[],
    currencies: new Map<string, CurrencyRow>(),
    users: new Map<string, UserRow>(),
    /** Симуляция гонки: findUnique промокода возвращает устаревший redemptionsCount. */
    stalePromoRead: null as number | null,
  };

  function resetState() {
    state.promos = [];
    state.redemptions = [];
    state.ledger = [];
    state.currencies = new Map();
    state.users = new Map();
    state.stalePromoRead = null;
  }

  const randomUuid = () =>
    (globalThis as unknown as { crypto: { randomUUID: () => string } }).crypto.randomUUID();

  const p2002 = () => {
    const err = new Error('Unique constraint failed') as Error & { code: string };
    err.code = 'P2002';
    return err;
  };

  const prismaMock: any = {
    promoCode: {
      findUnique: async ({ where }: any) => {
        const row = state.promos.find((r) => (where.code ? r.code === where.code : r.id === where.id));
        if (!row) return null;
        const copy = { ...row };
        if (state.stalePromoRead !== null) copy.redemptionsCount = state.stalePromoRead;
        return copy;
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const row of state.promos) {
          if (where.id !== undefined && row.id !== where.id) continue;
          if (where.isActive !== undefined && row.isActive !== where.isActive) continue;
          if (where.redemptionsCount?.lt !== undefined && !(row.redemptionsCount < where.redemptionsCount.lt)) continue;
          if (data.redemptionsCount?.increment) row.redemptionsCount += data.redemptionsCount.increment;
          count++;
        }
        return { count };
      },
    },
    promoRedemption: {
      findUnique: async ({ where }: any) => {
        const w = where.codeId_userId;
        return state.redemptions.find((r) => r.codeId === w.codeId && r.userId === w.userId) ?? null;
      },
      create: async ({ data }: any) => {
        if (state.redemptions.some((r) => r.codeId === data.codeId && r.userId === data.userId)) {
          throw p2002();
        }
        const row = { id: randomUuid(), codeId: data.codeId, userId: data.userId, createdAt: new Date() };
        state.redemptions.push(row);
        return row;
      },
    },
    currencyLedger: {
      create: async ({ data }: any) => {
        if (state.ledger.some((r) => r.userId === data.userId && r.idempotencyKey === data.idempotencyKey)) {
          throw p2002();
        }
        const row = {
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
        const row = { userId: data.userId, diamonds: 50, tickets: 5, lastTicketRefill: null };
        state.currencies.set(data.userId, row);
        return row;
      },
      update: async ({ where, data }: any) => {
        const row = state.currencies.get(where.userId);
        if (!row) throw new Error('not found');
        if (typeof data.diamonds === 'number') row.diamonds = data.diamonds;
        if (typeof data.tickets === 'number') row.tickets = data.tickets;
        return row;
      },
    },
    user: {
      findUnique: async ({ where }: any) => state.users.get(where.id) ?? null,
      update: async ({ where, data }: any) => {
        const row = state.users.get(where.id);
        if (!row) throw new Error('not found');
        if (data.vipExpiresAt !== undefined) row.vipExpiresAt = data.vipExpiresAt;
        return row;
      },
    },
    $transaction: async (fn: any) => fn(prismaMock),
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

import { redeemPromoCode, normalizePromoCode } from '../promo/service';

const U = 'user-1';
const DAY = 24 * 60 * 60 * 1000;

function addPromo(partial: Partial<(typeof state.promos)[number]> = {}) {
  const row = {
    id: `promo-${state.promos.length + 1}`,
    code: 'WELCOME10',
    diamonds: 10,
    tickets: 0,
    vipDays: 0,
    maxRedemptions: 0,
    redemptionsCount: 0,
    expiresAt: null as Date | null,
    isActive: true,
    createdAt: new Date(),
    ...partial,
  };
  state.promos.push(row);
  return row;
}

function setCurrency(diamonds: number, tickets: number) {
  state.currencies.set(U, { userId: U, diamonds, tickets, lastTicketRefill: null });
}

beforeEach(resetState);

describe('Promo — normalizePromoCode', () => {
  it('регистронезависимость: trim + upper-case', () => {
    expect(normalizePromoCode('  welcome10 ')).toBe('WELCOME10');
  });
});

describe('Promo — успешное погашение', () => {
  it('начисляет награду через леджер (reason promo, refId = code)', async () => {
    addPromo({ diamonds: 25, tickets: 2 });
    setCurrency(50, 5);

    const result = await redeemPromoCode(U, 'welcome10');
    expect(result.status).toBe('ok');
    if (result.status !== 'ok') return;

    expect(result.reward).toEqual({ diamonds: 25, tickets: 2, vipDays: 0 });
    expect(result.balances).toEqual({ diamonds: 75, tickets: 7 });

    // Записи в леджере — по одной на валюту.
    expect(state.ledger).toHaveLength(2);
    for (const row of state.ledger) {
      expect(row.reason).toBe('promo');
      expect(row.refId).toBe('WELCOME10');
    }
    expect(state.ledger.find((r) => r.currency === 'diamonds')!.delta).toBe(25);
    expect(state.ledger.find((r) => r.currency === 'tickets')!.delta).toBe(2);

    // Погашение зафиксировано + счётчик инкрементирован в той же транзакции.
    expect(state.redemptions).toHaveLength(1);
    expect(state.promos[0]!.redemptionsCount).toBe(1);
  });

  it('код только с VIP-наградой не пишет строк в леджер', async () => {
    addPromo({ diamonds: 0, tickets: 0, vipDays: 7 });
    setCurrency(50, 5);
    state.users.set(U, { id: U, vipExpiresAt: null });

    const result = await redeemPromoCode(U, 'WELCOME10');
    expect(result.status).toBe('ok');
    if (result.status !== 'ok') return;
    expect(result.balances).toEqual({ diamonds: 50, tickets: 5 });
    expect(state.ledger).toHaveLength(0);
  });
});

describe('Promo — vipDays', () => {
  it('без активного VIP продлевает от now', async () => {
    addPromo({ diamonds: 0, vipDays: 3 });
    setCurrency(50, 5);
    state.users.set(U, { id: U, vipExpiresAt: null });

    const before = Date.now();
    const result = await redeemPromoCode(U, 'WELCOME10');
    expect(result.status).toBe('ok');

    const vip = state.users.get(U)!.vipExpiresAt!;
    expect(vip.getTime()).toBeGreaterThanOrEqual(before + 3 * DAY - 5000);
    expect(vip.getTime()).toBeLessThanOrEqual(Date.now() + 3 * DAY + 5000);
  });

  it('с активным VIP продлевает от текущего vipExpiresAt (max(now, текущее))', async () => {
    addPromo({ diamonds: 0, vipDays: 3 });
    setCurrency(50, 5);
    const current = new Date(Date.now() + 2 * DAY);
    state.users.set(U, { id: U, vipExpiresAt: current });

    const result = await redeemPromoCode(U, 'WELCOME10');
    expect(result.status).toBe('ok');

    const vip = state.users.get(U)!.vipExpiresAt!;
    expect(vip.getTime()).toBe(current.getTime() + 3 * DAY);
  });
});

describe('Promo — ошибки', () => {
  it('неизвестный код → not_found', async () => {
    setCurrency(50, 5);
    expect((await redeemPromoCode(U, 'NOPE')).status).toBe('not_found');
  });

  it('неактивный код → not_found', async () => {
    addPromo({ isActive: false });
    setCurrency(50, 5);
    expect((await redeemPromoCode(U, 'WELCOME10')).status).toBe('not_found');
  });

  it('истёкший код → expired', async () => {
    addPromo({ expiresAt: new Date(Date.now() - 1000) });
    setCurrency(50, 5);
    expect((await redeemPromoCode(U, 'WELCOME10')).status).toBe('expired');
  });

  it('исчерпанный код → exhausted', async () => {
    addPromo({ maxRedemptions: 2, redemptionsCount: 2 });
    setCurrency(50, 5);
    expect((await redeemPromoCode(U, 'WELCOME10')).status).toBe('exhausted');
  });

  it('повторное погашение тем же пользователем → already_redeemed', async () => {
    addPromo({ diamonds: 10 });
    setCurrency(50, 5);

    expect((await redeemPromoCode(U, 'WELCOME10')).status).toBe('ok');
    const second = await redeemPromoCode(U, 'welcome10');
    expect(second.status).toBe('already_redeemed');

    // Баланс и счётчик не задвоились.
    expect(state.currencies.get(U)!.diamonds).toBe(60);
    expect(state.promos[0]!.redemptionsCount).toBe(1);
    expect(state.ledger).toHaveLength(1);
  });

  it('гонка исчерпания: условный инкремент не матчится → exhausted, без начисления', async () => {
    // Реальный счётчик уже на лимите, но первая читка вернула устаревшее значение.
    addPromo({ maxRedemptions: 1, redemptionsCount: 1 });
    setCurrency(50, 5);
    state.stalePromoRead = 0;

    const result = await redeemPromoCode(U, 'WELCOME10');
    expect(result.status).toBe('exhausted');
    expect(state.promos[0]!.redemptionsCount).toBe(1); // не переинкрементирован
    expect(state.ledger).toHaveLength(0);
    expect(state.currencies.get(U)!.diamonds).toBe(50);
  });
});
