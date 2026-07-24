import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import type { Request } from 'express';
import type { Store } from 'express-rate-limit';
import { logger } from '../utils/logger';

const skipInTest = () => process.env.NODE_ENV === 'test';

// ─── Redis-стор (общий между инстансами), если задан REDIS_URL ───────────────
// Динамический require в try/catch: сервер работает и без redis-модулей —
// тогда in-memory стор + однократный warning в prod.

type RedisLikeClient = {
  sendCommand: (args: string[]) => Promise<unknown>;
  connect: () => Promise<unknown>;
  on: (event: string, cb: (err: unknown) => void) => void;
};

let redisClient: RedisLikeClient | null | undefined;

function getRedisClient(): RedisLikeClient | null {
  if (redisClient !== undefined) return redisClient;
  const url = process.env.REDIS_URL;
  if (!url) {
    redisClient = null;
    if (process.env.NODE_ENV === 'production') {
      logger.warn(
        '[rate-limit] REDIS_URL not set — using in-memory store (limits are NOT shared between instances)'
      );
    }
    return null;
  }
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { createClient } = require('redis');
    const client = createClient({ url }) as RedisLikeClient;
    client.on('error', (err) => logger.error({ err }, '[rate-limit] redis error'));
    client.connect().catch((err) => logger.error({ err }, '[rate-limit] redis connect failed'));
    redisClient = client;
  } catch (err) {
    logger.warn({ err }, '[rate-limit] redis module unavailable — falling back to in-memory store');
    redisClient = null;
  }
  return redisClient;
}

function makeStore(prefix: string): Store | undefined {
  const client = getRedisClient();
  if (!client) return undefined;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { RedisStore } = require('rate-limit-redis');
    return new RedisStore({
      prefix,
      sendCommand: (...args: string[]) => client.sendCommand(args),
    }) as unknown as Store;
  } catch (err) {
    logger.warn({ err }, '[rate-limit] rate-limit-redis unavailable — falling back to in-memory store');
    return undefined;
  }
}

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
  store: makeStore('rl:login:'),
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
  store: makeStore('rl:register:'),
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
  store: makeStore('rl:social:'),
});

/**
 * Лимитер для ротации refresh-токенов: 30 запросов в минуту с IP —
 * нормальный клиент рефрешит раз в ~12 часов, но допускаем ретраи.
 */
export const refreshLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 30,
  message: { error: 'Too many refresh attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
  store: makeStore('rl:refresh:'),
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
  store: makeStore('rl:iap:'),
  keyGenerator: (req: Request) => {
    const uid = (req as Request & { userId?: string }).userId;
    if (uid) return `iap:${uid}`;
    // ipKeyGenerator корректно обрабатывает IPv6 (нормализует /64 префикс).
    return `iap-ip:${ipKeyGenerator(req.ip ?? '')}`;
  },
});

/**
 * Лимитер экономических транзакций: 60 запросов в минуту на пользователя —
 * клиент флашит офлайн-очередь батчами, чаще незачем.
 */
export const economyLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 60,
  message: { error: 'Too many economy requests, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
  store: makeStore('rl:economy:'),
  keyGenerator: (req: Request) => {
    const uid = (req as Request & { userId?: string }).userId;
    if (uid) return `eco:${uid}`;
    return `eco-ip:${ipKeyGenerator(req.ip ?? '')}`;
  },
});

/**
 * Щедрый лимитер аналитики: клиент батчует и флашит каждые ~30с.
 * 60 запросов в минуту с одного IP.
 */
export const analyticsLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 60,
  message: { error: 'Too many analytics requests, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
  store: makeStore('rl:analytics:'),
});

/**
 * Лимитер погашения промокодов: 10 запросов в минуту на пользователя —
 * защита от перебора кодов. Ключ — userId из JWT (роут стоит после
 * authMiddleware), fallback на IP.
 */
export const promoRedeemLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  message: { error: 'Too many promo attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
  store: makeStore('rl:promo:'),
  keyGenerator: (req: Request) => {
    const uid = (req as Request & { userId?: string }).userId;
    if (uid) return `promo:${uid}`;
    return `promo-ip:${ipKeyGenerator(req.ip ?? '')}`;
  },
});

/**
 * Лимитер операций с аккаунтом (удаление / экспорт данных): редкие действия,
 * 10 запросов в час на пользователя. Ключ — userId (после authMiddleware).
 */
export const accountLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  message: { error: 'Too many account requests, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
  store: makeStore('rl:account:'),
  keyGenerator: (req: Request) => {
    const uid = (req as Request & { userId?: string }).userId;
    if (uid) return `acc:${uid}`;
    return `acc-ip:${ipKeyGenerator(req.ip ?? '')}`;
  },
});

/**
 * Лимитер S2S-нотификаций сторов: защита от флуда StoreNotification.
 * 120 запросов в минуту с IP — Apple/Google шлют пачками, но не тысячами.
 */
export const storeNotificationsLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  message: { error: 'Too many requests' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTest,
  store: makeStore('rl:notif:'),
});
