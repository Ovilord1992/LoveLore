import { Router, Response } from 'express';
import prisma from '../db';
import { AuthRequest, authMiddleware } from '../middleware/auth';

export const syncRouter = Router();

// Все роуты требуют авторизации
syncRouter.use(authMiddleware);

// ─── Валидаторы ─────────────────────────────────────────────────────────────
const MAX_CURRENCY = 999_999;
const MAX_COUNTER = 1_000_000;
const MAX_COLLECTION_LEN = 10_000;
const MAX_COLLECTION_ITEM_LEN = 100;
const MAX_DISPLAY_NAME_LEN = 50;

type ValidationError = { field: string };

function isIntInRange(v: unknown, min: number, max: number): boolean {
  return typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max;
}

function isStringArray(v: unknown, maxLen: number, maxItemLen: number): boolean {
  if (!Array.isArray(v)) return false;
  if (v.length > maxLen) return false;
  for (const item of v) {
    if (typeof item !== 'string') return false;
    if (item.length === 0 || item.length > maxItemLen) return false;
  }
  return true;
}

function validateProfileFields(body: any): ValidationError | null {
  if (body == null || typeof body !== 'object') {
    return { field: 'body' };
  }

  if (body.displayName !== undefined) {
    if (
      typeof body.displayName !== 'string' ||
      body.displayName.length < 1 ||
      body.displayName.length > MAX_DISPLAY_NAME_LEN
    ) {
      return { field: 'displayName' };
    }
  }

  const counterFields: ReadonlyArray<string> = [
    'totalNovelsStarted',
    'totalNovelsCompleted',
    'totalChoicesMade',
    'totalChaptersRead',
    'avatarIndex',
  ];
  for (const f of counterFields) {
    if (body[f] !== undefined && !isIntInRange(body[f], 0, MAX_COUNTER)) {
      return { field: f };
    }
  }

  if (
    body.unlockedCGs !== undefined &&
    !isStringArray(body.unlockedCGs, MAX_COLLECTION_LEN, MAX_COLLECTION_ITEM_LEN)
  ) {
    return { field: 'unlockedCGs' };
  }
  if (
    body.achievements !== undefined &&
    !isStringArray(body.achievements, MAX_COLLECTION_LEN, MAX_COLLECTION_ITEM_LEN)
  ) {
    return { field: 'achievements' };
  }

  return null;
}

