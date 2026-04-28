import type { IapValidator, VerifyRequest, VerifyResult } from './types';

const PROD_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

/**
 * Валидатор чеков Apple App Store через legacy verifyReceipt API.
 *
 * Требует APPLE_SHARED_SECRET (App-Specific Shared Secret из App Store Connect).
 *
 * Алгоритм:
 *   1. POST на production endpoint.
 *   2. Если status=21007 — это sandbox-чек, повторяем на sandbox endpoint.
 *   3. Ищем в latest_receipt_info / in_app запись с нашим productId.
 *   4. Берём original_transaction_id (id для дедупликации) и expires_date_ms (для подписок).
 *
 * Note: Apple рекомендует мигрировать на App Store Server API (JWT-based).
 * verifyReceipt deprecated, но работает и проще для MVP.
 */
export class AppleValidator implements IapValidator {
  private readonly sharedSecret: string;

  constructor() {
    const secret = process.env.APPLE_SHARED_SECRET || '';
    if (!secret) {
      throw new Error('Apple validator not configured (set APPLE_SHARED_SECRET)');
    }
    this.sharedSecret = secret;
  }

  async verify(req: VerifyRequest): Promise<VerifyResult> {
    try {
      let response = await this.callVerify(PROD_URL, req.receipt);

      // 21007 = "this receipt is from sandbox, try sandbox endpoint"
      if (response.status === 21007) {
        response = await this.callVerify(SANDBOX_URL, req.receipt);
      }

      if (response.status !== 0) {
        return {
          verified: false,
          transactionId: null,
          productId: req.productId,
          isSubscription: false,
          raw: response,
          error: `Apple verifyReceipt failed: status=${response.status}`,
        };
      }

      // Ищем нужную транзакцию.
      // Для подписок свежие данные в latest_receipt_info, для consumables — в receipt.in_app.
      const latest: AppleInAppEntry[] = Array.isArray(response.latest_receipt_info)
        ? response.latest_receipt_info
        : [];
      const inApp: AppleInAppEntry[] = Array.isArray(response.receipt?.in_app)
        ? response.receipt!.in_app!
        : [];

      const candidates = [...latest, ...inApp].filter(
        (e) => e && e.product_id === req.productId
      );

      if (candidates.length === 0) {
        return {
          verified: false,
          transactionId: null,
          productId: req.productId,
          isSubscription: false,
          raw: response,
          error: `productId ${req.productId} not found in Apple receipt`,
        };
      }

      // Самая свежая запись по purchase_date_ms
      candidates.sort((a, b) => {
        const aMs = parseInt(a.purchase_date_ms || '0', 10);
        const bMs = parseInt(b.purchase_date_ms || '0', 10);
        return bMs - aMs;
      });
      const entry = candidates[0]!;

      const isSubscription = !!entry.expires_date_ms;
      const expiresAt = entry.expires_date_ms
        ? new Date(parseInt(entry.expires_date_ms, 10))
        : undefined;

      // Для подписки: проверяем что не истекла.
      if (isSubscription && expiresAt && expiresAt.getTime() < Date.now()) {
        return {
          verified: false,
          transactionId: null,
          productId: req.productId,
          isSubscription: true,
          expiresAt,
          raw: response,
          error: 'Subscription expired',
        };
      }

      return {
        verified: true,
        transactionId: entry.original_transaction_id || entry.transaction_id || null,
        productId: entry.product_id,
        isSubscription,
        expiresAt,
        raw: response,
      };
    } catch (err) {
      return {
        verified: false,
        transactionId: null,
        productId: req.productId,
        isSubscription: false,
        error: `Apple verify exception: ${(err as Error).message}`,
      };
    }
  }

  private async callVerify(url: string, receipt: string): Promise<AppleVerifyResponse> {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        'receipt-data': receipt,
        password: this.sharedSecret,
        'exclude-old-transactions': true,
      }),
    });

    if (!res.ok) {
      throw new Error(`Apple verifyReceipt HTTP ${res.status}`);
    }

    return (await res.json()) as AppleVerifyResponse;
  }
}

// ─── Типы ответа Apple verifyReceipt ────────────────────────────────────────

interface AppleInAppEntry {
  product_id: string;
  transaction_id?: string;
  original_transaction_id?: string;
  purchase_date_ms?: string;
  expires_date_ms?: string;
}

interface AppleVerifyResponse {
  status: number;
  environment?: string;
  receipt?: {
    in_app?: AppleInAppEntry[];
  };
  latest_receipt_info?: AppleInAppEntry[];
  latest_receipt?: string;
}
