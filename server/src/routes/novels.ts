import { Router, Request, Response } from 'express';
import path from 'path';
import fs from 'fs';
import prisma from '../db';
import { upload } from '../middleware/upload';
import { extractMetaFromZip, extractCoverFromZip, extractChaptersFromZip, extractChapterJsonFromZip } from '../utils/zip';

export const novelsRouter = Router();

const uploadDir = process.env.UPLOAD_DIR || './uploads';

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

    if (!novel || !novel.zipFilename) {
      res.status(404).json({ error: 'Novel not found or no file available' });
      return;
    }

    const filePath = path.resolve(uploadDir, 'packs', novel.zipFilename);

    if (!fs.existsSync(filePath)) {
      res.status(404).json({ error: 'File not found on server' });
      return;
    }

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
      } catch {
        // ignore
      }

      // Если новелла уже существует — обновляем, иначе создаём
      const existing = await prisma.novel.findUnique({
        where: { id: novelId },
      });

      // Удаляем старый ZIP если обновляем
      if (existing?.zipFilename) {
        const oldPath = path.resolve(uploadDir, 'packs', existing.zipFilename);
        if (fs.existsSync(oldPath)) fs.unlinkSync(oldPath);
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
novelsRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const novel = await prisma.novel.findUnique({
      where: { id: req.params.id },
    });

    if (!novel) {
      res.status(404).json({ error: 'Novel not found' });
      return;
    }

    // Удаляем файлы
    if (novel.zipFilename) {
      const zipPath = path.resolve(uploadDir, 'packs', novel.zipFilename);
      if (fs.existsSync(zipPath)) fs.unlinkSync(zipPath);
    }
    if (novel.coverUrl) {
      const coverPath = path.resolve(uploadDir, novel.coverUrl.replace(/^\//, ''));
      if (fs.existsSync(coverPath)) fs.unlinkSync(coverPath);
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

    if (!novel) {
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
      totalChapters: novel.chaptersCount,
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

      if (!novel || !novel.zipFilename) {
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
