import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { logger } from '../utils/logger';

function resolveJwtSecret(): string {
  const fromEnv = process.env.JWT_SECRET;
  if (fromEnv && fromEnv.length > 0) {
    return fromEnv;
  }
  // Default к production-режиму: только явный development/test разрешает дефолтный секрет.
  // undefined / любое другое значение NODE_ENV (например, незаданное под PM2/Docker) — production.
  const env = process.env.NODE_ENV;
  if (env !== 'development' && env !== 'test') {
    throw new Error('JWT_SECRET is required (NODE_ENV is not development/test)');
  }
  logger.warn('[auth] Using default JWT_SECRET — set JWT_SECRET in .env for production');
  return 'amoria-dev-secret-change-in-production';
}

export const JWT_SECRET = resolveJwtSecret();

export interface AuthRequest extends Request {
  userId?: string;
}

/** Генерация JWT токена */
export function generateToken(userId: string): string {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '30d' });
}

/** Middleware: проверка JWT токена */
export function authMiddleware(req: AuthRequest, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Authorization required' });
    return;
  }

  const token = header.slice(7);

  try {
    const payload = jwt.verify(token, JWT_SECRET) as { userId: string };
    req.userId = payload.userId;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
