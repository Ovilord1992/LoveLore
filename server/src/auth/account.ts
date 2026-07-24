import crypto from 'crypto';
import prisma from '../db';
import { logger } from '../utils/logger';

/**
 * Удаление аккаунта (анонимизация) и экспорт данных — требования сторов/GDPR
 * (спека 4.7).
 *
 * Удаление НЕ стирает строку User: она анонимизируется, а финансовый след
 * (CurrencyLedger, IapTransaction, AnalyticsEvent, PromoRedemption) остаётся
 * привязанным к анонимной записи.
 */

export async function deleteAccount(userId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { id: true } });
  if (!user) return false;

  await prisma.$transaction(async (db) => {
    // Пользовательские данные — удаляются.
    await db.gameSave.deleteMany({ where: { userId } });
    await db.userProfileData.deleteMany({ where: { userId } });
    await db.currencyData.deleteMany({ where: { userId } });
    await db.favorite.deleteMany({ where: { userId } });
    await db.rating.deleteMany({ where: { userId } });
    await db.review.deleteMany({ where: { userId } });

    // Все refresh-токены — отозваны.
    await db.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });

    // Анонимизация + глобальный отзыв access-токенов (tokenVersion++).
    await db.user.update({
      where: { id: userId },
      data: {
        email: `deleted-${userId}@deleted.local`,
        passwordHash: crypto.randomBytes(32).toString('hex'),
        displayName: '',
        tokenVersion: { increment: 1 },
      },
    });
  });

  logger.info({ userId }, '[account] account deleted (anonymized)');
  return true;
}

/**
 * Экспорт всех данных пользователя одним JSON — без passwordHash, токенов
 * и чувствительных полей IAP (receiptHash, rawResponseLog).
 */
export async function exportUserData(userId: string): Promise<Record<string, unknown> | null> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      email: true,
      displayName: true,
      role: true,
      vipExpiresAt: true,
      lastActiveAt: true,
      createdAt: true,
      updatedAt: true,
    },
  });
  if (!user) return null;

  const [profile, saves, currency, favorites, ratings, reviews, ledger, iapTransactions, promoRedemptions] =
    await Promise.all([
      prisma.userProfileData.findUnique({
        where: { userId },
        select: {
          displayName: true,
          avatarIndex: true,
          totalNovelsStarted: true,
          totalNovelsCompleted: true,
          totalChoicesMade: true,
          totalChaptersRead: true,
          unlockedCGs: true,
          achievements: true,
          updatedAt: true,
        },
      }),
      prisma.gameSave.findMany({
        where: { userId },
        select: { novelId: true, data: true, updatedAt: true },
      }),
      prisma.currencyData.findUnique({
        where: { userId },
        select: { diamonds: true, tickets: true, lastTicketRefill: true, updatedAt: true },
      }),
      prisma.favorite.findMany({
        where: { userId },
        select: { novelId: true, createdAt: true },
      }),
      prisma.rating.findMany({
        where: { userId },
        select: { novelId: true, value: true, createdAt: true, updatedAt: true },
      }),
      prisma.review.findMany({
        where: { userId },
        select: { novelId: true, text: true, status: true, createdAt: true },
      }),
      prisma.currencyLedger.findMany({
        where: { userId },
        orderBy: { createdAt: 'asc' },
        select: { currency: true, delta: true, reason: true, refId: true, createdAt: true },
      }),
      prisma.iapTransaction.findMany({
        where: { userId },
        select: {
          platform: true,
          productId: true,
          transactionId: true,
          verified: true,
          rewardClaimed: true,
          revokedAt: true,
          usdCents: true,
          createdAt: true,
        },
      }),
      prisma.promoRedemption.findMany({
        where: { userId },
        select: { createdAt: true, code: { select: { code: true } } },
      }),
    ]);

  return {
    exportedAt: new Date().toISOString(),
    user,
    profile,
    saves,
    currency,
    favorites,
    ratings,
    reviews,
    ledger,
    iapTransactions,
    promoRedemptions: promoRedemptions.map((r) => ({
      code: r.code?.code ?? null,
      createdAt: r.createdAt,
    })),
  };
}
