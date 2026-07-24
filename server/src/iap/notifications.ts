import fs from 'fs';
import path from 'path';
import { OAuth2Client } from 'google-auth-library';
import {
  Environment,
  SignedDataVerifier,
  type ResponseBodyV2DecodedPayload,
} from '@apple/app-store-server-library';
import prisma from '../db';
import { logger } from '../utils/logger';
import { revokeIapTransaction, revokeIapByReceiptHash, type RevokeOutcome } from './revocation';

/**
 * S2S-нотификации сторов (спека 2.6).
 * Без валидной подписи никакие действия не выполняются: сырой payload
 * сохраняется в StoreNotification, ответ — 200.
 */

export interface NotificationOutcome {
  action: string;
}

// ─── Общее: сохранение сырой нотификации ─────────────────────────────────────

async function storeNotification(data: {
  platform: string;
  messageId?: string | null;
  type?: string | null;
  transactionId?: string | null;
  payload: unknown;
  processed: boolean;
  error?: string | null;
}): Promise<{ id: string } | 'duplicate'> {
  try {
    const row = await prisma.storeNotification.create({
      data: {
        platform: data.platform,
        messageId: data.messageId ?? null,
        type: data.type ?? null,
        transactionId: data.transactionId ?? null,
        payload: data.payload as object,
        processed: data.processed,
        error: data.error ?? null,
      },
      select: { id: true },
    });
    return row;
  } catch (err) {
    // unique(platform, messageId) — повторная доставка Pub/Sub.
    if (err && typeof err === 'object' && 'code' in err && (err as { code: string }).code === 'P2002') {
      return 'duplicate';
    }
    throw err;
  }
}

async function markProcessed(id: string, error?: string | null): Promise<void> {
  await prisma.storeNotification.update({
    where: { id },
    data: { processed: true, error: error ?? null },
  });
}

// ─── Apple: App Store Server Notifications V2 ────────────────────────────────

const APPLE_REVOKE_TYPES: ReadonlySet<string> = new Set(['REFUND', 'REVOKE', 'EXPIRED']);

let appleVerifier: SignedDataVerifier | null | undefined;

/**
 * Верификатор подписи Apple. Требует:
 *  - APPLE_BUNDLE_ID — bundle id приложения;
 *  - APPLE_ROOT_CA_DIR — директория с DER-корневыми сертификатами Apple (.cer);
 *  - APPLE_ENV — Sandbox | Production (дефолт Production);
 *  - APPLE_APP_APPLE_ID — числовой App ID (обязателен для Production).
 * Если не настроен — нотификации только сохраняются (без действий).
 */
function getAppleVerifier(): SignedDataVerifier | null {
  if (appleVerifier !== undefined) return appleVerifier;
  appleVerifier = null;
  try {
    const bundleId = process.env.APPLE_BUNDLE_ID || '';
    const certDir = process.env.APPLE_ROOT_CA_DIR || '';
    if (!bundleId || !certDir || !fs.existsSync(certDir)) {
      logger.warn('[iap] Apple notification verifier not configured (APPLE_BUNDLE_ID / APPLE_ROOT_CA_DIR) — storing raw payloads only');
      return null;
    }
    const certs = fs
      .readdirSync(certDir)
      .filter((f) => /\.(cer|der|pem)$/i.test(f))
      .map((f) => fs.readFileSync(path.join(certDir, f)));
    if (certs.length === 0) {
      logger.warn({ certDir }, '[iap] no Apple root certificates found — storing raw payloads only');
      return null;
    }
    const envName = (process.env.APPLE_ENV || 'Production').toLowerCase();
    const environment = envName === 'sandbox' ? Environment.SANDBOX : Environment.PRODUCTION;
    const appAppleIdRaw = process.env.APPLE_APP_APPLE_ID || '';
    const appAppleId = appAppleIdRaw ? Number(appAppleIdRaw) : undefined;
    if (environment === Environment.PRODUCTION && appAppleId === undefined) {
      logger.warn('[iap] APPLE_APP_APPLE_ID is required for Production Apple notifications — storing raw payloads only');
      return null;
    }
    appleVerifier = new SignedDataVerifier(certs, true, environment, bundleId, appAppleId);
  } catch (err) {
    logger.warn({ err }, '[iap] failed to init Apple verifier — storing raw payloads only');
    appleVerifier = null;
  }
  return appleVerifier;
}

/** Для тестов. */
export function resetAppleVerifierCache(): void {
  appleVerifier = undefined;
}

