import { JWT } from 'google-auth-library';
import type { IapValidator, VerifyRequest, VerifyResult } from './types';

/**
 * Валидатор покупок Google Play через Android Publisher API v3.
 *
 * Требует:
 *   - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON — содержимое JSON-ключа сервисного аккаунта
 *     (с правом androidpublisher.purchases.products.get / subscriptions.get)
 *   - GOOGLE_PLAY_PACKAGE_NAME — имя пакета приложения (например, com.amoria.app)
 *
 * РЕШЕНИЕ ПО БИБЛИОТЕКЕ: используем google-auth-library (уже в зависимостях
 * для Google Sign-In) + ручные fetch к androidpublisher.googleapis.com,
 * вместо googleapis (~50 МБ + 100+ транзитивных пакетов).
 * google-auth-library умеет JWT через сервисный аккаунт + автоматический
 * обмен на access_token, что покрывает всё что нам нужно.
 */
export class GoogleValidator implements IapValidator {
  private readonly packageName: string;
  private readonly jwtClient: JWT;

  constructor() {
    const json = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON || '';
    const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME || '';

    if (!json || !packageName) {
      throw new Error(
        'Google validator not configured (set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON and GOOGLE_PLAY_PACKAGE_NAME)'
      );
    }

    let creds: { client_email: string; private_key: string };
    try {
      creds = JSON.parse(json);
    } catch {
      throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not valid JSON');
    }

    if (!creds.client_email || !creds.private_key) {
      throw new Error(
        'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON missing client_email/private_key'
      );
    }

    this.packageName = packageName;
    this.jwtClient = new JWT({
      email: creds.client_email,
      key: creds.private_key,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
  }

  async verify(req: VerifyRequest): Promise<VerifyResult> {
    try {
      const isSubscription = req.productId.startsWith('vip_');
      const url = isSubscription
        ? this.subscriptionUrl(req.productId, req.receipt)
        : this.productUrl(req.productId, req.receipt);

      const accessToken = await this.getAccessToken();

      const res = await fetch(url, {
        method: 'GET',
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      if (!res.ok) {
        const body = await res.text();
        return {
          verified: false,
          transactionId: null,
          productId: req.productId,
          isSubscription,
          raw: { status: res.status, body },
          error: `Google API HTTP ${res.status}`,
        };
      }

      const data = (await res.json()) as Record<string, unknown>;

      if (isSubscription) {
        return this.parseSubscription(req, data);
      }
      return this.parseProduct(req, data);
    } catch (err) {
      return {
        verified: false,
        transactionId: null,
        productId: req.productId,
        isSubscription: false,
        error: `Google verify exception: ${(err as Error).message}`,
      };
    }
  }

  private async getAccessToken(): Promise<string> {
    const tokens = await this.jwtClient.authorize();
    if (!tokens.access_token) {
      throw new Error('Google JWT did not return access_token');
    }
    return tokens.access_token;
  }

  private productUrl(productId: string, purchaseToken: string): string {
    const pkg = encodeURIComponent(this.packageName);
    const pid = encodeURIComponent(productId);
    const tok = encodeURIComponent(purchaseToken);
    return `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases/products/${pid}/tokens/${tok}`;
  }

  private subscriptionUrl(_productId: string, purchaseToken: string): string {
    const pkg = encodeURIComponent(this.packageName);
    const tok = encodeURIComponent(purchaseToken);
    // subscriptionsv2 не требует subscriptionId в URL — только токен.
    return `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${pkg}/purchases/subscriptionsv2/tokens/${tok}`;
  }

  private parseProduct(req: VerifyRequest, data: Record<string, unknown>): VerifyResult {
    // ProductPurchase: purchaseState 0=Purchased, 1=Canceled, 2=Pending
    const purchaseState = typeof data.purchaseState === 'number' ? data.purchaseState : -1;
    const orderId = typeof data.orderId === 'string' ? data.orderId : '';

    if (purchaseState !== 0) {
      return {
        verified: false,
        transactionId: null,
        productId: req.productId,
        isSubscription: false,
        raw: data,
        error: `Google purchaseState=${purchaseState} (not Purchased)`,
      };
    }

    if (!orderId) {
      return {
        verified: false,
        transactionId: null,
        productId: req.productId,
        isSubscription: false,
        raw: data,
        error: 'Google response missing orderId',
      };
    }

    return {
      verified: true,
      transactionId: orderId,
      productId: req.productId,
      isSubscription: false,
      raw: data,
    };
  }

  private parseSubscription(
    req: VerifyRequest,
    data: Record<string, unknown>
  ): VerifyResult {
    // SubscriptionPurchaseV2:
    //   subscriptionState: SUBSCRIPTION_STATE_ACTIVE | _CANCELED | _EXPIRED | ...
    //   latestOrderId: string
    //   lineItems: [{ expiryTime: ISO string, ... }]
    const state = typeof data.subscriptionState === 'string' ? data.subscriptionState : '';
    const orderId = typeof data.latestOrderId === 'string' ? data.latestOrderId : '';

    const validStates = new Set([
      'SUBSCRIPTION_STATE_ACTIVE',
      'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    ]);

    if (!validStates.has(state)) {
      return {
        verified: false,
        transactionId: null,
        productId: req.productId,
        isSubscription: true,
        raw: data,
        error: `Google subscription state=${state}`,
      };
    }

    if (!orderId) {
      return {
        verified: false,
        transactionId: null,
        productId: req.productId,
        isSubscription: true,
        raw: data,
        error: 'Google subscription missing latestOrderId',
      };
    }

    let expiresAt: Date | undefined;
    const lineItems = Array.isArray(data.lineItems) ? data.lineItems : [];
    for (const item of lineItems) {
      if (item && typeof item === 'object' && 'expiryTime' in item) {
        const t = (item as { expiryTime?: string }).expiryTime;
        if (typeof t === 'string') {
          const d = new Date(t);
          if (!Number.isNaN(d.getTime())) {
            expiresAt = d;
            break;
          }
        }
      }
    }

    return {
      verified: true,
      transactionId: orderId,
      productId: req.productId,
      isSubscription: true,
      expiresAt,
      raw: data,
    };
  }
}
