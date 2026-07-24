import crypto from 'crypto';
import prisma from '../db';
import { logger } from '../utils/logger';
import { getRewardForProduct } from './rewards';

/**
 * Отзыв покупки по S2S-нотификации стора (refund/revoke/expired):
 * IapTransaction.revokedAt, отзыв VIP (если продукт VIP), компенсирующая
 * запись в леджер (кламп баланса ≥ 0). Идемпотентен.
 */

export type RevokeOutcome = 'revoked' | 'not_found' | 'already_revoked';

export async function revokeIapTransaction(platform: string, transactionId: string): Promise<RevokeOutcome> {
  const tx = await prisma.iapTransaction.findUnique({
    where: { platform_transactionId: { platform, transactionId } },
  });
  if (!tx || !tx.verified) return 'not_found';
  if (tx.revokedAt) return 'already_revoked';

  const reward = await getRewardForProduct(tx.productId);

  try {
    await prisma.$transaction(async (db) => {
      await db.iapTransaction.update({
        where: { id: tx.id },
        data: { revokedAt: new Date() },
      });

      // Компенсация валюты — только если награда была реально выдана.
      if (tx.rewardClaimed && (reward.diamonds || reward.tickets)) {
        const cur = await db.currencyData.findUnique({ where: { userId: tx.userId } });
        if (cur) {
          let diamonds = cur.diamonds;
          let tickets = cur.tickets;

          if (reward.diamonds) {
            const delta = -Math.min(reward.diamonds, diamonds);
            if (delta !== 0) {
              await db.currencyLedger.create({
                data: {
                  userId: tx.userId,
                  currency: 'diamonds',
                  delta,
                  reason: 'iap_refund',
                  refId: transactionId,
                  idempotencyKey: `iap_refund:${platform}:${transactionId}:diamonds`,
                },
              });
              diamonds += delta;
            }
          }
          if (reward.tickets) {
            const delta = -Math.min(reward.tickets, tickets);
            if (delta !== 0) {
              await db.currencyLedger.create({
                data: {
                  userId: tx.userId,
                  currency: 'tickets',
                  delta,
                  reason: 'iap_refund',
                  refId: transactionId,
                  idempotencyKey: `iap_refund:${platform}:${transactionId}:tickets`,
                },
              });
              tickets += delta;
            }
          }
          await db.currencyData.update({
            where: { userId: tx.userId },
            data: { diamonds, tickets },
          });
        }
      }

      // Отзыв VIP: продукт с vipDays → срезаем vipExpiresAt до "сейчас".
      if (reward.vipDays && reward.vipDays > 0) {
        const user = await db.user.findUnique({
          where: { id: tx.userId },
          select: { vipExpiresAt: true },
        });
        if (user?.vipExpiresAt && user.vipExpiresAt.getTime() > Date.now()) {
          await db.user.update({
            where: { id: tx.userId },
            data: { vipExpiresAt: new Date() },
          });
        }
      }
    });
  } catch (err) {
    // P2002 на леджере — параллельный отзыв уже прошёл.
    if (err && typeof err === 'object' && 'code' in err && (err as { code: string }).code === 'P2002') {
      return 'already_revoked';
    }
    throw err;
  }

  logger.info({ platform, transactionId, userId: tx.userId, productId: tx.productId }, '[iap] transaction revoked');
  return 'revoked';
}

/** Отзыв по хэшу receipt/purchaseToken (Google subscription RTDN не содержит orderId). */
export async function revokeIapByReceiptHash(platform: string, receipt: string): Promise<RevokeOutcome> {
  const receiptHash = crypto.createHash('sha256').update(receipt).digest('hex');
  const tx = await prisma.iapTransaction.findFirst({
    where: { platform, receiptHash, verified: true },
    orderBy: { createdAt: 'desc' },
  });
  if (!tx) return 'not_found';
  return revokeIapTransaction(platform, tx.transactionId);
}
