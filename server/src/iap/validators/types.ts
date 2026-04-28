/**
 * Типы для серверной валидации IAP-чеков (Apple App Store / Google Play).
 *
 * Каждый стор имеет свой формат receipt и свой API верификации,
 * но мы прячем это за единым интерфейсом IapValidator.
 */

export type IapPlatform = 'apple' | 'google';

export interface VerifyRequest {
  platform: IapPlatform;
  productId: string;
  /** raw base64 receipt (Apple) или purchaseToken (Google). */
  receipt: string;
  userId: string;
}

export interface VerifyResult {
  verified: boolean;
  /** null если verified=false. */
  transactionId: string | null;
  /** Подтверждённый productId от стора (может отличаться от запрошенного при подменах). */
  productId: string;
  isSubscription: boolean;
  /** Для подписок — момент истечения. */
  expiresAt?: Date;
  /** Лог ответа стора (для дебага). */
  raw?: unknown;
  /** Человекочитаемое описание ошибки (если verified=false). */
  error?: string;
}

export interface IapValidator {
  verify(req: VerifyRequest): Promise<VerifyResult>;
}
