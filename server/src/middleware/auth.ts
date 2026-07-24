import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../db';
import { logger } from '../utils/logger';

const DEV_DEFAULT_JWT_SECRET = 'amoria-dev-secret-change-in-production';

function resolveJwtSecret(): string {
  const fromEnv = process.env.JWT_SECRET;
  // Default к production-режиму: только явный development/test разрешает дефолтный секрет.
  // undefined / любое другое значение NODE_ENV (например, незаданное под PM2/Docker) — production.
  const env = process.env.NODE_ENV;
  const isProd = env !== 'development' && env !== 'test';

  if (fromEnv && fromEnv.length > 0) {
    // Даже если секрет задан явно — в проде (NODE_ENV=production) он не должен
    // совпадать с известным dev-дефолтом. Локальный dev (NODE_ENV не задан) при
    // этом продолжает работать с дефолтом из .env, как и раньше.
    if (env === 'production' && fromEnv === DEV_DEFAULT_JWT_SECRET) {
      throw new Error(
        'JWT_SECRET must not be the known dev default in production — set a strong unique secret'
      );
    }
    return fromEnv;
  }
  // Пустой секрет: фейлимся во всём, что не является явным development/test
  // (unset NODE_ENV трактуем как прод — fail-safe).
  if (isProd) {
    throw new Error('JWT_SECRET is required (NODE_ENV is not development/test)');
  }
  logger.warn('[auth] Using default JWT_SECRET — set JWT_SECRET in .env for production');
  return DEV_DEFAULT_JWT_SECRET;
}

export const JWT_SECRET = resolveJwtSecret();

/** Access-токен короткоживущий: refresh-токены (см. auth/refresh.ts) продлевают сессию. */
const ACCESS_TOKEN_TTL = '12h';

/** Троттлинг обновления User.lastActiveAt — не чаще раза в час. */
const LAST_ACTIVE_THROTTLE_MS = 60 * 60 * 1000;

export interface AuthRequest extends Request {
  userId?: string;
  /** Роль из БД (optionalAuthMiddleware) — для тест-режима контента (спека 4.9). */
  role?: string;
}

interface TokenPayload {
  userId: string;
  role?: string;
  /** tokenVersion на момент выпуска. Легаси-токены без tv валидны, пока user.tokenVersion == 0. */
  tv?: number;
}

/** Генерация access JWT (claims: userId, role, tv). */
export function generateToken(userId: string, role: string = 'user', tokenVersion: number = 0): string {
  return jwt.sign({ userId, role, tv: tokenVersion }, JWT_SECRET, { expiresIn: ACCESS_TOKEN_TTL });
}

function verifyToken(token: string): TokenPayload | null {
  try {
    const payload = jwt.verify(token, JWT_SECRET) as TokenPayload;
    return payload && typeof payload.userId === 'string' ? payload : null;
  } catch {
    return null;
  }
}

/** Fire-and-forget обновление lastActiveAt (не чаще раза в час). */
function touchLastActive(userId: string, lastActiveAt: Date | null): void {
  const now = Date.now();
  if (lastActiveAt && now - lastActiveAt.getTime() < LAST_ACTIVE_THROTTLE_MS) return;
  prisma.user
    .update({ where: { id: userId }, data: { lastActiveAt: new Date(now) } })
    .catch((err) => logger.warn({ err, userId }, '[auth] failed to update lastActiveAt'));
}

/** Middleware: проверка JWT токена + tokenVersion (глобальный отзыв). */
export async function authMiddleware(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Authorization required' });
    return;
  }

  const payload = verifyToken(header.slice(7));
  if (!payload) {
    res.status(401).json({ error: 'Invalid or expired token' });
    return;
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { tokenVersion: true, lastActiveAt: true },
    });
    // Легаси-токены без tv считаются выпущенными при tokenVersion=0.
    if (!user || (payload.tv ?? 0) !== user.tokenVersion) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    req.userId = payload.userId;
    touchLastActive(payload.userId, user.lastActiveAt);
    next();
  } catch (err) {
    logger.error({ err }, '[auth] middleware error');
    res.status(500).json({ error: 'Internal server error' });
  }
}

/**
 * Middleware: опциональная авторизация (аналитика). Валидный токен заполняет
 * req.userId; отсутствие/невалидность токена НЕ является ошибкой — запрос
 * продолжается анонимно.
 */
export async function optionalAuthMiddleware(req: AuthRequest, _res: Response, next: NextFunction): Promise<void> {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    next();
    return;
  }

  const payload = verifyToken(header.slice(7));
  if (!payload) {
    next();
    return;
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { tokenVersion: true, lastActiveAt: true, role: true },
    });
    if (user && (payload.tv ?? 0) === user.tokenVersion) {
      req.userId = payload.userId;
      // Роль — из БД, не из клейма: тест-режим контента (спека 4.9) должен
      // отключаться сразу при снятии роли, не дожидаясь истечения токена.
      req.role = user.role;
      touchLastActive(payload.userId, user.lastActiveAt);
    }
  } catch (err) {
    logger.warn({ err }, '[auth] optional auth lookup failed — continuing as anonymous');
  }
  next();
}