export async function processAppleNotification(signedPayload: string): Promise<NotificationOutcome> {
  const verifier = getAppleVerifier();

  if (!verifier) {
    await storeNotification({
      platform: 'apple',
      payload: { signedPayload },
      processed: false,
      error: 'verification not configured',
    });
    return { action: 'stored_unverified' };
  }

  let decoded: ResponseBodyV2DecodedPayload;
  try {
    decoded = await verifier.verifyAndDecodeNotification(signedPayload);
  } catch (err) {
    logger.warn({ err }, '[iap] Apple notification signature verification failed');
    await storeNotification({
      platform: 'apple',
      payload: { signedPayload },
      processed: false,
      error: 'signature verification failed',
    });
    return { action: 'stored_invalid_signature' };
  }

  const type = decoded.notificationType ?? null;
  let originalTransactionId: string | null = null;
  if (decoded.data?.signedTransactionInfo) {
    try {
      const txInfo = await verifier.verifyAndDecodeTransaction(decoded.data.signedTransactionInfo);
      originalTransactionId = txInfo.originalTransactionId ?? txInfo.transactionId ?? null;
    } catch (err) {
      logger.warn({ err }, '[iap] Apple transaction info verification failed');
    }
  }

  const stored = await storeNotification({
    platform: 'apple',
    type,
    transactionId: originalTransactionId,
    payload: { signedPayload, decoded: JSON.parse(JSON.stringify(decoded)) },
    processed: false,
  });
  if (stored === 'duplicate') return { action: 'duplicate' };

  if (type && APPLE_REVOKE_TYPES.has(type) && originalTransactionId) {
    const outcome = await revokeIapTransaction('apple', originalTransactionId);
    await markProcessed(stored.id, outcome === 'revoked' ? null : outcome);
    return { action: `revoke:${outcome}` };
  }

  await markProcessed(stored.id, null);
  return { action: 'ignored' };
}

// ─── Google: Real-time Developer Notifications (Pub/Sub push) ────────────────

/** Google SUBSCRIPTION_REVOKED (RTDN subscriptionNotification.notificationType). */
const GOOGLE_SUBSCRIPTION_REVOKED = 12;

const oidcClient = new OAuth2Client();

/** Верификация OIDC Bearer-токена Pub/Sub push (audience из env GOOGLE_RTDN_AUDIENCE). */
export async function verifyGoogleRtdnAuth(
  authHeader: string | undefined,
  audience: string
): Promise<boolean> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return false;
  try {
    await oidcClient.verifyIdToken({ idToken: authHeader.slice(7), audience });
    return true;
  } catch (err) {
    logger.warn({ err }, '[iap] Google RTDN OIDC verification failed');
    return false;
  }
}

export interface GoogleRtdnEnvelope {
  message?: { data?: unknown; messageId?: unknown };
  subscription?: unknown;
}

interface GoogleDeveloperNotification {
  version?: string;
  packageName?: string;
  subscriptionNotification?: { notificationType?: number; purchaseToken?: string; subscriptionId?: string };
  oneTimeProductNotification?: { notificationType?: number; purchaseToken?: string; sku?: string };
  voidedPurchaseNotification?: { purchaseToken?: string; orderId?: string; productType?: number; refundType?: number };
}

function decodeGoogleData(dataB64: unknown): GoogleDeveloperNotification | null {
  if (typeof dataB64 !== 'string' || dataB64.length === 0) return null;
  try {
    return JSON.parse(Buffer.from(dataB64, 'base64').toString('utf-8'));
  } catch {
    return null;
  }
}

function googleNotificationType(decoded: GoogleDeveloperNotification | null): string | null {
  if (!decoded) return null;
  if (decoded.voidedPurchaseNotification) return 'voided_purchase';
  if (decoded.subscriptionNotification) {
    return `subscription:${decoded.subscriptionNotification.notificationType ?? 'unknown'}`;
  }
  if (decoded.oneTimeProductNotification) {
    return `one_time:${decoded.oneTimeProductNotification.notificationType ?? 'unknown'}`;
  }
  return null;
}

/**
 * Обработка RTDN-конверта. `verified=false` → только сохранение сырого payload
 * (никаких действий). Идемпотентность по messageId (unique в StoreNotification).
 */
export async function processGoogleNotification(
  envelope: GoogleRtdnEnvelope,
  verified: boolean
): Promise<NotificationOutcome> {
  const messageId =
    typeof envelope?.message?.messageId === 'string' && envelope.message.messageId.length > 0
      ? envelope.message.messageId
      : null;
  const decoded = decodeGoogleData(envelope?.message?.data);

  const stored = await storeNotification({
    platform: 'google',
    messageId,
    type: googleNotificationType(decoded),
    transactionId: decoded?.voidedPurchaseNotification?.orderId ?? null,
    payload: envelope as object,
    processed: false,
    error: verified ? null : 'verification skipped or failed',
  });
  if (stored === 'duplicate') return { action: 'duplicate' };

  if (!verified) return { action: 'stored_unverified' };
  if (!decoded) {
    await markProcessed(stored.id, 'undecodable message.data');
    return { action: 'stored_undecodable' };
  }

  const voided = decoded.voidedPurchaseNotification;
  if (voided && (voided.orderId || voided.purchaseToken)) {
    let outcome: RevokeOutcome = 'not_found';
    if (voided.orderId) {
      outcome = await revokeIapTransaction('google', voided.orderId);
    }
    if (outcome === 'not_found' && voided.purchaseToken) {
      outcome = await revokeIapByReceiptHash('google', voided.purchaseToken);
    }
    await markProcessed(stored.id, outcome === 'revoked' ? null : outcome);
    return { action: `revoke:${outcome}` };
  }

  const sub = decoded.subscriptionNotification;
  if (sub && sub.notificationType === GOOGLE_SUBSCRIPTION_REVOKED && sub.purchaseToken) {
    const outcome = await revokeIapByReceiptHash('google', sub.purchaseToken);
    await markProcessed(stored.id, outcome === 'revoked' ? null : outcome);
    return { action: `revoke:${outcome}` };
  }

  await markProcessed(stored.id, null);
  return { action: 'ignored' };
}
