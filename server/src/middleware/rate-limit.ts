import rateLimit from 'express-rate-limit';
import type { Request } from 'express';

const skipInTest = () => process.env.NODE_ENV === 'test';

/**
 * Лимитер для логина — защита от brute-force подбора пароля.
 * 5 запросов в минуту с одного IP.
 */
export const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 5,
  message: { error: 'Too many login attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
});

/**
 * Лимитер для регистрации — защита от массового создания аккаунтов.
 * 3 запроса в час с одного IP.
 */
export const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 3,
  message: { error: 'Too many registration attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
});

/**
 * Лимитер для социального входа (Google / Apple).
 * 10 запросов в минуту с одного IP — чуть мягче, т.к. валидация токена медленная,
 * но один пользователь не должен слать сюда десятки запросов.
 */
export const socialAuthLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  message: { error: 'Too many social auth attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
});

/**
 * Лимитер для верификации IAP-чеков.
 * 10 запросов в минуту на пользователя (ключ — userId, не IP), т.к. реальный
 * пользователь не покупает чаще раза в несколько секунд, а боты могут
 * пытаться брутфорсить дубликаты transactionId.
 *
 * Ключ — userId из JWT (заполнен authMiddleware). Если по какой-то причине
 * userId отсутствует — fallback на IP, чтобы не уронить лимитер.
 */
export const iapVerifyLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  message: { error: 'Too many IAP verify attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
  keyGenerator: (req: Request) => {
    const uid = (req as Request & { userId?: string }).userId;
    return uid ? `iap:${uid}` : `iap-ip:${req.ip}`;
  },
});
