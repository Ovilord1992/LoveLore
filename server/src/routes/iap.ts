import { Router, Response } from 'express';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { iapVerifyLimiter } from '../middleware/rate-limit';
import { logger } from '../utils/logger';
import { processIapPurchase } from '../iap/service';
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
