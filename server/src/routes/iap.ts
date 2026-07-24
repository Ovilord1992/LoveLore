import { Router, Request, Response } from 'express';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { iapVerifyLimiter, storeNotificationsLimiter } from '../middleware/rate-limit';
import { logger } from '../utils/logger';
import { processIapPurchase } from '../iap/service';
import {
  processAppleNotification,
  processGoogleNotification,
  verifyGoogleRtdnAuth,
} from '../iap/notifications';
import type { IapPlatform } from '../iap/validators/types';

export const iapRouter = Router();

const VALID_PLATFORMS: ReadonlySet<string> = new Set(['apple', 'google']);
const MAX_PRODUCT_ID_LEN = 200;
const MAX_RECEIPT_LEN = 100_000; // Apple base64-receipts могут быть большими (~50КБ)

// ─── POST /v1/iap/verify ── Верификация чека и начисление награды ───────────
iapRouter.post(
  '/verify',
  authMiddleware,
  iapVerifyLimiter,
  async (req: AuthRequest, res: Response) => {
    try {
      const { platform, productId, receipt } = req.body ?? {};

      // ── Валидация входа ────────────────────────────────────────────────
      if (typeof platform !== 'string' || !VALID_PLATFORMS.has(platform)) {
        res.status(400).json({ error: 'platform must be "apple" or "google"' });
        return;
      }
      if (typeof productId !== 'string' || productId.length === 0 || productId.length > MAX_PRODUCT_ID_LEN) {
        res.status(400).json({ error: 'productId is required (1..200 chars)' });
        return;
      }
      if (typeof receipt !== 'string' || receipt.length === 0 || receipt.length > MAX_RECEIPT_LEN) {
        res.status(400).json({ error: 'receipt is required (1..100000 chars)' });
        return;
      }
      if (!req.userId) {
        // На всякий случай — authMiddleware должен был отсечь.
        res.status(401).json({ error: 'Authorization required' });
        return;
      }

      const result = await processIapPurchase({
        platform: platform as IapPlatform,
        productId,
        receipt,
        userId: req.userId,
      });

      // ── Маппинг status → HTTP ──────────────────────────────────────────
      if (result.status === 'invalid') {
        res.status(400).json({
          status: 'invalid',
          error: result.error || 'Receipt verification failed',
        });
        return;
      }

      // success | already_claimed → 200
      res.json({
        status: result.status,
        rewards: result.rewards,
        newBalance: result.newBalance,
        vipExpiresAt: result.vipExpiresAt
          ? result.vipExpiresAt instanceof Date
            ? result.vipExpiresAt.toISOString()
            : result.vipExpiresAt
          : null,
      });
    } catch (err) {
      logger.error({ err }, '[iap] verify error');
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ─── POST /v1/iap/notifications/apple ── App Store Server Notifications V2 ──
// Server-to-server, без auth. Без валидной подписи действия не выполняются —
// payload сохраняется в StoreNotification, ответ 200.
iapRouter.post(
  '/notifications/apple',
  storeNotificationsLimiter,
  async (req: Request, res: Response) => {
    try {
      const signedPayload = req.body?.signedPayload;
      if (typeof signedPayload !== 'string' || signedPayload.length === 0) {
        res.status(400).json({ error: 'signedPayload is required' });
        return;
      }

      const result = await processAppleNotification(signedPayload);
      res.json({ received: true, action: result.action });
    } catch (err) {
      logger.error({ err }, '[iap] apple notification error');
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ─── POST /v1/iap/notifications/google ── RTDN через Pub/Sub push ────────────
// Верификация OIDC bearer (audience из env GOOGLE_RTDN_AUDIENCE). Если env не
// задан — только сохранение payload. Идемпотентность по messageId.
iapRouter.post(
  '/notifications/google',
  storeNotificationsLimiter,
  async (req: Request, res: Response) => {
    try {
      const audience = process.env.GOOGLE_RTDN_AUDIENCE || '';
      let verified = false;
      if (audience) {
        verified = await verifyGoogleRtdnAuth(req.headers.authorization, audience);
      }

      const result = await processGoogleNotification(req.body ?? {}, verified);
      res.json({ received: true, action: result.action });
    } catch (err) {
      logger.error({ err }, '[iap] google notification error');
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);
