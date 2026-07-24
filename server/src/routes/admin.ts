import { Router, Response } from 'express';
import path from 'path';
import fs from 'fs';
import prisma from '../db';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { adminMiddleware } from '../middleware/admin';
import { adminSetCurrency } from '../economy/ledger';
import { validateGameConfigInput } from '../config/schema';
import { saveConfigWithHistory, rollbackConfig } from '../config/service';
import { upsertChapterInZip } from '../utils/zip';
import { invalidateNovelZipCache } from '../utils/zip-cache';
import { logger } from '../utils/logger';

export const adminRouter = Router();

const uploadDir = process.env.UPLOAD_DIR || './uploads';

// Все роуты защищены JWT + admin role
adminRouter.use(authMiddleware);
adminRouter.use(adminMiddleware);

// ─── GET /v1/admin/stats ── Статистика ───────────────────────────────────────
adminRouter.get('/stats', async (_req: AuthRequest, res: Response) => {
  try {
    const [totalUsers, totalNovels, totalDownloads] = await Promise.all([
      prisma.user.count(),
      prisma.novel.count(),
      prisma.novel.aggregate({ _sum: { downloads: true } }),
    ]);

    const now = new Date();
    const day = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const week = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const month = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    // Активность — по lastActiveAt (троттлится в authMiddleware), не по updatedAt.
    const [activeDay, activeWeek, activeMonth] = await Promise.all([
      prisma.user.count({ where: { lastActiveAt: { gte: day } } }),
      prisma.user.count({ where: { lastActiveAt: { gte: week } } }),
      prisma.user.count({ where: { lastActiveAt: { gte: month } } }),
    ]);

    res.json({
      totalUsers,
      totalNovels,
      totalDownloads: totalDownloads._sum.downloads || 0,
      active: { day: activeDay, week: activeWeek, month: activeMonth },
    });
  } catch (err) {
    console.error('Admin stats error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/analytics/summary ── Сводка аналитики (спека 2.4) ─────────
adminRouter.get('/analytics/summary', async (req: AuthRequest, res: Response) => {
  try {
    const days = Math.min(90, Math.max(1, Number(req.query.days) || 30));
    const now = new Date();
    const since = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    const week = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const month = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [dau, wauRows, mauRows, newUsers, revenueAgg, revenueByDay, topRows] = await Promise.all([
      prisma.$queryRaw<{ date: string; count: number }[]>`
        SELECT to_char(date_trunc('day', ts), 'YYYY-MM-DD') AS date,
               COUNT(DISTINCT COALESCE(user_id, device_id))::int AS count
        FROM analytics_events
        WHERE ts >= ${since}
        GROUP BY 1 ORDER BY 1`,
      prisma.$queryRaw<{ count: number }[]>`
        SELECT COUNT(DISTINCT COALESCE(user_id, device_id))::int AS count
        FROM analytics_events WHERE ts >= ${week}`,
      prisma.$queryRaw<{ count: number }[]>`
        SELECT COUNT(DISTINCT COALESCE(user_id, device_id))::int AS count
        FROM analytics_events WHERE ts >= ${month}`,
      prisma.$queryRaw<{ date: string; count: number }[]>`
        SELECT to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS date, COUNT(*)::int AS count
        FROM users
        WHERE created_at >= ${since}
        GROUP BY 1 ORDER BY 1`,
      prisma.iapTransaction.aggregate({
        _sum: { usdCents: true },
        where: { verified: true, revokedAt: null, createdAt: { gte: since } },
      }),
      prisma.$queryRaw<{ date: string; usdCents: number }[]>`
        SELECT to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS date,
               COALESCE(SUM(usd_cents), 0)::int AS "usdCents"
        FROM iap_transactions
        WHERE verified = true AND revoked_at IS NULL AND usd_cents IS NOT NULL AND created_at >= ${since}
        GROUP BY 1 ORDER BY 1`,
      prisma.$queryRaw<{ id: string; chapterCompletes: number }[]>`
        SELECT params->>'novelId' AS id, COUNT(*)::int AS "chapterCompletes"
        FROM analytics_events
        WHERE name = 'chapter_complete' AND ts >= ${since} AND params->>'novelId' IS NOT NULL
        GROUP BY 1 ORDER BY 2 DESC LIMIT 10`,
    ]);

    const topIds = topRows.map((r) => r.id);
    const titleRows = topIds.length
      ? await prisma.novel.findMany({ where: { id: { in: topIds } }, select: { id: true, title: true } })
      : [];
    const titles = new Map(titleRows.map((n) => [n.id, n.title]));

    res.json({
      dau,
      wau: wauRows[0]?.count ?? 0,
      mau: mauRows[0]?.count ?? 0,
      newUsers,
      revenueEstimateUsdCents: revenueAgg._sum.usdCents ?? 0,
      revenueByDay,
      topNovels: topRows.map((r) => ({
        id: r.id,
        title: titles.get(r.id) ?? r.id,
        chapterCompletes: r.chapterCompletes,
      })),
    });
  } catch (err) {
    console.error('Admin analytics summary error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/users ── Список пользователей ─────────────────────────────
adminRouter.get('/users', async (req: AuthRequest, res: Response) => {
  try {
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
    const search = (req.query.search as string) || '';
    const sortBy = (req.query.sortBy as string) || 'createdAt';
    const order = (req.query.order as string) === 'asc' ? 'asc' : 'desc';

    const where = search
      ? {
          OR: [
            { email: { contains: search, mode: 'insensitive' as const } },
            { displayName: { contains: search, mode: 'insensitive' as const } },
          ],
        }
      : {};

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { [sortBy]: order },
        select: {
          id: true,
          email: true,
          displayName: true,
          role: true,
          createdAt: true,
          updatedAt: true,
          _count: { select: { saves: true } },
        },
      }),
      prisma.user.count({ where }),
    ]);

    res.json({ users, total, page, limit, pages: Math.ceil(total / limit) });
  } catch (err) {
    console.error('Admin users error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/users/:id ── Детали пользователя ──────────────────────────
adminRouter.get('/users/:id', async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      select: {
        id: true,
        email: true,
        displayName: true,
        role: true,
        createdAt: true,
        updatedAt: true,
        profile: true,
        currency: true,
        saves: {
          select: { id: true, novelId: true, updatedAt: true },
          orderBy: { updatedAt: 'desc' },
        },
      },
    });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ user });
  } catch (err) {
    console.error('Admin user detail error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PATCH /v1/admin/users/:id ── Редактировать пользователя ─────────────────
adminRouter.patch('/users/:id', async (req: AuthRequest, res: Response) => {
  try {
    const { role, displayName, diamonds, tickets } = req.body;

    const user = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    // Обновляем пользователя
    const updateData: Record<string, unknown> = {};
    if (role && ['user', 'admin'].includes(role)) updateData.role = role;
    if (displayName) updateData.displayName = displayName;

    if (Object.keys(updateData).length > 0) {
      await prisma.user.update({ where: { id: req.params.id }, data: updateData });
    }

    // Обновляем валюту через леджер (admin_grant/admin_deduct) — не прямым set.
    if (diamonds !== undefined || tickets !== undefined) {
      const target: { diamonds?: number; tickets?: number } = {};
      if (diamonds !== undefined) {
        const d = Number(diamonds);
        if (!Number.isFinite(d)) {
          res.status(400).json({ error: 'diamonds must be a number' });
          return;
        }
        target.diamonds = d;
      }
      if (tickets !== undefined) {
        const t = Number(tickets);
        if (!Number.isFinite(t)) {
          res.status(400).json({ error: 'tickets must be a number' });
          return;
        }
        target.tickets = t;
      }
      await adminSetCurrency(req.params.id, target, req.userId!);
    }

    // Возвращаем обновлённого пользователя
    const updated = await prisma.user.findUnique({
      where: { id: req.params.id },
      select: {
        id: true, email: true, displayName: true, role: true,
        currency: { select: { diamonds: true, tickets: true } },
      },
    });

    res.json({ user: updated });
  } catch (err) {
    console.error('Admin user update error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/users/:id/ledger ── Последние операции леджера ────────────
adminRouter.get('/users/:id/ledger', async (req: AuthRequest, res: Response) => {
  try {
    const limit = Math.min(200, Math.max(1, Number(req.query.limit) || 50));

    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      select: { id: true },
    });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const entries = await prisma.currencyLedger.findMany({
      where: { userId: req.params.id },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        currency: true,
        delta: true,
        reason: true,
        refId: true,
        createdAt: true,
      },
    });

    res.json({ entries, limit });
  } catch (err) {
    console.error('Admin user ledger error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── DELETE /v1/admin/users/:id ── Удалить пользователя ──────────────────────
adminRouter.delete('/users/:id', async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    // Нельзя удалить самого себя
    if (user.id === req.userId) {
      res.status(400).json({ error: 'Cannot delete yourself' });
      return;
    }

    await prisma.user.delete({ where: { id: req.params.id } });

    res.json({ message: 'User deleted' });
  } catch (err) {
    console.error('Admin user delete error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/novels ── Все новеллы (включая неопубликованные) ───────────
adminRouter.get('/novels', async (req: AuthRequest, res: Response) => {
  try {
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
    const search = (req.query.search as string) || '';

    const where = search
      ? {
          OR: [
            { title: { contains: search, mode: 'insensitive' as const } },
            { author: { contains: search, mode: 'insensitive' as const } },
          ],
        }
      : {};

    const [novels, total] = await Promise.all([
      prisma.novel.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { updatedAt: 'desc' },
      }),
      prisma.novel.count({ where }),
    ]);

    res.json({ novels, total, page, limit, pages: Math.ceil(total / limit) });
  } catch (err) {
    console.error('Admin novels error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PATCH /v1/admin/novels/:id ── Редактировать новеллу ─────────────────────
adminRouter.patch('/novels/:id', async (req: AuthRequest, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({ where: { id: req.params.id } });
    if (!novel) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    const { title, description, author, tags, isPublished } = req.body;
    const updateData: Record<string, unknown> = {};

    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (author !== undefined) updateData.author = author;
    if (tags !== undefined) updateData.tags = tags;
    if (isPublished !== undefined) updateData.isPublished = Boolean(isPublished);

    const updated = await prisma.novel.update({
      where: { id: req.params.id },
      data: updateData,
    });

    res.json({ novel: updated });
  } catch (err) {
    console.error('Admin novel update error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/novels/:id/chapters ── Список глав (admin) ────────────────
adminRouter.get('/novels/:id/chapters', async (req: AuthRequest, res: Response) => {
  try {
    const chapters = await prisma.chapter.findMany({
      where: { novelId: req.params.id },
      orderBy: { number: 'asc' },
    });

    res.json({ chapters });
  } catch (err) {
    console.error('Admin chapters error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PATCH /v1/admin/novels/:id/chapters/:number ── Выпустить/скрыть главу ───
adminRouter.patch(
  '/novels/:id/chapters/:number',
  async (req: AuthRequest, res: Response) => {
    try {
      const chapterNumber = parseInt(req.params.number);
      const { isReleased, releasedAt, title } = req.body;

      const chapter = await prisma.chapter.findUnique({
        where: {
          novelId_number: { novelId: req.params.id, number: chapterNumber },
        },
      });

      if (!chapter) {
        res.status(404).json({ error: 'Chapter not found' });
        return;
      }

      const releasedAtProvided = releasedAt !== undefined;
      let parsedReleasedAt: Date | null = null;
      if (releasedAtProvided && releasedAt !== null) {
        parsedReleasedAt = new Date(releasedAt);
        if (isNaN(parsedReleasedAt.getTime())) {
          res.status(400).json({ error: 'Invalid releasedAt' });
          return;
        }
      }

      const updateData: Record<string, unknown> = {};
      if (isReleased !== undefined) {
        updateData.isReleased = Boolean(isReleased);
        if (isReleased && !chapter.releasedAt && !releasedAtProvided) {
          updateData.releasedAt = new Date();
        }
      }
      if (releasedAtProvided) updateData.releasedAt = parsedReleasedAt;

      // Скрытая глава с прошедшим releasedAt была бы перевыпущена планировщиком
      // в течение минуты — при скрытии без нового расписания дата обнуляется.
      const effectiveReleased =
        isReleased !== undefined ? Boolean(isReleased) : chapter.isReleased;
      if (!effectiveReleased) {
        const effectiveReleasedAt = releasedAtProvided
          ? parsedReleasedAt
          : chapter.releasedAt;
        if (effectiveReleasedAt && effectiveReleasedAt.getTime() <= Date.now()) {
          updateData.releasedAt = null;
        }
      }
      if (title !== undefined) updateData.title = title;

      const updated = await prisma.chapter.update({
        where: { id: chapter.id },
        data: updateData,
      });

      // Пересчитать releasedChapters
      const releasedCount = await prisma.chapter.count({
        where: { novelId: req.params.id, isReleased: true },
      });
      await prisma.novel.update({
        where: { id: req.params.id },
        data: { releasedChapters: releasedCount },
      });

      // Состав выпущенных глав изменился — кеш released-ZIP устарел.
      invalidateNovelZipCache(req.params.id);

      res.json({ chapter: updated });
    } catch (err) {
      console.error('Admin chapter update error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ─── POST /v1/admin/novels/:id/chapters ── Upsert одной главы в ZIP ──────────
// Основной сценарий «выпустить новую главу без перезаливки всего архива»:
// JSON главы вставляется/заменяется внутри ZIP, upsert строки Chapter
// (сохраняя isReleased существующей), version++, инвалидация кеша.
adminRouter.post('/novels/:id/chapters', async (req: AuthRequest, res: Response) => {
  try {
    const { chapter } = req.body ?? {};

    if (!chapter || typeof chapter !== 'object') {
      res.status(400).json({ error: 'chapter object is required' });
      return;
    }
    if (typeof chapter.id !== 'string' || chapter.id.length === 0) {
      res.status(400).json({ error: 'chapter.id is required' });
      return;
    }
    if (typeof chapter.title !== 'string' || chapter.title.length === 0) {
      res.status(400).json({ error: 'chapter.title is required' });
      return;
    }
    if (typeof chapter.number !== 'number' || !Number.isInteger(chapter.number) || chapter.number < 1) {
      res.status(400).json({ error: 'chapter.number must be a positive integer' });
      return;
    }
    if (typeof chapter.firstSceneId !== 'string' || chapter.firstSceneId.length === 0) {
      res.status(400).json({ error: 'chapter.firstSceneId is required' });
      return;
    }
    if (!Array.isArray(chapter.scenes) || chapter.scenes.length === 0) {
      res.status(400).json({ error: 'chapter.scenes must be a non-empty array' });
      return;
    }

    const novel = await prisma.novel.findUnique({ where: { id: req.params.id } });
    if (!novel || !novel.zipFilename) {
      res.status(404).json({ error: 'Novel not found or has no uploaded pack' });
      return;
    }

    const zipPath = path.resolve(uploadDir, 'packs', novel.zipFilename);
    if (!fs.existsSync(zipPath)) {
      res.status(404).json({ error: 'Novel file not found on server' });
      return;
    }

    const existingRow = await prisma.chapter.findUnique({
      where: { novelId_number: { novelId: novel.id, number: chapter.number } },
    });

    upsertChapterInZip(zipPath, chapter.number, JSON.stringify(chapter, null, 2));

    const row = await prisma.chapter.upsert({
      where: { novelId_number: { novelId: novel.id, number: chapter.number } },
      // Существующая глава сохраняет isReleased/releasedAt.
      update: { title: chapter.title },
      create: {
        novelId: novel.id,
        number: chapter.number,
        title: chapter.title,
        isReleased: false,
        releasedAt: null,
      },
    });

    const [chaptersCount, releasedCount] = await Promise.all([
      prisma.chapter.count({ where: { novelId: novel.id } }),
      prisma.chapter.count({ where: { novelId: novel.id, isReleased: true } }),
    ]);

    const updatedNovel = await prisma.novel.update({
      where: { id: novel.id },
      data: {
        version: { increment: 1 },
        chaptersCount,
        releasedChapters: releasedCount,
        fileSize: fs.statSync(zipPath).size,
      },
      select: { id: true, version: true, chaptersCount: true, releasedChapters: true },
    });

    invalidateNovelZipCache(novel.id);
    logger.info({ novelId: novel.id, number: chapter.number }, '[admin] chapter upserted into zip');

    res.status(existingRow ? 200 : 201).json({
      message: existingRow ? 'Chapter updated' : 'Chapter created',
      chapter: row,
      novel: updatedNovel,
    });
  } catch (err) {
    console.error('Admin chapter upsert error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/config ── Получить конфигурацию ───────────────────────────
adminRouter.get('/config', async (_req: AuthRequest, res: Response) => {
  try {
    const config = await prisma.gameConfig.findUnique({
      where: { id: 'singleton' },
    });
    if (!config) {
      return res.status(404).json({ error: 'Config not found' });
    }
    res.json(config);
  } catch (err) {
    console.error('Admin config get error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PUT /v1/admin/config ── Обновить конфигурацию (zod + история) ───────────
adminRouter.put('/config', async (req: AuthRequest, res: Response) => {
  try {
    const validation = validateGameConfigInput(req.body ?? {});
    if (!validation.ok) {
      res.status(400).json({ error: 'Invalid config', details: validation.errors });
      return;
    }

    const { economy, ads, iap, vip, daily, achievements, localization } = req.body;
    const { version } = await saveConfigWithHistory(
      { economy, ads, iap, vip, daily, achievements, localization },
      req.userId!
    );

    res.json({ message: 'Config updated', version, warnings: validation.warnings });
  } catch (err) {
    console.error('Admin config update error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/config/history ── Список версий конфига ───────────────────
adminRouter.get('/config/history', async (_req: AuthRequest, res: Response) => {
  try {
    const history = await prisma.configHistory.findMany({
      orderBy: { version: 'desc' },
      take: 100,
      select: { version: true, changedBy: true, createdAt: true },
    });
    res.json({ history });
  } catch (err) {
    console.error('Admin config history error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/config/history/:version ── Полный снапшот версии ──────────
adminRouter.get('/config/history/:version', async (req: AuthRequest, res: Response) => {
  try {
    const version = parseInt(req.params.version, 10);
    if (isNaN(version)) {
      res.status(400).json({ error: 'Invalid version' });
      return;
    }

    const snapshot = await prisma.configHistory.findUnique({ where: { version } });
    if (!snapshot) {
      res.status(404).json({ error: 'Version not found' });
      return;
    }

    res.json({
      version: snapshot.version,
      changedBy: snapshot.changedBy,
      createdAt: snapshot.createdAt,
      data: snapshot.data,
    });
  } catch (err) {
    console.error('Admin config history detail error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/admin/config/rollback ── Откат к версии из истории ─────────────
adminRouter.post('/config/rollback', async (req: AuthRequest, res: Response) => {
  try {
    const { version } = req.body ?? {};
    if (typeof version !== 'number' || !Number.isInteger(version)) {
      res.status(400).json({ error: 'version (integer) is required' });
      return;
    }

    const result = await rollbackConfig(version, req.userId!);
    if (!result.ok) {
      res.status(404).json({ error: 'Version not found' });
      return;
    }

    res.json({ message: 'Config rolled back', version: result.version, rolledBackTo: result.rolledBackTo });
  } catch (err) {
    console.error('Admin config rollback error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/admin/reviews ── Список отзывов ─────────────────────────────────
adminRouter.get('/reviews', async (req: AuthRequest, res: Response) => {
  try {
    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 10));
    const status = req.query.status as string | undefined;
    const where = status ? { status } : {};

    const [items, total] = await Promise.all([
      prisma.review.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          user: { select: { id: true, displayName: true, email: true } },
          novel: { select: { id: true, title: true } },
        },
      }),
      prisma.review.count({ where }),
    ]);

    res.json({ items, total, page, limit });
  } catch (err) {
    console.error('Admin reviews error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── PATCH /v1/admin/reviews/:id ── Обновить статус отзыва ───────────────────
adminRouter.patch('/reviews/:id', async (req: AuthRequest, res: Response) => {
  try {
    const { status } = req.body;
    if (!status || !['approved', 'rejected'].includes(status)) {
      res.status(400).json({ error: 'Status must be "approved" or "rejected"' });
      return;
    }

    const review = await prisma.review.findUnique({ where: { id: req.params.id } });
    if (!review) {
      res.status(404).json({ error: 'Review not found' });
      return;
    }

    const updated = await prisma.review.update({
      where: { id: req.params.id },
      data: { status },
    });

    res.json({ review: updated });
  } catch (err) {
    console.error('Admin review update error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── DELETE /v1/admin/reviews/:id ── Удалить отзыв ───────────────────────────
adminRouter.delete('/reviews/:id', async (req: AuthRequest, res: Response) => {
  try {
    const review = await prisma.review.findUnique({ where: { id: req.params.id } });
    if (!review) {
      res.status(404).json({ error: 'Review not found' });
      return;
    }

    await prisma.review.delete({ where: { id: req.params.id } });

    res.json({ message: 'Review deleted' });
  } catch (err) {
    console.error('Admin review delete error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
