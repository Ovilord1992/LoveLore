import { Router, Response } from 'express';
import prisma from '../db';
import { AuthRequest, optionalAuthMiddleware } from '../middleware/auth';
import { analyticsLimiter } from '../middleware/rate-limit';
import { logger } from '../utils/logger';

export const analyticsRouter = Router();

/** Фиксированный словарь имён событий клиента (спека 2.3). */
export const ANALYTICS_EVENT_NAMES: ReadonlySet<string> = new Set([
  'session_start',
  'novel_start',
  'chapter_start',
  'chapter_complete',
  'choice_made',
  'ad_reward',
  'iap_success',
  'ending_reached',
  'novel_download',
]);

const MAX_BATCH = 50;
const MAX_PARAMS_BYTES = 1024;
const MAX_TS_PAST_MS = 90 * 24 * 60 * 60 * 1000; // события старше 90 дней не принимаем
const MAX_TS_FUTURE_MS = 60 * 60 * 1000; // допуск на рассинхрон часов — 1 час вперёд

interface IncomingEvent {
  name?: unknown;
  params?: unknown;
  ts?: unknown;
}

function validateEvent(e: IncomingEvent, now: number): { name: string; params: object | null; ts: Date } | null {
  if (!e || typeof e !== 'object') return null;
  if (typeof e.name !== 'string' || !ANALYTICS_EVENT_NAMES.has(e.name)) return null;
  if (typeof e.ts !== 'number' || !Number.isFinite(e.ts)) return null;
  if (e.ts < now - MAX_TS_PAST_MS || e.ts > now + MAX_TS_FUTURE_MS) return null;

  let params: object | null = null;
  if (e.params !== undefined && e.params !== null) {
    if (typeof e.params !== 'object' || Array.isArray(e.params)) return null;
    try {
      if (JSON.stringify(e.params).length > MAX_PARAMS_BYTES) return null;
    } catch {
      return null;
    }
    params = e.params as object;
  }

  return { name: e.name, params, ts: new Date(e.ts) };
}

// ─── POST /v1/analytics/events ── Батч событий (auth опционален) ─────────────
analyticsRouter.post(
  '/events',
  analyticsLimiter,
  optionalAuthMiddleware,
  async (req: AuthRequest, res: Response) => {
    try {
      const { deviceId, events } = req.body ?? {};

      if (typeof deviceId !== 'string' || deviceId.length < 8 || deviceId.length > 128) {
        res.status(400).json({ error: 'deviceId is required (8..128 chars)' });
        return;
      }
      if (!Array.isArray(events) || events.length === 0 || events.length > MAX_BATCH) {
        res.status(400).json({ error: `events must be an array (1..${MAX_BATCH})` });
        return;
      }

      const now = Date.now();
      const accepted: { userId: string | null; deviceId: string; name: string; params: object | null; ts: Date }[] = [];
      let rejected = 0;

      for (const e of events) {
        const valid = validateEvent(e as IncomingEvent, now);
        if (!valid) {
          rejected++;
          continue;
        }
        accepted.push({
          userId: req.userId ?? null,
          deviceId,
          name: valid.name,
          params: valid.params,
          ts: valid.ts,
        });
      }

      if (accepted.length > 0) {
        await prisma.analyticsEvent.createMany({
          data: accepted.map((e) => ({
            userId: e.userId,
            deviceId: e.deviceId,
            name: e.name,
            params: e.params ?? undefined,
            ts: e.ts,
          })),
        });
      }

      res.json({ accepted: accepted.length, rejected });
    } catch (err) {
      logger.error({ err }, '[analytics] events error');
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);
