/**
 * Тесты удаления аккаунта и экспорта данных (спека 4.7): анонимизация,
 * отзыв токенов, чистка таблиц; экспорт без passwordHash и чувствительных полей.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

const mocks = vi.hoisted(() => {
  type UserRow = {
    id: string;
    email: string;
    passwordHash: string;
    displayName: string;
    role: string;
    vipExpiresAt: Date | null;
    tokenVersion: number;
    lastActiveAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
  };

  const state = {
    users: new Map<string, UserRow>(),
    saves: [] as { userId: string; novelId: string; data: unknown; updatedAt: Date }[],
    profiles: new Map<string, Record<string, unknown>>(),
    currencies: new Map<string, Record<string, unknown>>(),
    favorites: [] as { userId: string; novelId: string; createdAt: Date }[],
    ratings: [] as { userId: string; novelId: string; value: number; createdAt: Date; updatedAt: Date }[],
    reviews: [] as { userId: string; novelId: string; text: string; status: string; createdAt: Date }[],
    refreshTokens: [] as { userId: string; tokenHash: string; revokedAt: Date | null }[],
    ledger: [] as { userId: string; currency: string; delta: number; reason: string; refId: string | null; idempotencyKey: string; createdAt: Date }[],
    iaps: [] as { userId: string; platform: string; productId: string; transactionId: string; receiptHash: string; verified: boolean; rewardClaimed: boolean; revokedAt: Date | null; usdCents: number | null; createdAt: Date }[],
    promoRedemptions: [] as { userId: string; codeString: string; createdAt: Date }[],
  };

  function resetState() {
    state.users = new Map();
    state.saves = [];
    state.profiles = new Map();
    state.currencies = new Map();
    state.favorites = [];
    state.ratings = [];
    state.reviews = [];
    state.refreshTokens = [];
    state.ledger = [];
    state.iaps = [];
    state.promoRedemptions = [];
  }

  /** Применить prisma-select к строке (иначе экспорт «утащит» лишние поля из мока). */
  const pick = (row: Record<string, unknown> | null, select?: Record<string, unknown>) => {
    if (!row) return null;
    if (!select) return { ...row };
    const out: Record<string, unknown> = {};
    for (const [key, want] of Object.entries(select)) {
      if (want === true) out[key] = row[key];
    }
    return out;
  };

  const prismaMock: any = {
    user: {
      findUnique: async ({ where, select }: any) => pick(state.users.get(where.id) ?? null, select),
      update: async ({ where, data }: any) => {
        const row = state.users.get(where.id);
        if (!row) throw new Error('not found');
        if (typeof data.email === 'string') row.email = data.email;
        if (typeof data.passwordHash === 'string') row.passwordHash = data.passwordHash;
        if (typeof data.displayName === 'string') row.displayName = data.displayName;
        if (data.tokenVersion?.increment) row.tokenVersion += data.tokenVersion.increment;
        return row;
      },
    },
    gameSave: {
      deleteMany: async ({ where }: any) => {
        state.saves = state.saves.filter((r) => r.userId !== where.userId);
        return {};
      },
      findMany: async ({ where, select }: any) =>
        state.saves.filter((r) => r.userId === where.userId).map((r) => pick(r as any, select)),
    },
    userProfileData: {
      deleteMany: async ({ where }: any) => {
        state.profiles.delete(where.userId);
        return {};
      },
      findUnique: async ({ where, select }: any) => pick(state.profiles.get(where.userId) ?? null, select),
    },
    currencyData: {
      deleteMany: async ({ where }: any) => {
        state.currencies.delete(where.userId);
        return {};
      },
      findUnique: async ({ where, select }: any) => pick(state.currencies.get(where.userId) ?? null, select),
    },
    favorite: {
      deleteMany: async ({ where }: any) => {
        state.favorites = state.favorites.filter((r) => r.userId !== where.userId);
        return {};
      },
      findMany: async ({ where, select }: any) =>
        state.favorites.filter((r) => r.userId === where.userId).map((r) => pick(r as any, select)),
    },
    rating: {
      deleteMany: async ({ where }: any) => {
        state.ratings = state.ratings.filter((r) => r.userId !== where.userId);
        return {};
      },
      findMany: async ({ where, select }: any) =>
        state.ratings.filter((r) => r.userId === where.userId).map((r) => pick(r as any, select)),
    },
    review: {
      deleteMany: async ({ where }: any) => {
        state.reviews = state.reviews.filter((r) => r.userId !== where.userId);
        return {};
      },
      findMany: async ({ where, select }: any) =>
        state.reviews.filter((r) => r.userId === where.userId).map((r) => pick(r as any, select)),
    },
    refreshToken: {
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const row of state.refreshTokens) {
          if (row.userId !== where.userId) continue;
          if (where.revokedAt === null && row.revokedAt !== null) continue;
          row.revokedAt = data.revokedAt;
          count++;
        }
        return { count };
      },
    },
    currencyLedger: {
      findMany: async ({ where, select }: any) =>
        state.ledger.filter((r) => r.userId === where.userId).map((r) => pick(r as any, select)),
    },
    iapTransaction: {
      findMany: async ({ where, select }: any) =>
        state.iaps.filter((r) => r.userId === where.userId).map((r) => pick(r as any, select)),
    },
    promoRedemption: {
      findMany: async ({ where }: any) =>
        state.promoRedemptions
          .filter((r) => r.userId === where.userId)
          .map((r) => ({ createdAt: r.createdAt, code: { code: r.codeString } })),
    },
    $transaction: async (fn: any) => fn(prismaMock),
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

import { deleteAccount, exportUserData } from '../auth/account';

