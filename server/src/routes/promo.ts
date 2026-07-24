import { Router, Response } from 'express';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { promoRedeemLimiter } from '../middleware/rate-limit';
import { redeemPromoCode } from '../promo/service';
import { logger } from '../utils/logger';

export const promoRouter = Router();

// ─── POST /v1/promo/redeem ── Погасить промокод (спека 4.5) ──────────────────
// 200 { reward: { diamonds, tickets, vipDays }, balances }
// 404 — нет кода / неактивен; 410 — истёк или исчерпан; 409 — уже погашен.
promoRouter.post(
  '/redeem',
  authMiddleware,
  promoRedeemLimiter,
  async (req: AuthRequest, res: Response) => {
    try {
      const { code } = req.body ?? {};
      if (typeof code !== 'string' || code.trim().length === 0 || code.length > 64) {
        res.status(400).json({ error: 'code is required (string, <= 64 chars)' });
        return;
      }

      const result = await redeemPromoCode(req.userId!, code);
      switch (result.status) {
        case 'ok':
          res.json({ reward: result.reward, balances: result.balances });
          return;
        case 'not_found':
          res.status(404).json({ error: 'Promo code not found' });
          return;
        case 'expired':
          res.status(410).json({ error: 'Promo code expired' });
          return;
        case 'exhausted':
          res.status(410).json({ error: 'Promo code exhausted' });
          return;
        case 'already_redeemed':
          res.status(409).json({ error: 'Promo code already redeemed' });
          return;
      }
    } catch (err) {
      logger.error({ err }, '[promo] redeem error');
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);
