import { Router, Response } from 'express';
import bcrypt from 'bcryptjs';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';
import prisma from '../db';
import { AuthRequest, generateToken, authMiddleware } from '../middleware/auth';

export const authRouter = Router();

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

const APPLE_CLIENT_ID = process.env.APPLE_CLIENT_ID || '';

// ─── POST /v1/auth/register ── Регистрация ──────────────────────────────────
authRouter.post('/register', async (req: AuthRequest, res: Response) => {
  try {
    const { email, password, displayName } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'Email and password are required' });
      return;
    }

    if (password.length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters' });
      return;
    }

    // Проверяем, не занят ли email
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      res.status(409).json({ error: 'Email already registered' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        displayName: displayName || 'Читатель',
        // Создаём связанные данные сразу
        profile: { create: { displayName: displayName || 'Читатель' } },
        currency: { create: {} },
      },
      select: { id: true, email: true, displayName: true },
    });

    const token = generateToken(user.id);

    res.status(201).json({ user: { ...user, role: 'user' }, token });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/auth/login ── Вход ────────────────────────────────────────────
authRouter.post('/login', async (req: AuthRequest, res: Response) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'Email and password are required' });
      return;
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const token = generateToken(user.id);

    res.json({
      user: { id: user.id, email: user.email, displayName: user.displayName, role: user.role },
      token,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── GET /v1/auth/me ── Текущий пользователь ────────────────────────────────
authRouter.get('/me', authMiddleware, async (req: AuthRequest, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: { id: true, email: true, displayName: true, role: true, createdAt: true },
    });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ user });
  } catch (err) {
    console.error('Me error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── POST /v1/auth/social ── Вход через Google / Apple ───────────────────────
authRouter.post('/social', async (req: AuthRequest, res: Response) => {
  try {
    const { provider, idToken, identityToken, email, displayName } = req.body;

    if (!provider) {
      res.status(400).json({ error: 'provider is required' });
      return;
    }

    let verifiedEmail: string | null = null;
    let verifiedName: string | null = null;

    if (provider === 'google') {
      if (!idToken) {
        res.status(400).json({ error: 'idToken is required' });
        return;
      }
      // Верификация Google ID Token
      try {
        const ticket = await googleClient.verifyIdToken({
          idToken,
          audience: GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        if (!payload || !payload.email) {
          res.status(401).json({ error: 'Invalid Google token' });
          return;
        }
        verifiedEmail = payload.email;
        verifiedName = payload.name || null;
      } catch {
        res.status(401).json({ error: 'Google token verification failed' });
        return;
      }
    } else if (provider === 'apple') {
      if (!APPLE_CLIENT_ID) {
        res.status(503).json({ error: 'Apple Sign-In not configured' });
        return;
      }
      // Apple отправляет displayName только при первом входе — клиент шлёт его опционально.
      // identityToken (новое имя) предпочтительнее, idToken оставлен для обратной совместимости.
      const appleToken = identityToken || idToken;
      if (!appleToken) {
        res.status(400).json({ error: 'identityToken is required' });
        return;
      }
      try {
        const appleData = await appleSignin.verifyIdToken(appleToken, {
          audience: APPLE_CLIENT_ID,
          ignoreExpiration: false,
        });
        if (!appleData.email) {
          res.status(400).json({ error: 'Apple token missing email' });
          return;
        }
        verifiedEmail = appleData.email;
        // Apple не возвращает имя в токене — оно может прийти только из тела запроса при первом логине
        verifiedName = null;
      } catch {
        res.status(401).json({ error: 'Apple token verification failed' });
        return;
      }
    } else {
      res.status(400).json({ error: 'Unsupported provider. Use "google" or "apple"' });
      return;
    }

    if (!verifiedEmail) {
      res.status(400).json({ error: 'Could not determine email from provider' });
      return;
    }

    // Ищем или создаём пользователя
    let user = await prisma.user.findUnique({ where: { email: verifiedEmail } });

    if (!user) {
      // Создаём нового пользователя (без пароля — через соцсеть).
      // displayName из тела запроса используем только для первого входа (Apple шлёт его один раз).
      const name = verifiedName || displayName || 'Читатель';
      user = await prisma.user.create({
        data: {
          email: verifiedEmail,
          passwordHash: '', // пустой — вход только через соцсеть
          displayName: name,
          profile: { create: { displayName: name } },
          currency: { create: {} },
        },
      });
    }

    const token = generateToken(user.id);

    res.json({
      user: { id: user.id, email: user.email, displayName: user.displayName, role: user.role },
      token,
    });
  } catch (err) {
    console.error('Social auth error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
