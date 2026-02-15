import { Router, Request, Response } from 'express';
import prisma from '../db';

export const configRouter = Router();

// GET /v1/config — публичный, возвращает весь конфиг
// Поддерживает ?v=N — если клиентская версия == серверная, возвращает 304
configRouter.get('/', async (req: Request, res: Response) => {
  try {
    const config = await prisma.gameConfig.findUnique({
      where: { id: 'singleton' },
    });

    if (!config) {
      return res.status(404).json({ error: 'Config not found' });
    }

    // Проверка версии для кеширования
    const clientVersion = parseInt(req.query.v as string, 10);
    if (!isNaN(clientVersion) && clientVersion >= config.version) {
      return res.status(304).end();
    }

    res.json({
      version: config.version,
      economy: config.economy,
      ads: config.ads,
      iap: config.iap,
      vip: config.vip,
      daily: config.daily,
      achievements: config.achievements,
      localization: config.localization,
    });
  } catch (err) {
    console.error('Config fetch error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
