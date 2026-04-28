import crypto from 'crypto';
import type { IapValidator, VerifyRequest, VerifyResult } from './types';

/**
 * Mock-валидатор для dev/test окружений.
 *
 * Всегда возвращает verified=true с уникальным transactionId.
 * Используется когда IAP_VALIDATOR=mock (по умолчанию) — не требует
 * настройки секретов App Store / Google Play.
 *
 * НЕ ИСПОЛЬЗОВАТЬ В ПРОДАКШЕНЕ.
 */
export class MockValidator implements IapValidator {
  async verify(req: VerifyRequest): Promise<VerifyResult> {
    const transactionId = `mock-${crypto.randomUUID()}`;
    const isSubscription =
      req.productId === 'vip_monthly' || req.productId.startsWith('vip_');

    const result: VerifyResult = {
      verified: true,
      transactionId,
      productId: req.productId,
      isSubscription,
      raw: { mock: true, receivedReceiptLength: req.receipt.length },
    };

    if (isSubscription) {
      // 30 дней по умолчанию
      result.expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    }

    return result;
  }
}
