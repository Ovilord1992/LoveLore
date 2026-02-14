import { Router, Response } from 'express';
import prisma from '../db';
import { AuthRequest, authMiddleware } from '../middleware/auth';

export const syncRouter = Router();

// Все роуты требуют авторизации
syncRouter.use(authMiddleware);

// ═══════════════════════════════════════════════════════════════════════════════
// SAVES — сохранения игры
// ═══════════════════════════════════════════════════════════════════════════════

// ─── GET /v1/sync/saves ── Все сохранения пользователя ──────────────────────
syncRouter.get('/saves', async (req: AuthRequest, res: Response) => {
  try {
    const saves = await prisma.gameSave.findMany({
      where: { userId: req.userId },
      select: { novelId: true, data: true, updatedAt: true },
    });

    res.json({ saves });
  } catch (err) {
    console.error('Get saves error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/sync/saves/:novelId ── Сохранение конкретной новеллы ───────────
syncRouter.get('/saves/:novelId', async (req: AuthRequest, res: Response) => {
  try {
    const save = await prisma.gameSave.findUnique({
      where: {
        userId_novelId: {
          userId: req.userId!,
          novelId: req.params.novelId,
        },
      },
      select: { novelId: true, data: true, updatedAt: true },
    });

    if (!save) {
      res.status(404).json({ error: 'Save not found' });
      return;
    }

    res.json({ save });
  } catch (err) {
    console.error('Get save error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PUT /v1/sync/saves/:novelId ── Сохранить/обновить прогресс ─────────────
syncRouter.put('/saves/:novelId', async (req: AuthRequest, res: Response) => {
  try {
    const { data } = req.body;

    if (!data) {
      res.status(400).json({ error: 'Save data is required' });
      return;
    }

    const save = await prisma.gameSave.upsert({
      where: {
        userId_novelId: {
          userId: req.userId!,
          novelId: req.params.novelId,
        },
      },
      update: { data },
      create: {
        userId: req.userId!,
        novelId: req.params.novelId,
        data,
      },
      select: { novelId: true, updatedAt: true },
    });

    res.json({ save });
  } catch (err) {
    console.error('Put save error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── DELETE /v1/sync/saves/:novelId ── Удалить сохранение ───────────────────
syncRouter.delete('/saves/:novelId', async (req: AuthRequest, res: Response) => {
  try {
    await prisma.gameSave.deleteMany({
      where: {
        userId: req.userId!,
        novelId: req.params.novelId,
      },
    });

    res.json({ message: 'Save deleted' });
  } catch (err) {
    console.error('Delete save error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE — профиль пользователя
// ═══════════════════════════════════════════════════════════════════════════════

// ─── GET /v1/sync/profile ── Получить профиль ───────────────────────────────
syncRouter.get('/profile', async (req: AuthRequest, res: Response) => {
  try {
    const profile = await prisma.userProfileData.findUnique({
      where: { userId: req.userId },
    });

    if (!profile) {
      res.status(404).json({ error: 'Profile not found' });
      return;
    }

    res.json({
      profile: {
        displayName: profile.displayName,
        avatarIndex: profile.avatarIndex,
        totalNovelsStarted: profile.totalNovelsStarted,
        totalNovelsCompleted: profile.totalNovelsCompleted,
        totalChoicesMade: profile.totalChoicesMade,
        totalChaptersRead: profile.totalChaptersRead,
        unlockedCGs: profile.unlockedCGs,
        achievements: profile.achievements,
      },
    });
  } catch (err) {
    console.error('Get profile error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PUT /v1/sync/profile ── Обновить профиль ───────────────────────────────
syncRouter.put('/profile', async (req: AuthRequest, res: Response) => {
  try {
    const data = req.body;

    const profile = await prisma.userProfileData.upsert({
      where: { userId: req.userId },
      update: {
        displayName: data.displayName,
        avatarIndex: data.avatarIndex,
        totalNovelsStarted: data.totalNovelsStarted,
        totalNovelsCompleted: data.totalNovelsCompleted,
        totalChoicesMade: data.totalChoicesMade,
        totalChaptersRead: data.totalChaptersRead,
        unlockedCGs: data.unlockedCGs ?? [],
        achievements: data.achievements ?? [],
      },
      create: {
        userId: req.userId!,
        displayName: data.displayName ?? 'Читатель',
        avatarIndex: data.avatarIndex ?? 0,
        totalNovelsStarted: data.totalNovelsStarted ?? 0,
        totalNovelsCompleted: data.totalNovelsCompleted ?? 0,
        totalChoicesMade: data.totalChoicesMade ?? 0,
        totalChaptersRead: data.totalChaptersRead ?? 0,
        unlockedCGs: data.unlockedCGs ?? [],
        achievements: data.achievements ?? [],
      },
    });

    res.json({ profile });
  } catch (err) {
    console.error('Put profile error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// CURRENCY — валюта (алмазы, билеты)
// ═══════════════════════════════════════════════════════════════════════════════

// ─── GET /v1/sync/currency ── Получить валюту ───────────────────────────────
syncRouter.get('/currency', async (req: AuthRequest, res: Response) => {
  try {
    const currency = await prisma.currencyData.findUnique({
      where: { userId: req.userId },
    });

    if (!currency) {
      res.status(404).json({ error: 'Currency data not found' });
      return;
    }

    res.json({
      currency: {
        diamonds: currency.diamonds,
        tickets: currency.tickets,
        lastTicketRefill: currency.lastTicketRefill?.toISOString() ?? null,
      },
    });
  } catch (err) {
    console.error('Get currency error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PUT /v1/sync/currency ── Обновить валюту ───────────────────────────────
syncRouter.put('/currency', async (req: AuthRequest, res: Response) => {
  try {
    const data = req.body;

    const currency = await prisma.currencyData.upsert({
      where: { userId: req.userId },
      update: {
        diamonds: data.diamonds,
        tickets: data.tickets,
        lastTicketRefill: data.lastTicketRefill
          ? new Date(data.lastTicketRefill)
          : null,
      },
      create: {
        userId: req.userId!,
        diamonds: data.diamonds ?? 50,
        tickets: data.tickets ?? 5,
        lastTicketRefill: data.lastTicketRefill
          ? new Date(data.lastTicketRefill)
          : null,
      },
    });

    res.json({ currency });
  } catch (err) {
    console.error('Put currency error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// FULL SYNC — полная синхронизация (pull all / push all)
// ═══════════════════════════════════════════════════════════════════════════════

// ─── GET /v1/sync/all ── Получить все данные пользователя ────────────────────
syncRouter.get('/all', async (req: AuthRequest, res: Response) => {
  try {
    const [saves, profile, currency] = await Promise.all([
      prisma.gameSave.findMany({
        where: { userId: req.userId },
        select: { novelId: true, data: true, updatedAt: true },
      }),
      prisma.userProfileData.findUnique({
        where: { userId: req.userId },
      }),
      prisma.currencyData.findUnique({
        where: { userId: req.userId },
      }),
    ]);

    res.json({
      saves,
      profile: profile
        ? {
            displayName: profile.displayName,
            avatarIndex: profile.avatarIndex,
            totalNovelsStarted: profile.totalNovelsStarted,
            totalNovelsCompleted: profile.totalNovelsCompleted,
            totalChoicesMade: profile.totalChoicesMade,
            totalChaptersRead: profile.totalChaptersRead,
            unlockedCGs: profile.unlockedCGs,
            achievements: profile.achievements,
          }
        : null,
      currency: currency
        ? {
            diamonds: currency.diamonds,
            tickets: currency.tickets,
            lastTicketRefill: currency.lastTicketRefill?.toISOString() ?? null,
          }
        : null,
    });
  } catch (err) {
    console.error('Get all sync error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
