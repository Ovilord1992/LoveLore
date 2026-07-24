import express, { NextFunction, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import multer from 'multer';
import pinoHttp from 'pino-http';
import path from 'path';
import { novelsRouter } from './routes/novels';
import { authRouter } from './routes/auth';
import { syncRouter } from './routes/sync';
import { adminRouter } from './routes/admin';
import { configRouter } from './routes/config';
import { iapRouter } from './routes/iap';
import { economyRouter } from './routes/economy';
import { analyticsRouter } from './routes/analytics';
import { startChapterReleaseScheduler } from './scheduler';
import { logger } from './utils/logger';

const app = express();
const PORT = Number(process.env.PORT) || 3000;
const uploadDir = process.env.UPLOAD_DIR || './uploads';

// CORS_ORIGINS — каноничное имя (спека 2.7); ALLOWED_ORIGINS поддерживается
// для обратной совместимости.
const allowedOrigins = (
  process.env.CORS_ORIGINS ||
  process.env.ALLOWED_ORIGINS ||
  'http://localhost:5173,http://localhost:5174'
)
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

// Helmet — безопасные HTTP-заголовки. Должен идти первым.
// crossOriginResourcePolicy ослаблен до 'cross-origin', чтобы не блокировать
// раздачу обложек (/covers/*) из других origin (мобильное приложение, web-клиенты).
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);

app.use(
  cors({
    origin: (origin, cb) => {
      // Запросы без origin (мобильные клиенты, curl) — пропускаем.
      if (!origin) return cb(null, true);
      if (allowedOrigins.includes(origin)) return cb(null, true);
      logger.warn({ origin }, 'CORS rejected origin');
      const err = new Error(`Origin ${origin} not allowed by CORS`) as Error & { statusCode?: number };
      err.statusCode = 403;
      cb(err);
    },
    credentials: true,
  })
);
app.use(pinoHttp({ logger }));
// Лимит тела: IAP-чеки Apple base64 могут быть ~100КБ (MAX_RECEIPT_LEN=100000),
// что превышает дефолтные 100kb express.json — поднимаем до 1mb с запасом.
app.use(express.json({ limit: '1mb' }));

// Статическая раздача обложек — из той же директории, куда пишет upload.ts
// (UPLOAD_DIR/covers), а не из захардкоженного пути.
app.use('/covers', express.static(path.join(uploadDir, 'covers')));

// API v1
app.use('/v1/auth', authRouter);
app.use('/v1/novels', novelsRouter);
app.use('/v1/sync', syncRouter);
app.use('/v1/admin', adminRouter);
app.use('/v1/config', configRouter);
app.use('/v1/iap', iapRouter);
app.use('/v1/economy', economyRouter);
app.use('/v1/analytics', analyticsRouter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

// ─── Глобальный error-handler ───────────────────────────────────────────────
// Должен идти ПОСЛЕ всех роутов. Логирует ошибку на сервере, клиенту отдаёт
// чистый JSON без стектрейса. Обрабатывает ошибки Multer (размер/тип файла)
// и помеченные statusCode клиентские ошибки (fileFilter, CORS).
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (res.headersSent) {
    return _next(err);
  }

  // Ошибки Multer: превышение размера → 413, прочие (тип/поле) → 400.
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      logger.warn({ code: err.code }, 'Upload rejected: file too large');
      res.status(413).json({ error: 'File too large' });
      return;
    }
    logger.warn({ code: err.code, message: err.message }, 'Upload rejected');
    res.status(400).json({ error: err.message });
    return;
  }

  // Клиентские ошибки с явным statusCode (fileFilter «Only ZIP», CORS и т.п.).
  const status = (err as { statusCode?: number; status?: number } | null)?.statusCode
    ?? (err as { status?: number } | null)?.status;
  if (typeof status === 'number' && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : 'Bad request';
    res.status(status).json({ error: message });
    return;
  }

  // Всё прочее — 500 без раскрытия стектрейса клиенту.
  logger.error({ err }, 'Unhandled error');
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  logger.info(`🚀 Amoria Server running on http://0.0.0.0:${PORT}`);
});

// Планировщик авторелиза глав (не в тестах).
if (process.env.NODE_ENV !== 'test') {
  startChapterReleaseScheduler();
}

export default app;
