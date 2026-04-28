import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import path from 'path';
import { novelsRouter } from './routes/novels';
import { authRouter } from './routes/auth';
import { syncRouter } from './routes/sync';
import { adminRouter } from './routes/admin';
import { configRouter } from './routes/config';
import { iapRouter } from './routes/iap';
import { logger } from './utils/logger';

const app = express();
const PORT = Number(process.env.PORT) || 3000;

const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:5173,http://localhost:5174')
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
      cb(new Error(`Origin ${origin} not allowed by CORS`));
    },
    credentials: true,
  })
);
app.use(pinoHttp({ logger }));
app.use(express.json());

// Статическая раздача обложек
app.use('/covers', express.static(path.join(__dirname, '../uploads/covers')));

// API v1
app.use('/v1/auth', authRouter);
app.use('/v1/novels', novelsRouter);
app.use('/v1/sync', syncRouter);
app.use('/v1/admin', adminRouter);
app.use('/v1/config', configRouter);
app.use('/v1/iap', iapRouter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

app.listen(PORT, '0.0.0.0', () => {
  logger.info(`🚀 Amoria Server running on http://0.0.0.0:${PORT}`);
});

export default app;
