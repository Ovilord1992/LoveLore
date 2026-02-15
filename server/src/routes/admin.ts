import { Router, Response } from 'express';
import prisma from '../db';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { adminMiddleware } from '../middleware/admin';

export const adminRouter = Router();

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

    const [activeDay, activeWeek, activeMonth] = await Promise.all([
      prisma.user.count({ where: { updatedAt: { gte: day } } }),
      prisma.user.count({ where: { updatedAt: { gte: week } } }),
      prisma.user.count({ where: { updatedAt: { gte: month } } }),
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

    // Обновляем валюту если передана
    if (diamonds !== undefined || tickets !== undefined) {
      const currencyData: Record<string, unknown> = {};
      if (diamonds !== undefined) currencyData.diamonds = Number(diamonds);
      if (tickets !== undefined) currencyData.tickets = Number(tickets);

      await prisma.currencyData.upsert({
        where: { userId: req.params.id },
        update: currencyData,
        create: { userId: req.params.id, ...currencyData },
      });
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

      const updateData: Record<string, unknown> = {};
      if (isReleased !== undefined) {
        updateData.isReleased = Boolean(isReleased);
        if (isReleased && !chapter.releasedAt) {
          updateData.releasedAt = new Date();
        }
      }
      if (releasedAt !== undefined) updateData.releasedAt = new Date(releasedAt);
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

      res.json({ chapter: updated });
    } catch (err) {
      console.error('Admin chapter update error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);
