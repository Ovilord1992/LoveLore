import multer from 'multer';
import path from 'path';
import { v4 as uuid } from 'uuid';
import fs from 'fs';

const uploadDir = process.env.UPLOAD_DIR || './uploads';

// Ensure upload dirs exist
fs.mkdirSync(path.join(uploadDir, 'packs'), { recursive: true });
fs.mkdirSync(path.join(uploadDir, 'covers'), { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, path.join(uploadDir, 'packs'));
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuid()}${ext}`);
  },
});

export const upload = multer({
  storage,
  limits: { fileSize: 100 * 1024 * 1024 }, // 100 MB max — типичная новелла со спрайтами/фонами умещается; сильно больше — повод пересобрать ZIP без сырого ассета
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'application/zip' || file.originalname.endsWith('.zip')) {
      cb(null, true);
    } else {
      // statusCode помечает ошибку как клиентскую (400) для глобального error-handler.
      const err = new Error('Only ZIP files are allowed') as Error & { statusCode?: number };
      err.statusCode = 400;
      cb(err);
    }
  },
});
