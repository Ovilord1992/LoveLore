import express from 'express';
import cors from 'cors';
import path from 'path';
import { novelsRouter } from './routes/novels';
import { authRouter } from './routes/auth';
import { syncRouter } from './routes/sync';

const app = express();
const PORT = Number(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json());

// Статическая раздача обложек
app.use('/covers', express.static(path.join(__dirname, '../uploads/covers')));

// API v1
app.use('/v1/auth', authRouter);
app.use('/v1/novels', novelsRouter);
app.use('/v1/sync', syncRouter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Amoria Server running on http://0.0.0.0:${PORT}`);
});

export default app;
