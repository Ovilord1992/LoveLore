import { Router, Response } from 'express';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { economyLimiter } from '../middleware/rate-limit';
import { applyClientOperations, loadEconomyRules } from '../economy/ledger';
import { logger } from '../utils/logger';

export const economyRouter = Router();

const MAX_BATCH = 100;

// ─── POST /v1/economy/transactions ── Батч операций с идемпотентностью ───────
economyRouter.post(
  '/transactions',
  authMiddleware,
  economyLimiter,
  async (req: AuthRequest, res: Response) => {
    try {
      const { transactions } = req.body ?? {};

      if (!Array.isArray(transactions) || transactions.length === 0) {
        res.status(400).json({ error: 'transactions array is required' });
        return;
      }
      if (transactions.length > MAX_BATCH) {
        res.status(400).json({ error: `too many transactions (max ${MAX_BATCH})` });
        return;
      }

      const rules = await loadEconomyRules();
      const { results, balances } = await applyClientOperations(req.userId!, transactions, rules);

      res.json({ results, balances });
    } catch (err) {
      logger.error({ err }, '[economy] transactions error');
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);
