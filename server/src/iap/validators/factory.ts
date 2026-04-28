import type { IapPlatform, IapValidator } from './types';
import { MockValidator } from './mock';
import { AppleValidator } from './apple';
import { GoogleValidator } from './google';

/**
 * Возвращает валидатор для указанной платформы.
 *
 * Поведение зависит от env IAP_VALIDATOR:
 *   - 'mock' (по умолчанию) — всегда MockValidator (dev/test)
 *   - 'real' — реальный валидатор по платформе (apple|google)
 *
 * Конструкторы Apple/Google валидаторов кидают исключение, если их env
 * не настроены — это намеренно, чтобы prod не молча работал в mock-режиме.
 */
export function getValidator(platform: IapPlatform): IapValidator {
  const mode = process.env.IAP_VALIDATOR || 'mock';

  if (mode === 'mock') {
    return new MockValidator();
  }

  if (platform === 'apple') {
    return new AppleValidator();
  }
  if (platform === 'google') {
    return new GoogleValidator();
  }

  throw new Error(`Unknown platform: ${platform}`);
}
