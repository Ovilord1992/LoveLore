import crypto from 'crypto';
import prisma from '../db';
import { logger } from '../utils/logger';
import { getValidator } from './validators/factory';
import type { VerifyRequest } from './validators/types';
import { getRewardForProduct, type Reward } from './rewards';

export type ProcessStatus = 'success' | 'already_claimed' | 'invalid';

export interface ProcessResult {
  status: ProcessStatus;
  rewards?: Reward;
  newBalance?: { diamonds: number; tickets: number };
  vipExpiresAt?: Date | null;
  error?: string;
}

/**
 * Главный orchestrator серверной IAP-валидации.
 *
 * Шаги:
 *   1. SHA-256 от receipt — для дедуп-логики и хранения без раскрытия чека.
 *   2. Валидация через store API (Apple/Google/Mock).
 *   3. Если invalid — пишем audit-запись (verified=false), возвращаем 'invalid'.
 *   4. Дедупликация по (platform, transactionId): если уже claimed — возвращаем
 *      'already_claimed' (idempotent), иначе — продолжаем (повтор после краша).
 *   5. Атомарно: upsert IapTransaction(verified, claimed) + начисление в одной БД-транзакции.
 *   6. Consumables → currency, подписки → user.vipExpiresAt.
 */
export async function processIapPurchase(req: VerifyRequest): Promise<ProcessResult> {
  const receiptHash = sha256(req.receipt);
  const validator = getValidator(req.platform);
  const result = await validator.verify(req);

  // ─── Невалидно: audit-запись и выходим ────────────────────────────────────
  if (!result.verified || !result.transactionId) {
    try {
      await prisma.iapTransaction.create({
        data: {
          userId: req.userId,
          platform: req.platform,
          productId: req.productId,
          transactionId: `invalid-${crypto.randomUUID()}`,
          receiptHash,
          verified: false,
          rewardClaimed: false,
          // rawResponseLog не сохраняем — см. комментарий в _runAwardTransaction.
        },
      });
    } catch (err) {
      logger.warn({ err }, '[iap] failed to write invalid audit record');
    }
    return { status: 'invalid', error: result.error || 'Receipt verification failed' };
  }

  const platform = req.platform;
  const transactionId = result.transactionId;
  const productId = result.productId; // подтверждённый стором

  // ─── Дедупликация ────────────────────────────────────────────────────────
  const existing = await prisma.iapTransaction.findUnique({
    where: { platform_transactionId: { platform, transactionId } },
  });

  if (existing && existing.rewardClaimed) {
    // Уже выдавали — возвращаем баланс ТЕКУЩЕГО запрашивающего пользователя
    // (req.userId), а не владельца исходной транзакции (existing.userId): иначе
    // при повторной отправке чужого чека утёк бы баланс другого юзера.
    const [currency, user] = await Promise.all([
      prisma.currencyData.findUnique({ where: { userId: req.userId } }),
      prisma.user.findUnique({
        where: { id: req.userId },
        select: { vipExpiresAt: true },
      }),
    ]);
    return {
      status: 'already_claimed',
      newBalance: currency
        ? { diamonds: currency.diamonds, tickets: currency.tickets }
        : undefined,
      vipExpiresAt: user?.vipExpiresAt ?? null,
    };
  }

  // ─── Получаем reward ─────────────────────────────────────────────────────
  const reward = await getRewardForProduct(productId);

  // ─── Атомарное начисление ────────────────────────────────────────────────
  let tx: { newCurrency: { diamonds: number; tickets: number } | undefined; newVipExpiresAt: Date | null };
  try {
    tx = await _runAwardTransaction(req.userId, platform, transactionId, productId, receiptHash, result.raw, reward);
  } catch (err: unknown) {
    // Race condition: другая параллельная verify создала запись с тем же
    // (platform, transactionId) → P2002 unique constraint violation.
    // Возвращаем already_claimed с текущим балансом — другой запрос уже начислил.
    if (err && typeof err === 'object' && 'code' in err && (err as { code: string }).code === 'P2002') {
      logger.warn({ platform, transactionId }, '[iap] concurrent verify hit unique constraint, treating as already_claimed');
      const [currency, user] = await Promise.all([
        prisma.currencyData.findUnique({ where: { userId: req.userId } }),
        prisma.user.findUnique({ where: { id: req.userId }, select: { vipExpiresAt: true } }),
      ]);
      return {
        status: 'already_claimed',
        newBalance: currency ? { diamonds: currency.diamonds, tickets: currency.tickets } : undefined,
        vipExpiresAt: user?.vipExpiresAt ?? null,
      };
    }
    throw err;
  }

  return {
    status: 'success',
    rewards: reward,
    newBalance: tx.newCurrency,
    vipExpiresAt: tx.newVipExpiresAt,
  };
}

async function _runAwardTransaction(
  userId: string,
  platform: string,
  transactionId: string,
  productId: string,
  receiptHash: string,
  rawResponse: unknown,
  reward: Reward,
): Promise<{ newCurrency: { diamonds: number; tickets: number } | undefined; newVipExpiresAt: Date | null }> {
  return prisma.$transaction(async (db) => {
    // 1. upsert транзакции
    // Note: rawResponseLog не сохраняем — может содержать чувствительные данные
    // (transactionId стора, email из Apple, orderId Google). Если нужен дебаг
    // продакшна — включать через env-флаг с маскированием.
    await db.iapTransaction.upsert({
      where: { platform_transactionId: { platform, transactionId } },
      update: {
        verified: true,
        rewardClaimed: true,
      },
      create: {
        userId,
        platform,
        productId,
        transactionId,
        receiptHash,
        verified: true,
        rewardClaimed: true,
      },
    });

    // 2. Currency (consumables)
    let newCurrency: { diamonds: number; tickets: number } | undefined;
    if (reward.diamonds || reward.tickets) {
      const updated = await db.currencyData.upsert({
        where: { userId },
        update: {
          diamonds: { increment: reward.diamonds ?? 0 },
          tickets: { increment: reward.tickets ?? 0 },
        },
        create: {
          userId,
          diamonds: 50 + (reward.diamonds ?? 0),
          tickets: 5 + (reward.tickets ?? 0),
        },
        select: { diamonds: true, tickets: true },
      });
      newCurrency = { diamonds: updated.diamonds, tickets: updated.tickets };
    } else {
      const cur = await db.currencyData.findUnique({
        where: { userId },
        select: { diamonds: true, tickets: true },
      });
      if (cur) newCurrency = { diamonds: cur.diamonds, tickets: cur.tickets };
    }

    // 3. VIP (subscriptions): vipExpiresAt = max(now, current) + vipDays * 24h
    let newVipExpiresAt: Date | null = null;
    if (reward.vipDays && reward.vipDays > 0) {
      const userBefore = await db.user.findUnique({
        where: { id: userId },
        select: { vipExpiresAt: true },
      });
      const now = Date.now();
      const baseMs = Math.max(now, userBefore?.vipExpiresAt?.getTime() ?? 0);
      newVipExpiresAt = new Date(baseMs + reward.vipDays * 24 * 60 * 60 * 1000);
      await db.user.update({
        where: { id: userId },
        data: { vipExpiresAt: newVipExpiresAt },
      });
    } else {
      const u = await db.user.findUnique({
        where: { id: userId },
        select: { vipExpiresAt: true },
      });
      newVipExpiresAt = u?.vipExpiresAt ?? null;
    }

    return { newCurrency, newVipExpiresAt };
  });
}

function sha256(s: string): string {
  return crypto.createHash('sha256').update(s).digest('hex');
}
