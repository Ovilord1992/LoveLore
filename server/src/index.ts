import express from 'express';
import cors from 'cors';
import path from 'path';
import { novelsRouter } from './routes/novels';

const app = express();
const PORT = Number(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json());

// Статическая раздача обложек
app.use('/covers', express.static(path.join(__dirname, '../uploads/covers')));

// API v1
app.use('/v1/novels', novelsRouter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

app.listen(PORT, () => {
  console.log(`🚀 Amoria Server running on http://localhost:${PORT}`);
});

export default app;
