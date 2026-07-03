import { Router, Request, Response } from 'express';
import path from 'path';
import fs from 'fs';
import prisma from '../db';
import { upload } from '../middleware/upload';
import { AuthRequest, authMiddleware } from '../middleware/auth';
import { adminMiddleware } from '../middleware/admin';
import { extractMetaFromZip, extractCoverFromZip, extractChaptersFromZip, extractChapterJsonFromZip, extractTranslationLanguagesFromZip, extractTranslationFromZip, addTranslationToZip, extractAllTranslationsFromZip, buildReleasedZipBuffer, zipHasUnreleasedChapters } from '../utils/zip';
import { logger } from '../utils/logger';

export const novelsRouter = Router();

const uploadDir = process.env.UPLOAD_DIR || './uploads';

// Разрешённый формат id новеллы: строчные буквы/цифры/дефис/подчёркивание, 1..64.
// Закрывает path traversal через meta.id (запись обложки, имена файлов, пути).
const NOVEL_ID_RE = /^[a-z0-9_-]{1,64}$/;
// Код языка перевода: ISO 639-1 + опциональный регион (например, ru, en, pt-BR).
const LANG_RE = /^[a-z]{2}(-[A-Z]{2})?$/;

// ─── GET /v1/novels ── Каталог опубликованных новелл ────────────────────────
novelsRouter.get('/', async (_req: Request, res: Response) => {
  try {
    const novels = await prisma.novel.findMany({
      where: { isPublished: true },
      orderBy: { updatedAt: 'desc' },
      select: {
        id: true,
        title: true,
        description: true,
        author: true,
        coverUrl: true,
        tags: true,
        version: true,
        chaptersCount: true,
        releasedChapters: true,
        fileSize: true,
        downloads: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    res.json({ novels });
  } catch (err) {
    console.error('Error fetching catalog:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/popular ── Топ новелл по рейтингу ─────────────────────────
novelsRouter.get('/popular', async (_req: Request, res: Response) => {
  try {
    const novels = await prisma.novel.findMany({
      where: { isPublished: true },
      orderBy: { averageRating: 'desc' },
      take: 10,
      select: {
        id: true,
        title: true,
        description: true,
        author: true,
        coverUrl: true,
        tags: true,
        averageRating: true,
        ratingCount: true,
        downloads: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    res.json({ novels });
  } catch (err) {
    console.error('Error fetching popular novels:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/new-chapters ── Новеллы с новыми главами ─────────────────
novelsRouter.get('/new-chapters', async (_req: Request, res: Response) => {
  try {
    const novels = await prisma.novel.findMany({
      where: {
        isPublished: true,
        chapters: { some: { isReleased: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 10,
      select: {
        id: true,
        title: true,
        coverUrl: true,
        releasedChapters: true,
        updatedAt: true,
        chapters: {
          where: { isReleased: true },
          orderBy: { releasedAt: 'desc' },
          take: 1,
          select: { number: true, title: true, releasedAt: true },
        },
      },
    });

    res.json({ novels });
  } catch (err) {
    console.error('Error fetching new chapters:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/:id ── Детали одной новеллы ─────────────────────────────
novelsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel || !novel.isPublished) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    res.json({ novel });
  } catch (err) {
    console.error('Error fetching novel:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/:id/download ── Скачать ZIP-пак ─────────────────────────
novelsRouter.get('/:id/download', async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel || !novel.isPublished || !novel.zipFilename) {
      res.status(404).json({ error: 'Novel not found or no file available' });
      return;
    }

    const filePath = path.resolve(uploadDir, 'packs', novel.zipFilename);

    if (!fs.existsSync(filePath)) {
      res.status(404).json({ error: 'File not found on server' });
      return;
    }

    // Множество выпущенных глав. Невыпущенные главы не должны утечь в ZIP,
    // даже если они физически лежат в архиве (управление через админку).
    const releasedRows = await prisma.chapter.findMany({
      where: { novelId: novel.id, isReleased: true },
      select: { number: true },
    });
    const releasedNumbers = new Set(releasedRows.map((c) => c.number));

    // Инкремент счётчика загрузок
    await prisma.novel.update({
      where: { id: req.params.id },
      data: { downloads: { increment: 1 } },
    });

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${novel.id}.zip"`
    );

    // Если архив содержит невыпущенные главы — отдаём пересобранный буфер без них.
    if (zipHasUnreleasedChapters(filePath, releasedNumbers)) {
      const buffer = buildReleasedZipBuffer(filePath, releasedNumbers);
      res.setHeader('Content-Length', buffer.length);
      res.send(buffer);
      return;
    }

    // Быстрый путь: все главы выпущены — стримим исходный файл как есть.
    const stat = fs.statSync(filePath);
    res.setHeader('Content-Length', stat.size);

    const stream = fs.createReadStream(filePath);
    stream.pipe(res);
  } catch (err) {
    console.error('Error downloading novel:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/novels/upload ── Загрузить новеллу (ZIP) ──────────────────────
novelsRouter.post(
  '/upload',
  authMiddleware,
  adminMiddleware,
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      const zipPath = req.file.path;
      const zipFilename = req.file.filename;
      const fileSize = req.file.size;

      // Извлекаем meta.json из ZIP
      const meta = extractMetaFromZip(zipPath);
      if (!meta || !meta.id || !meta.title) {
        // Удаляем невалидный файл
        fs.unlinkSync(zipPath);
        res.status(400).json({
          error: 'Invalid novel pack: meta.json with id and title is required',
        });
        return;
      }

      const novelId = meta.id as string;

      // Валидация id: закрывает path traversal (запись обложки, имена файлов, пути в ZIP).
      if (typeof novelId !== 'string' || !NOVEL_ID_RE.test(novelId)) {
        fs.unlinkSync(zipPath);
        res.status(400).json({ error: 'Invalid novel id' });
        return;
      }

      // Извлекаем обложку
      const coversDir = path.join(uploadDir, 'covers');
      const coverFile = extractCoverFromZip(zipPath, novelId, coversDir);
      const coverUrl = coverFile ? `/covers/${coverFile}` : null;

      // Считаем главы (chapters/ в ZIP)
      let chaptersCount = 0;
      const chapterInfos: { number: number; title: string }[] = [];
      try {
        const extracted = extractChaptersFromZip(zipPath);
        chaptersCount = extracted.length;
        chapterInfos.push(...extracted);
      } catch (err) {
        // ZIP bomb — отказ с 413, чтобы пользователь понял что архив отвергнут.
        // Чистим уже сохранённые артефакты (zip + обложку), т.к. БД ещё не трогали.
        if (err instanceof Error && err.message.includes('exceeds max uncompressed size')) {
          logger.error({ err: err.message, novelId }, '[upload] ZIP bomb rejected');
          try { if (fs.existsSync(zipPath)) fs.unlinkSync(zipPath); } catch (e) { logger.warn({ err: e }, '[upload] Failed to cleanup zip'); }
          if (coverFile) {
            const coverPath = path.join(coversDir, coverFile);
            try { if (fs.existsSync(coverPath)) fs.unlinkSync(coverPath); } catch (e) { logger.warn({ err: e }, '[upload] Failed to cleanup cover'); }
          }
          res.status(413).json({ error: 'ZIP exceeds maximum allowed size' });
          return;
        }
        // Прочие ошибки (corrupt archive / I/O) — лог, не падаем (главы создадутся как 0).
        logger.error({ err, novelId }, '[upload] Failed to extract chapters from ZIP');
      }

      // Если новелла уже существует — обновляем, иначе создаём
      const existing = await prisma.novel.findUnique({
        where: { id: novelId },
      });

      // Удаляем старый ZIP если обновляем
      if (existing?.zipFilename) {
        const oldPath = path.resolve(uploadDir, 'packs', existing.zipFilename);
        const uploadDirResolved = path.resolve(uploadDir);
        if (!oldPath.startsWith(uploadDirResolved)) {
          logger.warn({ oldPath }, 'Skipping old zip deletion: path traversal detected');
        } else if (fs.existsSync(oldPath)) {
          // Переносим переводы (translations/*.json), добавленные через
          // POST /translations, из старого архива в новый — иначе re-upload
          // молча теряет их. Новые переводы (если есть в загруженном ZIP) имеют
          // приоритет и не перезаписываются.
          try {
            const oldTranslations = extractAllTranslationsFromZip(oldPath);
            if (oldTranslations.length > 0) {
              const newLangs = new Set(extractTranslationLanguagesFromZip(zipPath));
              for (const t of oldTranslations) {
                if (!newLangs.has(t.language)) {
                  addTranslationToZip(zipPath, t.language, t.content);
                }
              }
            }
          } catch (e) {
            logger.warn({ err: e, novelId }, '[upload] Failed to migrate translations from old zip');
          }
          fs.unlinkSync(oldPath);
        }
      }

      const novel = await prisma.novel.upsert({
        where: { id: novelId },
        update: {
          title: meta.title as string,
          description: (meta.description as string) || '',
          author: (meta.author as string) || '',
          tags: (meta.tags as string[]) || [],
          version: existing ? existing.version + 1 : 1,
          chaptersCount,
          releasedChapters: chaptersCount,
          zipFilename,
          fileSize,
          coverUrl,
        },
        create: {
          id: novelId,
          title: meta.title as string,
          description: (meta.description as string) || '',
          author: (meta.author as string) || '',
          tags: (meta.tags as string[]) || [],
          version: 1,
          chaptersCount,
          releasedChapters: chaptersCount,
          zipFilename,
          fileSize,
          coverUrl,
        },
      });

      // Создаём записи Chapter для каждой главы из ZIP
      for (const ch of chapterInfos) {
        await prisma.chapter.upsert({
          where: {
            novelId_number: { novelId, number: ch.number },
          },
          update: {
            title: ch.title,
          },
          create: {
            novelId,
            number: ch.number,
            title: ch.title,
            isReleased: true,
            releasedAt: new Date(),
          },
        });
      }

      res.status(201).json({
        message: 'Novel uploaded successfully',
        novel: {
          id: novel.id,
          title: novel.title,
          version: novel.version,
          fileSize: novel.fileSize,
        },
      });
    } catch (err) {
      console.error('Error uploading novel:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ─── DELETE /v1/novels/:id ── Удалить новеллу ───────────────────────────────
novelsRouter.delete('/:id', authMiddleware, adminMiddleware, async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    const uploadDirResolved = path.resolve(uploadDir);

    // Удаляем файлы
    if (novel.zipFilename) {
      const zipPath = path.resolve(uploadDir, 'packs', novel.zipFilename);
      if (!zipPath.startsWith(uploadDirResolved)) {
        logger.warn({ zipPath }, 'Skipping zip deletion: path traversal detected');
      } else if (fs.existsSync(zipPath)) {
        fs.unlinkSync(zipPath);
      }
    }
    if (novel.coverUrl) {
      const coverPath = path.resolve(uploadDir, novel.coverUrl.replace(/^\//, ''));
      if (!coverPath.startsWith(uploadDirResolved)) {
        logger.warn({ coverPath }, 'Skipping cover deletion: path traversal detected');
      } else if (fs.existsSync(coverPath)) {
        fs.unlinkSync(coverPath);
      }
    }

    await prisma.novel.delete({ where: { id: req.params.id } });

    res.json({ message: 'Novel deleted' });
  } catch (err) {
    console.error('Error deleting novel:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/:id/chapters ── Список глав ─────────────────────────────
novelsRouter.get('/:id/chapters', async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel || !novel.isPublished) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    const chapters = await prisma.chapter.findMany({
      where: { novelId: req.params.id },
      orderBy: { number: 'asc' },
      select: {
        number: true,
        title: true,
        isReleased: true,
        releasedAt: true,
      },
    });

    res.json({
      novelId: req.params.id,
      chaptersCount: novel.chaptersCount,
      releasedChapters: novel.releasedChapters,
      chapters,
    });
  } catch (err) {
    console.error('Error fetching chapters:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/:id/chapters/:number/download ── Скачать JSON главы ─────
novelsRouter.get(
  '/:id/chapters/:number/download',
  async (req: Request, res: Response) => {
    try {
      const chapterNumber = parseInt(req.params.number);
      if (isNaN(chapterNumber)) {
        res.status(400).json({ error: 'Invalid chapter number' });
        return;
      }

      const novel = await prisma.novel.findUnique({
        where: { id: req.params.id },
      });

      if (!novel || !novel.isPublished || !novel.zipFilename) {
        res.status(404).json({ error: 'Novel not found' });
        return;
      }

      // Проверяем что глава выпущена
      const chapter = await prisma.chapter.findUnique({
        where: {
          novelId_number: { novelId: req.params.id, number: chapterNumber },
        },
      });

      if (!chapter || !chapter.isReleased) {
        res.status(404).json({ error: 'Chapter not available' });
        return;
      }

      // Извлекаем JSON главы из ZIP
      const zipPath = path.resolve(uploadDir, 'packs', novel.zipFilename);
      if (!fs.existsSync(zipPath)) {
        res.status(404).json({ error: 'Novel file not found on server' });
        return;
      }

      const chapterJson = extractChapterJsonFromZip(zipPath, chapterNumber);
      if (!chapterJson) {
        res.status(404).json({ error: 'Chapter not found in novel pack' });
        return;
      }

      res.setHeader('Content-Type', 'application/json');
      res.send(chapterJson);
    } catch (err) {
      console.error('Error downloading chapter:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// ─── GET /v1/novels/:id/languages ── Доступные языки перевода ────────────────
novelsRouter.get('/:id/languages', async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel || !novel.isPublished || !novel.zipFilename) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    const zipPath = path.resolve(uploadDir, 'packs', novel.zipFilename);
    if (!fs.existsSync(zipPath)) {
      res.status(404).json({ error: 'Novel file not found' });
      return;
    }

    const meta = extractMetaFromZip(zipPath);
    const sourceLanguage = (meta?.sourceLanguage as string) || 'ru';
    const translations = extractTranslationLanguagesFromZip(zipPath);

    res.json({
      novelId: req.params.id,
      sourceLanguage,
      availableLanguages: [sourceLanguage, ...translations],
      translations,
    });
  } catch (err) {
    console.error('Error fetching languages:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/:id/translations/:lang ── Скачать перевод ────────────────
novelsRouter.get('/:id/translations/:lang', async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel || !novel.isPublished || !novel.zipFilename) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    if (!LANG_RE.test(req.params.lang)) {
      res.status(400).json({ error: 'Invalid language code' });
      return;
    }

    const zipPath = path.resolve(uploadDir, 'packs', novel.zipFilename);
    if (!fs.existsSync(zipPath)) {
      res.status(404).json({ error: 'Novel file not found' });
      return;
    }

    const translation = extractTranslationFromZip(zipPath, req.params.lang);
    if (!translation) {
      res.status(404).json({ error: `Translation for '${req.params.lang}' not found` });
      return;
    }

    res.setHeader('Content-Type', 'application/json');
    res.send(translation);
  } catch (err) {
    console.error('Error fetching translation:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/novels/:id/translations/:lang ── Загрузить перевод ─────────────
novelsRouter.post('/:id/translations/:lang', authMiddleware, adminMiddleware, async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel || !novel.zipFilename) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    if (!LANG_RE.test(req.params.lang)) {
      res.status(400).json({ error: 'Invalid language code' });
      return;
    }

    const zipPath = path.resolve(uploadDir, 'packs', novel.zipFilename);
    if (!fs.existsSync(zipPath)) {
      res.status(404).json({ error: 'Novel file not found' });
      return;
    }

    const translationData = req.body;
    if (!translationData || !translationData.texts) {
      res.status(400).json({ error: 'Invalid translation data: texts field is required' });
      return;
    }

    addTranslationToZip(zipPath, req.params.lang, JSON.stringify(translationData, null, 2));

    res.json({
      message: `Translation for '${req.params.lang}' uploaded successfully`,
      novelId: req.params.id,
      language: req.params.lang,
    });
  } catch (err) {
    console.error('Error uploading translation:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/novels/:id/rate ── Оценить новеллу ────────────────────────────
novelsRouter.post('/:id/rate', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { value } = req.body;
    if (!value || value < 1 || value > 5 || !Number.isInteger(value)) {
      res.status(400).json({ error: 'Rating value must be an integer from 1 to 5' });
      return;
    }

    const novel = await prisma.novel.findUnique({ where: { id: req.params.id } });
    if (!novel || !novel.isPublished) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    await prisma.rating.upsert({
      where: { userId_novelId: { userId: req.userId!, novelId: req.params.id } },
      update: { value },
      create: { userId: req.userId!, novelId: req.params.id, value },
    });

    // Recalculate average rating
    const agg = await prisma.rating.aggregate({
      where: { novelId: req.params.id },
      _avg: { value: true },
      _count: { value: true },
    });

    await prisma.novel.update({
      where: { id: req.params.id },
      data: {
        averageRating: Math.round((agg._avg.value ?? 0) * 100) / 100,
        ratingCount: agg._count.value,
      },
    });

    res.json({ averageRating: agg._avg.value, ratingCount: agg._count.value });
  } catch (err) {
    console.error('Error rating novel:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/:id/rating ── Рейтинг текущего пользователя ─────────────
novelsRouter.get('/:id/rating', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const rating = await prisma.rating.findUnique({
      where: { userId_novelId: { userId: req.userId!, novelId: req.params.id } },
    });

    res.json({ rating: rating ? rating.value : null });
  } catch (err) {
    console.error('Error fetching rating:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/novels/:id/reviews ── Отзывы новеллы ───────────────────────────
novelsRouter.get('/:id/reviews', async (req: Request, res: Response) => {
  try {
    const reviews = await prisma.review.findMany({
      where: { novelId: req.params.id, status: 'approved' },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        text: true,
        createdAt: true,
        user: { select: { displayName: true } },
      },
    });

    res.json({ reviews });
  } catch (err) {
    console.error('Error fetching reviews:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/novels/:id/reviews ── Оставить отзыв ─────────────────────────
novelsRouter.post('/:id/reviews', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const { text } = req.body;
    if (!text || typeof text !== 'string' || text.trim().length === 0) {
      res.status(400).json({ error: 'Review text is required' });
      return;
    }
    if (text.length > 500) {
      res.status(400).json({ error: 'Review text must be 500 characters or less' });
      return;
    }

    const novel = await prisma.novel.findUnique({ where: { id: req.params.id } });
    if (!novel || !novel.isPublished) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    const existing = await prisma.review.findUnique({
      where: { userId_novelId: { userId: req.userId!, novelId: req.params.id } },
    });
    if (existing) {
      res.status(409).json({ error: 'You have already reviewed this novel' });
      return;
    }

    const review = await prisma.review.create({
      data: { userId: req.userId!, novelId: req.params.id, text: text.trim() },
    });

    res.status(201).json({ review });
  } catch (err) {
    console.error('Error creating review:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
