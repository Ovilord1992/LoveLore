import crypto from 'crypto';
import prisma from '../db';
import { logger } from '../utils/logger';

/**
 * Серверный леджер валюты — источник истины по балансам (спека 2.2).
 * Каждая мутация баланса = строка CurrencyLedger + атомарное обновление
 * CurrencyData в одной транзакции. sum(delta) по леджеру == баланс.
 */

export const MAX_CURRENCY = 999_999;

export type LedgerCurrency = 'diamonds' | 'tickets';

export interface ClientOperation {
  key: string;
  currency: LedgerCurrency;
  delta: number;
  reason: string;
  refId?: string;
  clientTs?: number;
}

export interface OperationResult {
  key: string;
  status: 'applied' | 'rejected';
  error?: string;
}

export interface EconomyRules {
  maxTickets: number;
  ticketRefillMinutes: number;
  legacySyncCap: number;
  adRewardAmount: number;
  maxAdsPerDay: number;
  vipDailyDiamonds: number;
  daily: { day: number; diamonds?: number; tickets?: number }[];
  achievements: { id: string; diamondReward?: number }[];
}

/** Причины, разрешённые от клиента. iap/admin_* пишутся только сервером. */
const CLIENT_REASONS: ReadonlySet<string> = new Set([
  'spend_choice',
  'spend_wardrobe',
  'ticket_entry',
  'ticket_refill',
  'ad_reward',
  'daily_reward',
  'achievement',
  'vip_daily',
  'legacy_sync',
]);

/** Кламп применяемой дельты: баланс остаётся в [0, MAX_CURRENCY]. */
export function clampDelta(balance: number, delta: number): number {
  if (delta >= 0) return Math.max(0, Math.min(delta, MAX_CURRENCY - balance));
  return Math.max(delta, -balance) + 0; // +0 нормализует -0
}

