import crypto from 'crypto';
import prisma from '../db';
import { logger } from '../utils/logger';

/** Refresh TTL — 90 дней (спека 2.1). */
const REFRESH_TTL_MS = 90 * 24 * 60 * 60 * 1000;

/** В БД храним только sha256-хэш; сам токен — 48 случайных байт base64url. */
export function hashRefreshToken(raw: string): string {
  return crypto.createHash('sha256').update(raw).digest('hex');
}

function newRawToken(): string {
  return crypto.randomBytes(48).toString('base64url');
}

/** Выпуск нового refresh-токена (новая семья, если familyId не задан). */
export async function issueRefreshToken(userId: string, familyId?: string): Promise<string> {
  const raw = newRawToken();
  await prisma.refreshToken.create({
    data: {
      userId,
      tokenHash: hashRefreshToken(raw),
      familyId: familyId ?? crypto.randomUUID(),
      expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
    },
  });
  return raw;
}

export type RotateResult =
  | { ok: true; userId: string; refreshToken: string }
  | { ok: false; reason: 'invalid' | 'reused' };

/**
 * Ротация: старый токен помечается использованным, выдаётся новый той же семьи.
 * Повторное использование уже ротированного/отозванного токена = кража →
 * отзыв всей семьи (family revoke).
 */
export async function rotateRefreshToken(raw: string): Promise<RotateResult> {
  if (typeof raw !== 'string' || raw.length < 20 || raw.length > 512) {
    return { ok: false, reason: 'invalid' };
  }

  const row = await prisma.refreshToken.findUnique({
    where: { tokenHash: hashRefreshToken(raw) },
  });
  if (!row) return { ok: false, reason: 'invalid' };

  if (row.revokedAt || row.replacedById) {
    await revokeFamily(row.familyId);
    logger.warn({ userId: row.userId, familyId: row.familyId }, '[auth] refresh token reuse detected — family revoked');
    return { ok: false, reason: 'reused' };
  }

  if (row.expiresAt.getTime() < Date.now()) return { ok: false, reason: 'invalid' };

  const newRaw = newRawToken();
  try {
    await prisma.$transaction(async (db) => {
      const created = await db.refreshToken.create({
        data: {
          userId: row.userId,
          tokenHash: hashRefreshToken(newRaw),
          familyId: row.familyId,
          expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
        },
      });
      // Условный update: если параллельная ротация успела первой — откатываемся.
      const marked = await db.refreshToken.updateMany({
        where: { id: row.id, revokedAt: null, replacedById: null },
        data: { revokedAt: new Date(), replacedById: created.id },
      });
      if (marked.count === 0) {
        throw new Error('refresh-rotate-race');
      }
    });
  } catch (err) {
    if (err instanceof Error && err.message === 'refresh-rotate-race') {
      await revokeFamily(row.familyId);
      return { ok: false, reason: 'reused' };
    }
    throw err;
  }

  return { ok: true, userId: row.userId, refreshToken: newRaw };
}

/** Logout: отзыв токена и всей его семьи (цепочки этого устройства). */
export async function revokeRefreshTokenFamily(raw: string): Promise<boolean> {
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > 512) return false;
  const row = await prisma.refreshToken.findUnique({
    where: { tokenHash: hashRefreshToken(raw) },
  });
  if (!row) return false;
  await revokeFamily(row.familyId);
  return true;
}

async function revokeFamily(familyId: string): Promise<void> {
  await prisma.refreshToken.updateMany({
    where: { familyId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}
