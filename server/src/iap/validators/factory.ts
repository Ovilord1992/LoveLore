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
    // Mock всегда возвращает verified=true — в production это отдало бы награды
    // за любой поддельный чек. Запрещаем mock при NODE_ENV=production; локальный
    // dev/test (NODE_ENV не production) продолжает использовать mock как раньше.
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'IAP_VALIDATOR=mock is not allowed in production — set IAP_VALIDATOR=real'
      );
    }
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