function utcDayStart(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

function asInt(v: unknown, fallback: number): number {
  return typeof v === 'number' && Number.isInteger(v) && v >= 0 ? v : fallback;
}

/** Извлечь правила экономики из строки GameConfig (с дефолтами при отсутствии). */
export function extractEconomyRules(config: {
  economy?: unknown;
  ads?: unknown;
  vip?: unknown;
  daily?: unknown;
  achievements?: unknown;
} | null): EconomyRules {
  const economy = (config?.economy ?? {}) as Record<string, unknown>;
  const ads = (config?.ads ?? {}) as Record<string, unknown>;
  const vip = (config?.vip ?? {}) as Record<string, unknown>;
  const daily = Array.isArray(config?.daily) ? (config!.daily as EconomyRules['daily']) : [];
  const achievements = Array.isArray(config?.achievements)
    ? (config!.achievements as EconomyRules['achievements'])
    : [];

  return {
    maxTickets: asInt(economy.maxTickets, 5),
    ticketRefillMinutes: asInt(economy.ticketRefillMinutes, 30),
    legacySyncCap: asInt(economy.legacySyncCap, 1000),
    // Спека: ads.rewardAmount; фолбэк на легаси-ключ diamondReward.
    adRewardAmount: asInt(ads.rewardAmount, asInt(ads.diamondReward, 3)),
    maxAdsPerDay: asInt(ads.maxAdsPerDay, 5),
    vipDailyDiamonds: asInt(vip.dailyDiamonds, 5),
    daily,
    achievements,
  };
}

export async function loadEconomyRules(): Promise<EconomyRules> {
  const config = await prisma.gameConfig.findUnique({ where: { id: 'singleton' } });
  return extractEconomyRules(config);
}

export async function getBalances(userId: string): Promise<{ diamonds: number; tickets: number }> {
  const cur = await prisma.currencyData.findUnique({ where: { userId } });
  return { diamonds: cur?.diamonds ?? 50, tickets: cur?.tickets ?? 5 };
}

/** Батч операций от клиента: последовательное применение + авторитетные балансы. */
export async function applyClientOperations(
  userId: string,
  ops: unknown[],
  rules: EconomyRules
): Promise<{ results: OperationResult[]; balances: { diamonds: number; tickets: number } }> {
  const results: OperationResult[] = [];
  for (const op of ops) {
    results.push(await applyOne(userId, op, rules));
  }
  const balances = await getBalances(userId);
  return { results, balances };
}

function validateShape(op: unknown): string | null {
  if (!op || typeof op !== 'object') return 'transaction must be an object';
  const o = op as Record<string, unknown>;
  if (typeof o.key !== 'string' || o.key.length < 8 || o.key.length > 128) {
    return 'key must be a string (8..128 chars)';
  }
  if (o.currency !== 'diamonds' && o.currency !== 'tickets') {
    return 'currency must be "diamonds" or "tickets"';
  }
  if (
    typeof o.delta !== 'number' ||
    !Number.isInteger(o.delta) ||
    o.delta === 0 ||
    Math.abs(o.delta) > 1_000_000
  ) {
    return 'delta must be a non-zero integer (|delta| <= 1000000)';
  }
  if (typeof o.reason !== 'string' || o.reason.length === 0 || o.reason.length > 50) {
    return 'reason is required';
  }
  if (o.refId !== undefined && (typeof o.refId !== 'string' || o.refId.length > 200)) {
    return 'refId must be a string (<= 200 chars)';
  }
  return null;
}

// Тип клиента транзакции prisma (callback $transaction) — используем прямую
// типизацию через typeof prisma, чтобы не тянуть Prisma.TransactionClient.
type Db = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

async function ensureCurrency(db: Db, userId: string): Promise<{ diamonds: number; tickets: number; lastTicketRefill: Date | null }> {
  const existing = await db.currencyData.findUnique({ where: { userId } });
  if (existing) {
    return {
      diamonds: existing.diamonds,
      tickets: existing.tickets,
      lastTicketRefill: existing.lastTicketRefill ?? null,
    };
  }
  const created = await db.currencyData.create({ data: { userId } });
  return {
    diamonds: created.diamonds,
    tickets: created.tickets,
    lastTicketRefill: created.lastTicketRefill ?? null,
  };
}

async function applyOne(userId: string, rawOp: unknown, rules: EconomyRules): Promise<OperationResult> {
  const shapeError = validateShape(rawOp);
  if (shapeError) {
    const key = rawOp && typeof rawOp === 'object' && typeof (rawOp as { key?: unknown }).key === 'string'
      ? ((rawOp as { key: string }).key)
      : '';
    return { key, status: 'rejected', error: shapeError };
  }
  const op = rawOp as ClientOperation;

  if (!CLIENT_REASONS.has(op.reason)) {
    return { key: op.key, status: 'rejected', error: `reason '${op.reason}' is not allowed from client` };
  }

  try {
    return await prisma.$transaction(async (db) => {
      // Идемпотентность: повтор ключа → прежний результат (строка есть = applied).
      const dup = await db.currencyLedger.findUnique({
        where: { userId_idempotencyKey: { userId, idempotencyKey: op.key } },
      });
      if (dup) return { key: op.key, status: 'applied' as const };

      const cur = await ensureCurrency(db, userId);
      const balance = op.currency === 'diamonds' ? cur.diamonds : cur.tickets;

      const rejection = await validateByReason(db, userId, op, rules, balance, cur);
      if (rejection) return { key: op.key, status: 'rejected' as const, error: rejection };

      const effective = clampDelta(balance, op.delta);
      await db.currencyLedger.create({
        data: {
          userId,
          currency: op.currency,
          delta: effective,
          reason: op.reason,
          refId: op.refId ?? null,
          idempotencyKey: op.key,
        },
      });

      const data: Record<string, unknown> = { [op.currency]: balance + effective };
      if (op.reason === 'ticket_refill') data.lastTicketRefill = new Date();
      await db.currencyData.update({ where: { userId }, data });

      return { key: op.key, status: 'applied' as const };
    });
  } catch (err) {
    if (isUniqueViolation(err)) {
      // Гонка двух одинаковых ключей — первый уже применил.
      return { key: op.key, status: 'applied' };
    }
    logger.error({ err, userId, key: op.key }, '[economy] failed to apply operation');
    return { key: op.key, status: 'rejected', error: 'internal error' };
  }
}

async function validateByReason(
  db: Db,
  userId: string,
  op: ClientOperation,
  rules: EconomyRules,
  balance: number,
  cur: { lastTicketRefill: Date | null }
): Promise<string | null> {
  const now = new Date();
  const dayStart = utcDayStart(now);

  switch (op.reason) {
    case 'spend_choice':
    case 'spend_wardrobe':
      return op.delta < 0 ? null : 'delta must be negative';

    case 'ticket_entry':
      if (op.currency !== 'tickets') return 'currency must be tickets';
      if (op.delta !== -1) return 'delta must be -1';
      return null;

    case 'ticket_refill': {
      if (op.currency !== 'tickets') return 'currency must be tickets';
      if (op.delta !== 1) return 'delta must be +1';
      if (balance >= rules.maxTickets) return 'tickets already at max';
      const last = cur.lastTicketRefill?.getTime() ?? 0;
      // ~интервал рефилла: 10% допуска на дрожание клиентских часов.
      const minIntervalMs = rules.ticketRefillMinutes * 60_000 * 0.9;
      if (last && now.getTime() - last < minIntervalMs) return 'refill too soon';
      return null;
    }

    case 'ad_reward': {
      if (op.currency !== 'diamonds') return 'currency must be diamonds';
      if (op.delta !== rules.adRewardAmount) return `delta must be +${rules.adRewardAmount}`;
      const todayCount = await db.currencyLedger.count({
        where: { userId, reason: 'ad_reward', createdAt: { gte: dayStart } },
      });
      if (todayCount >= rules.maxAdsPerDay) return 'daily ad limit reached';
      return null;
    }

    case 'daily_reward': {
      if (!op.refId) return 'refId (day index) is required';
      const dayIdx = Number(op.refId);
      const entry = rules.daily.find((d) => d.day === dayIdx);
      if (!entry) return `unknown daily day '${op.refId}'`;
      const expected = op.currency === 'diamonds' ? (entry.diamonds ?? 0) : (entry.tickets ?? 0);
      if (expected <= 0 || op.delta !== expected) return 'delta does not match daily config';
      const claimed = await db.currencyLedger.findFirst({
        where: { userId, reason: 'daily_reward', currency: op.currency, createdAt: { gte: dayStart } },
      });
      if (claimed) return 'daily reward already claimed today';
      return null;
    }

    case 'achievement': {
      if (!op.refId) return 'refId (achievement id) is required';
      const ach = rules.achievements.find((a) => a.id === op.refId);
      if (!ach) return `unknown achievement '${op.refId}'`;
      const rewardAmount = ach.diamondReward ?? 0;
      if (op.currency !== 'diamonds' || rewardAmount <= 0 || op.delta !== rewardAmount) {
        return 'delta does not match achievement reward';
      }
      const claimed = await db.currencyLedger.findFirst({
        where: { userId, reason: 'achievement', refId: op.refId },
      });
      if (claimed) return 'achievement already claimed';
      return null;
    }

    case 'vip_daily': {
      if (op.currency !== 'diamonds') return 'currency must be diamonds';
      if (op.delta !== rules.vipDailyDiamonds) return `delta must be +${rules.vipDailyDiamonds}`;
      const user = await db.user.findUnique({ where: { id: userId }, select: { vipExpiresAt: true } });
      if (!user?.vipExpiresAt || user.vipExpiresAt.getTime() <= now.getTime()) return 'VIP is not active';
      const claimed = await db.currencyLedger.findFirst({
        where: { userId, reason: 'vip_daily', createdAt: { gte: dayStart } },
      });
      if (claimed) return 'vip daily already claimed today';
      return null;
    }

    case 'legacy_sync': {
      if (op.delta <= 0) return 'delta must be positive';
      if (op.delta > rules.legacySyncCap) return `delta exceeds legacySyncCap (${rules.legacySyncCap})`;
      // Один раз за жизнь аккаунта (per currency — у операции одна валюта).
      const done = await db.currencyLedger.findFirst({
        where: { userId, reason: 'legacy_sync', currency: op.currency },
      });
      if (done) return 'legacy sync already performed';
      return null;
    }

    default:
      return 'unknown reason';
  }
}

/**
 * Админ-грант: установка абсолютных значений валюты через леджер
 * (admin_grant при увеличении, admin_deduct при уменьшении).
 */
export async function adminSetCurrency(
  userId: string,
  target: { diamonds?: number; tickets?: number },
  adminId: string
): Promise<{ diamonds: number; tickets: number }> {
  const clampAbs = (v: number) => Math.max(0, Math.min(MAX_CURRENCY, Math.trunc(v)));

  return prisma.$transaction(async (db) => {
    const cur = await ensureCurrency(db, userId);
    let diamonds = cur.diamonds;
    let tickets = cur.tickets;

    const write = async (currency: LedgerCurrency, from: number, to: number): Promise<number> => {
      const delta = to - from;
      if (delta === 0) return from;
      await db.currencyLedger.create({
        data: {
          userId,
          currency,
          delta,
          reason: delta > 0 ? 'admin_grant' : 'admin_deduct',
          refId: adminId,
          idempotencyKey: `admin:${crypto.randomUUID()}`,
        },
      });
      return to;
    };

    if (target.diamonds !== undefined) diamonds = await write('diamonds', diamonds, clampAbs(target.diamonds));
    if (target.tickets !== undefined) tickets = await write('tickets', tickets, clampAbs(target.tickets));

    await db.currencyData.update({ where: { userId }, data: { diamonds, tickets } });
    return { diamonds, tickets };
  });
}

function isUniqueViolation(err: unknown): boolean {
  return Boolean(err && typeof err === 'object' && 'code' in err && (err as { code: string }).code === 'P2002');
}
