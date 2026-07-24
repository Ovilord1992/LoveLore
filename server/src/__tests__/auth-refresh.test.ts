/**
 * Тесты refresh-токенов (спека 2.1): ротация, детект reuse → family revoke,
 * истечение, logout. Mock-prisma через vi.hoisted (паттерн iap.test.ts).
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';

const mocks = vi.hoisted(() => {
  type RtRow = {
    id: string;
    userId: string;
    tokenHash: string;
    familyId: string;
    expiresAt: Date;
    revokedAt: Date | null;
    replacedById: string | null;
    createdAt: Date;
  };

  const state = {
    tokens: [] as RtRow[],
    users: new Map<string, { id: string; role: string; tokenVersion: number }>(),
  };

  function resetState() {
    state.tokens = [];
    state.users = new Map();
  }

  const randomUuid = () =>
    (globalThis as unknown as { crypto: { randomUUID: () => string } }).crypto.randomUUID();

  const matches = (row: RtRow, where: any): boolean => {
    if (where.id !== undefined && row.id !== where.id) return false;
    if (where.familyId !== undefined && row.familyId !== where.familyId) return false;
    if (where.tokenHash !== undefined && row.tokenHash !== where.tokenHash) return false;
    if (where.revokedAt === null && row.revokedAt !== null) return false;
    if (where.replacedById === null && row.replacedById !== null) return false;
    return true;
  };

  const prismaMock: any = {
    refreshToken: {
      findUnique: async ({ where }: any) =>
        state.tokens.find((t) => t.tokenHash === where.tokenHash) ?? null,
      create: async ({ data }: any) => {
        const row: RtRow = {
          id: randomUuid(),
          userId: data.userId,
          tokenHash: data.tokenHash,
          familyId: data.familyId,
          expiresAt: data.expiresAt,
          revokedAt: null,
          replacedById: null,
          createdAt: new Date(),
        };
        state.tokens.push(row);
        return row;
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const row of state.tokens) {
          if (!matches(row, where)) continue;
          if (data.revokedAt !== undefined) row.revokedAt = data.revokedAt;
          if (data.replacedById !== undefined) row.replacedById = data.replacedById;
          count++;
        }
        return { count };
      },
    },
    user: {
      findUnique: async ({ where }: any) => state.users.get(where.id) ?? null,
    },
    $transaction: async (fn: any) => fn(prismaMock),
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

import {
  issueRefreshToken,
  rotateRefreshToken,
  revokeRefreshTokenFamily,
  hashRefreshToken,
} from '../auth/refresh';
import { MIN_PASSWORD_LENGTH } from '../routes/auth';

beforeEach(resetState);

describe('Auth — issueRefreshToken', () => {
  it('выдаёт случайный токен, в БД хранится только sha256-хэш', async () => {
    const raw = await issueRefreshToken('u1');
    expect(raw.length).toBeGreaterThanOrEqual(64); // 48 байт base64url
    expect(state.tokens).toHaveLength(1);
    expect(state.tokens[0]!.tokenHash).toBe(hashRefreshToken(raw));
    expect(state.tokens[0]!.tokenHash).not.toContain(raw);
  });
});

describe('Auth — ротация refresh-токена', () => {
  it('ротация: старый помечен использованным, новый — той же семьи', async () => {
    const raw = await issueRefreshToken('u1');
    const result = await rotateRefreshToken(raw);

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.userId).toBe('u1');
    expect(result.refreshToken).not.toBe(raw);

    expect(state.tokens).toHaveLength(2);
    const oldRow = state.tokens[0]!;
    const newRow = state.tokens[1]!;
    expect(oldRow.revokedAt).not.toBeNull();
    expect(oldRow.replacedById).toBe(newRow.id);
    expect(newRow.familyId).toBe(oldRow.familyId);
    expect(newRow.revokedAt).toBeNull();
  });

  it('повторное использование ротированного токена → reused + family revoke', async () => {
    const raw = await issueRefreshToken('u1');
    const first = await rotateRefreshToken(raw);
    expect(first.ok).toBe(true);

    // Кража: пробуем повторно использовать старый токен.
    const reuse = await rotateRefreshToken(raw);
    expect(reuse.ok).toBe(false);
    if (reuse.ok) return;
    expect(reuse.reason).toBe('reused');

    // Вся семья отозвана — включая свежевыданный токен.
    for (const row of state.tokens) {
      expect(row.revokedAt).not.toBeNull();
    }

    // Новый токен из первой ротации больше не работает.
    if (first.ok) {
      const after = await rotateRefreshToken(first.refreshToken);
      expect(after.ok).toBe(false);
    }
  });

  it('истёкший токен → invalid (без family revoke)', async () => {
    const raw = await issueRefreshToken('u1');
    state.tokens[0]!.expiresAt = new Date(Date.now() - 1000);

    const result = await rotateRefreshToken(raw);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.reason).toBe('invalid');
    expect(state.tokens[0]!.revokedAt).toBeNull();
  });

  it('мусорный/неизвестный токен → invalid', async () => {
    expect((await rotateRefreshToken('short')).ok).toBe(false);
    expect((await rotateRefreshToken('x'.repeat(64))).ok).toBe(false);
  });
});

describe('Auth — logout (revokeRefreshTokenFamily)', () => {
  it('отзывает всю семью токена', async () => {
    const raw = await issueRefreshToken('u1');
    const rotated = await rotateRefreshToken(raw);
    expect(rotated.ok).toBe(true);

    const revoked = await revokeRefreshTokenFamily(raw);
    expect(revoked).toBe(true);
    for (const row of state.tokens) {
      expect(row.revokedAt).not.toBeNull();
    }
  });

  it('неизвестный токен — no-op', async () => {
    expect(await revokeRefreshTokenFamily('unknown-token-value')).toBe(false);
  });
});

describe('Auth — политика пароля', () => {
  it('минимальная длина пароля регистрации — 8 символов', () => {
    expect(MIN_PASSWORD_LENGTH).toBe(8);
    expect('1234567'.length >= MIN_PASSWORD_LENGTH).toBe(false);
    expect('12345678'.length >= MIN_PASSWORD_LENGTH).toBe(true);
  });
});
