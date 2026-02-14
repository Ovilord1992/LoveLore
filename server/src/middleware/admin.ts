import { Response, NextFunction } from 'express';
import prisma from '../db';
import { AuthRequest } from './auth';

/** Middleware: проверяет JWT + role === 'admin' */
export async function adminMiddleware(req: AuthRequest, res: Response, next: NextFunction): Promise<void> {
  if (!req.userId) {
    res.status(401).json({ error: 'Authorization required' });
    return;
  }

  const user = await prisma.user.findUnique({
    where: { id: req.userId },
    select: { role: true },
  });

  if (!user || user.role !== 'admin') {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  next();
}
