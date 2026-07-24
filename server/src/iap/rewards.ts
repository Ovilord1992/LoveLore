import prisma from '../db';

/**
 * Награда за продукт IAP — что начислять пользователю после покупки.
 * Источник правды — RemoteConfig (GameConfig.iap), не хардкод.
 */
export interface Reward {
  diamonds?: number;
  tickets?: number;
  vipDays?: number;
}

/**
 * Возвращает награду для указанного productId на основе RemoteConfig.
 *
 * Структура GameConfig.iap (см. seed.ts):
 *   {
 *     "diamonds_20":  { "diamonds": 20 },
 *     "starter_bundle": { "diamonds": 100, "tickets": 10 },
 *     "vip_monthly": { "vipDays": 30 }
 *   }
 *
 * Если productId начинается с 'vip_' и в конфиге не указано vipDays —
 * по умолчанию подставляем 30 дней (месячная подписка).
 */
export async function getRewardForProduct(productId: string): Promise<Reward> {
  const config = await prisma.gameConfig.findUnique({
    where: { id: 'singleton' },
    select: { iap: true },
  });

  const iapConfig = (config?.iap as Record<string, Reward> | null | undefined) || {};
  const reward: Reward = { ...(iapConfig[productId] || {}) };

  // VIP: если конфиг не содержит явного vipDays для подписки — дефолт 30 дней.
  if (productId.startsWith('vip_') && reward.vipDays == null) {
    reward.vipDays = 30;
  }

  return reward;
}

/**
 * Пуст ли reward (нечего начислять).
 */
export function isEmptyReward(r: Reward): boolean {
  return !r.diamonds && !r.tickets && !r.vipDays;
}

/**
 * Оценка суммы покупки в центах USD из iap.products[].usdCents конфига
 * (спека 2.7) — для подсчёта выручки в аналитике.
 */
export async function getUsdCentsForProduct(productId: string): Promise<number | null> {
  const config = await prisma.gameConfig.findUnique({
    where: { id: 'singleton' },
    select: { iap: true },
  });

  const iapConfig = config?.iap as { products?: unknown } | null | undefined;
  const products = Array.isArray(iapConfig?.products) ? iapConfig!.products : [];
  const entry = products.find(
    (p: unknown): p is { id: string; usdCents?: unknown } =>
      !!p && typeof p === 'object' && (p as { id?: unknown }).id === productId
  );
  const usdCents = entry?.usdCents;
  return typeof usdCents === 'number' && Number.isInteger(usdCents) && usdCents >= 0 ? usdCents : null;
}