const U = 'u1';
const OTHER = 'u2';

function seedUser(id: string) {
  state.users.set(id, {
    id,
    email: `${id}@example.com`,
    passwordHash: `hash-original-${id}`,
    displayName: 'Вася',
    role: 'user',
    vipExpiresAt: null,
    tokenVersion: 0,
    lastActiveAt: null,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-07-01T00:00:00Z'),
  });
  state.saves.push({ userId: id, novelId: 'n1', data: { scene: 's5' }, updatedAt: new Date() });
  state.profiles.set(id, { displayName: 'Вася', avatarIndex: 1, totalNovelsStarted: 2, totalNovelsCompleted: 1, totalChoicesMade: 10, totalChaptersRead: 5, unlockedCGs: [], achievements: ['first_story'], updatedAt: new Date() });
  state.currencies.set(id, { diamonds: 120, tickets: 3, lastTicketRefill: null, updatedAt: new Date() });
  state.favorites.push({ userId: id, novelId: 'n1', createdAt: new Date() });
  state.ratings.push({ userId: id, novelId: 'n1', value: 5, createdAt: new Date(), updatedAt: new Date() });
  state.reviews.push({ userId: id, novelId: 'n1', text: 'Отлично', status: 'approved', createdAt: new Date() });
  state.refreshTokens.push({ userId: id, tokenHash: `rt-${id}-1`, revokedAt: null });
  state.refreshTokens.push({ userId: id, tokenHash: `rt-${id}-2`, revokedAt: null });
  state.ledger.push({ userId: id, currency: 'diamonds', delta: -15, reason: 'spend_choice', refId: 'n1:s5:2', idempotencyKey: `k-${id}`, createdAt: new Date() });
  state.iaps.push({ userId: id, platform: 'google', productId: 'diamonds_60', transactionId: `tx-${id}`, receiptHash: `secret-receipt-${id}`, verified: true, rewardClaimed: true, revokedAt: null, usdCents: 499, createdAt: new Date() });
  state.promoRedemptions.push({ userId: id, codeString: 'WELCOME10', createdAt: new Date() });
}

beforeEach(() => {
  resetState();
  seedUser(U);
  seedUser(OTHER);
});

describe('Account — deleteAccount (анонимизация)', () => {
  it('анонимизирует пользователя и отзывает токены', async () => {
    expect(await deleteAccount(U)).toBe(true);

    const user = state.users.get(U)!;
    expect(user.email).toBe(`deleted-${U}@deleted.local`);
    expect(user.passwordHash).not.toBe(`hash-original-${U}`);
    expect(user.passwordHash.length).toBeGreaterThanOrEqual(32); // случайный
    expect(user.displayName).toBe('');
    expect(user.tokenVersion).toBe(1);

    for (const rt of state.refreshTokens.filter((r) => r.userId === U)) {
      expect(rt.revokedAt).not.toBeNull();
    }
  });

  it('удаляет GameSave/UserProfileData/CurrencyData/Favorite/Rating/Review', async () => {
    await deleteAccount(U);

    expect(state.saves.filter((r) => r.userId === U)).toHaveLength(0);
    expect(state.profiles.has(U)).toBe(false);
    expect(state.currencies.has(U)).toBe(false);
    expect(state.favorites.filter((r) => r.userId === U)).toHaveLength(0);
    expect(state.ratings.filter((r) => r.userId === U)).toHaveLength(0);
    expect(state.reviews.filter((r) => r.userId === U)).toHaveLength(0);
  });

  it('леджер и IAP-транзакции остаются (финансовый учёт), чужие данные не тронуты', async () => {
    await deleteAccount(U);

    expect(state.ledger.filter((r) => r.userId === U)).toHaveLength(1);
    expect(state.iaps.filter((r) => r.userId === U)).toHaveLength(1);

    // Другой пользователь не задет.
    expect(state.users.get(OTHER)!.email).toBe(`${OTHER}@example.com`);
    expect(state.saves.filter((r) => r.userId === OTHER)).toHaveLength(1);
    expect(state.refreshTokens.find((r) => r.userId === OTHER)!.revokedAt).toBeNull();
  });

  it('неизвестный пользователь → false', async () => {
    expect(await deleteAccount('nope')).toBe(false);
  });
});

describe('Account — exportUserData', () => {
  it('содержит все данные пользователя', async () => {
    const data = await exportUserData(U);
    expect(data).not.toBeNull();

    expect((data!.user as any).email).toBe(`${U}@example.com`);
    expect(data!.saves).toHaveLength(1);
    expect((data!.profile as any).totalChoicesMade).toBe(10);
    expect((data!.currency as any).diamonds).toBe(120);
    expect(data!.favorites).toHaveLength(1);
    expect(data!.ratings).toHaveLength(1);
    expect(data!.reviews).toHaveLength(1);
    expect(data!.ledger).toHaveLength(1);
    expect(data!.iapTransactions).toHaveLength(1);
    expect(data!.promoRedemptions).toEqual([
      { code: 'WELCOME10', createdAt: expect.any(Date) },
    ]);
  });

  it('не содержит passwordHash, токенов и чувствительных полей IAP', async () => {
    const json = JSON.stringify(await exportUserData(U));
    expect(json).not.toContain('passwordHash');
    expect(json).not.toContain(`hash-original-${U}`);
    expect(json).not.toContain('receiptHash');
    expect(json).not.toContain(`secret-receipt-${U}`);
    expect(json).not.toContain('tokenHash');
    expect(json).not.toContain(`rt-${U}-1`);
  });

  it('неизвестный пользователь → null', async () => {
    expect(await exportUserData('nope')).toBeNull();
  });
});
