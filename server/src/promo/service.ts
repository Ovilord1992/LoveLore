import prisma from '../db';
import { clampDelta } from '../economy/ledger';
import { logger } from '../utils/logger';

/**
 * Погашение промокодов (спека 4.5).
 *
 * Начисление атомарно через леджер (reason 'promo', refId = code) в одной
 * транзакции с созданием PromoRedemption и условным инкрементом
 * redemptionsCount (защита от гонки исчерпания). vipDays продлевает
 * vipExpiresAt от max(now, текущего) — как в IAP.
 */

export interface PromoReward {
  diamonds: number;
  tickets: number;
  vipDays: number;
}

export type RedeemResult =
  | { status: 'ok'; reward: PromoReward; balances: { diamonds: number; tickets: number } }
  | { status: 'not_found' }
  | { status: 'expired' }
  | { status: 'exhausted' }
  | { status: 'already_redeemed' };

/** Коды регистронезависимы — храним и сравниваем upper-case. */
export function normalizePromoCode(raw: string): string {
  return raw.trim().toUpperCase();
}

const EXHAUSTED_RACE = 'promo-exhausted-race';

export async function redeemPromoCode(userId: string, rawCode: string): Promise<RedeemResult> {
  const code = normalizePromoCode(rawCode);

  const promo = await prisma.promoCode.findUnique({ where: { code } });
  if (!promo || !promo.isActive) return { status: 'not_found' };

  const now = new Date();
  if (promo.expiresAt && promo.expiresAt.getTime() <= now.getTime()) return { status: 'expired' };
  if (promo.maxRedemptions > 0 && promo.redemptionsCount >= promo.maxRedemptions) {
    return { status: 'exhausted' };
  }

  // Быстрая проверка повтора (гонка закрыта unique(codeId, userId) в транзакции).
  const dup = await prisma.promoRedemption.findUnique({
    where: { codeId_userId: { codeId: promo.id, userId } },
  });
  if (dup) return { status: 'already_redeemed' };

  const reward: PromoReward = {
    diamonds: promo.diamonds,
    tickets: promo.tickets,
    vipDays: promo.vipDays,
  };

  try {
    const balances = await prisma.$transaction(async (db) => {
      // Повторное погашение → P2002 (обрабатывается ниже).
      await db.promoRedemption.create({ data: { codeId: promo.id, userId } });

      // Условный инкремент — гонка исчерпания: если лимит уже выбран
      // параллельным запросом, update не матчится и транзакция откатывается.
      const inc = await db.promoCode.updateMany({
        where: {
          id: promo.id,
          isActive: true,
          ...(promo.maxRedemptions > 0 && {
            redemptionsCount: { lt: promo.maxRedemptions },
          }),
        },
        data: { redemptionsCount: { increment: 1 } },
      });
      if (inc.count === 0) throw new Error(EXHAUSTED_RACE);

      // Начисление валюты через леджер (server-only reason 'promo').
      const cur =
        (await db.currencyData.findUnique({ where: { userId } })) ??
        (await db.currencyData.create({ data: { userId } }));
      let diamonds = cur.diamonds;
      let tickets = cur.tickets;

      const award = async (currency: 'diamonds' | 'tickets', amount: number, balance: number): Promise<number> => {
        const effective = clampDelta(balance, amount);
        if (effective === 0) return balance;
        await db.currencyLedger.create({
          data: {
            userId,
            currency,
            delta: effective,
            reason: 'promo',
            refId: code,
            idempotencyKey: `promo:${promo.id}:${userId}:${currency}`,
          },
        });
        return balance + effective;
      };

      if (reward.diamonds > 0) diamonds = await award('diamonds', reward.diamonds, diamonds);
      if (reward.tickets > 0) tickets = await award('tickets', reward.tickets, tickets);
      if (diamonds !== cur.diamonds || tickets !== cur.tickets) {
        await db.currencyData.update({ where: { userId }, data: { diamonds, tickets } });
      }

      // VIP: продление от max(now, текущего) — как в IAP.
      if (reward.vipDays > 0) {
        const user = await db.user.findUnique({
          where: { id: userId },
          select: { vipExpiresAt: true },
        });
        const baseMs = Math.max(now.getTime(), user?.vipExpiresAt?.getTime() ?? 0);
        await db.user.update({
          where: { id: userId },
          data: { vipExpiresAt: new Date(baseMs + reward.vipDays * 24 * 60 * 60 * 1000) },
        });
      }

      return { diamonds, tickets };
    });

    logger.info({ userId, code }, '[promo] code redeemed');
    return { status: 'ok', reward, balances };
  } catch (err) {
    if (err instanceof Error && err.message === EXHAUSTED_RACE) {
      return { status: 'exhausted' };
    }
    if (isUniqueViolation(err)) {
      // Гонка двух одинаковых погашений — первый уже применил.
      return { status: 'already_redeemed' };
    }
    throw err;
  }
}

function isUniqueViolation(err: unknown): boolean {
  return Boolean(err && typeof err === 'object' && 'code' in err && (err as { code: string }).code === 'P2002');
}