function validateCurrencyFields(body: any): ValidationError | null {
  if (body == null || typeof body !== 'object') {
    return { field: 'body' };
  }

  if (body.diamonds !== undefined && !isIntInRange(body.diamonds, 0, MAX_CURRENCY)) {
    return { field: 'diamonds' };
  }
  if (body.tickets !== undefined && !isIntInRange(body.tickets, 0, MAX_CURRENCY)) {
    return { field: 'tickets' };
  }
  if (body.lastTicketRefill !== undefined && body.lastTicketRefill !== null) {
    if (typeof body.lastTicketRefill !== 'string') {
      return { field: 'lastTicketRefill' };
    }
    const t = Date.parse(body.lastTicketRefill);
    if (Number.isNaN(t)) {
      return { field: 'lastTicketRefill' };
    }
  }

  return null;
}

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

    const validationError = validateProfileFields(data);
    if (validationError) {
      res.status(400).json({ error: `invalid value for ${validationError.field}` });
      return;
    }

    const existing = await prisma.userProfileData.findUnique({
      where: { userId: req.userId },
    });

    // Merge: undefined → не трогать; счётчики → max; коллекции → union
    const merged = {
      displayName:
        data.displayName !== undefined
          ? data.displayName
          : existing?.displayName ?? 'Читатель',
      avatarIndex:
        data.avatarIndex !== undefined ? data.avatarIndex : existing?.avatarIndex ?? 0,
      totalNovelsStarted:
        data.totalNovelsStarted !== undefined
          ? Math.max(existing?.totalNovelsStarted ?? 0, data.totalNovelsStarted)
          : existing?.totalNovelsStarted ?? 0,
      totalNovelsCompleted:
        data.totalNovelsCompleted !== undefined
          ? Math.max(existing?.totalNovelsCompleted ?? 0, data.totalNovelsCompleted)
          : existing?.totalNovelsCompleted ?? 0,
      totalChoicesMade:
        data.totalChoicesMade !== undefined
          ? Math.max(existing?.totalChoicesMade ?? 0, data.totalChoicesMade)
          : existing?.totalChoicesMade ?? 0,
      totalChaptersRead:
        data.totalChaptersRead !== undefined
          ? Math.max(existing?.totalChaptersRead ?? 0, data.totalChaptersRead)
          : existing?.totalChaptersRead ?? 0,
      unlockedCGs:
        data.unlockedCGs !== undefined
          ? Array.from(new Set([...(existing?.unlockedCGs ?? []), ...data.unlockedCGs]))
          : existing?.unlockedCGs ?? [],
      achievements:
        data.achievements !== undefined
          ? Array.from(new Set([...(existing?.achievements ?? []), ...data.achievements]))
          : existing?.achievements ?? [],
    };

    // Если displayName был обновлён клиентом — синхронизируем его и в User.displayName,
    // чтобы поле не расходилось между моделями. Делаем единой транзакцией.
    const shouldSyncUserDisplayName = data.displayName !== undefined;

    const [profile] = await prisma.$transaction([
      prisma.userProfileData.upsert({
        where: { userId: req.userId },
        update: merged,
        create: { userId: req.userId!, ...merged },
      }),
      ...(shouldSyncUserDisplayName
        ? [
            prisma.user.update({
              where: { id: req.userId! },
              data: { displayName: merged.displayName },
            }),
          ]
        : []),
    ]);

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

    const validationError = validateCurrencyFields(data);
    if (validationError) {
      res.status(400).json({ error: `invalid value for ${validationError.field}` });
      return;
    }

    const existing = await prisma.currencyData.findUnique({
      where: { userId: req.userId },
    });

    // Нельзя обнулять с клиента — берём max
    const mergedDiamonds =
      data.diamonds !== undefined
        ? Math.max(existing?.diamonds ?? 50, data.diamonds)
        : existing?.diamonds ?? 50;
    const mergedTickets =
      data.tickets !== undefined
        ? Math.max(existing?.tickets ?? 5, data.tickets)
        : existing?.tickets ?? 5;
    const mergedLastRefill =
      data.lastTicketRefill !== undefined
        ? data.lastTicketRefill
          ? new Date(data.lastTicketRefill)
          : null
        : existing?.lastTicketRefill ?? null;

    const currency = await prisma.currencyData.upsert({
      where: { userId: req.userId },
      update: {
        diamonds: mergedDiamonds,
        tickets: mergedTickets,
        lastTicketRefill: mergedLastRefill,
      },
      create: {
        userId: req.userId!,
        diamonds: mergedDiamonds,
        tickets: mergedTickets,
        lastTicketRefill: mergedLastRefill,
      },
    });

    res.json({ currency });
  } catch (err) {
    console.error('Put currency error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// FAVORITES — избранные новеллы
// ═══════════════════════════════════════════════════════════════════════════════

// ─── GET /v1/sync/favorites ── Список избранных новелл ───────────────────────
syncRouter.get('/favorites', async (req: AuthRequest, res: Response) => {
  try {
    const favorites = await prisma.favorite.findMany({
      where: { userId: req.userId },
      select: { novelId: true },
    });

    res.json({ favorites: favorites.map((f) => f.novelId) });
  } catch (err) {
    console.error('Get favorites error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/sync/favorites/:novelId ── Переключить избранное ──────────────
syncRouter.post('/favorites/:novelId', async (req: AuthRequest, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.novelId },
      select: { id: true },
    });
    if (!novel) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    const existing = await prisma.favorite.findUnique({
      where: { userId_novelId: { userId: req.userId!, novelId: req.params.novelId } },
    });

    if (existing) {
      await prisma.favorite.delete({ where: { id: existing.id } });
      res.json({ favorited: false });
    } else {
      await prisma.favorite.create({
        data: { userId: req.userId!, novelId: req.params.novelId },
      });
      res.json({ favorited: true });
    }
  } catch (err) {
    console.error('Toggle favorite error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

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
