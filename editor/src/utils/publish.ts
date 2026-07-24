// Публикация на сервер Amoria напрямую из редактора (формат v2, часть 2.7):
// существующие админ-ручки создания/перезаливки новеллы (multipart ZIP,
// POST /v1/novels/upload, поле "file") + upsert главы (POST
// /v1/admin/novels/:id/chapters, JSON { chapter }, спека 2.4).
import type { Chapter } from '../types/novel';

export interface PublishSettings {
  baseUrl: string;
  email: string;
  token: string | null;
  refreshToken: string | null;
}

const SETTINGS_KEY = 'amoria-editor-publish';

export const DEFAULT_BASE_URL = 'http://localhost:3000/v1';

export function loadPublishSettings(): PublishSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<PublishSettings>;
      return {
        baseUrl: parsed.baseUrl || DEFAULT_BASE_URL,
        email: parsed.email || '',
        token: parsed.token ?? null,
        refreshToken: parsed.refreshToken ?? null,
      };
    }
  } catch {
    // ignore
  }
  return { baseUrl: DEFAULT_BASE_URL, email: '', token: null, refreshToken: null };
}

export function savePublishSettings(settings: PublishSettings): void {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch {
    // ignore
  }
}

export class PublishError extends Error {
  status?: number;
  constructor(message: string, status?: number) {
    super(message);
    this.status = status;
  }
}

function normalizeBaseUrl(baseUrl: string): string {
  return baseUrl.replace(/\/+$/, '');
}

async function parseErrorBody(res: Response): Promise<string | null> {
  try {
    const data = await res.json() as { error?: string; message?: string };
    return data.error || data.message || null;
  } catch {
    return null;
  }
}

function friendlyMessage(status: number, serverMsg: string | null, context: 'login' | 'upload' | 'chapter'): string {
  switch (status) {
    case 400: return serverMsg ? `Сервер отклонил запрос: ${serverMsg}` : 'Сервер отклонил запрос (400)';
    case 401: return context === 'login'
      ? 'Неверный email или пароль'
      : 'Сессия истекла — войдите заново';
    case 403: return 'Недостаточно прав: нужен аккаунт с ролью администратора';
    case 404: return context === 'chapter'
      ? 'Сервер не поддерживает отправку отдельной главы (нет ручки POST /admin/novels/:id/chapters — обновите сервер) или новелла не найдена'
      : (serverMsg ? `Не найдено: ${serverMsg}` : 'Ручка не найдена (404) — проверьте base URL (должен оканчиваться на /v1)');
    case 413: return 'Архив слишком большой — сервер отклонил загрузку (лимит 500 МБ)';
    case 429: return 'Слишком много запросов — подождите минуту и повторите';
    default:
      if (status >= 500) return `Ошибка сервера (${status})${serverMsg ? `: ${serverMsg}` : ''}`;
      return serverMsg ? `${serverMsg} (${status})` : `Неожиданный ответ сервера (${status})`;
  }
}

async function request(url: string, init: RequestInit, context: 'login' | 'upload' | 'chapter'): Promise<Response> {
  let res: Response;
  try {
    res = await fetch(url, init);
  } catch {
    throw new PublishError('Сервер недоступен — проверьте base URL и что сервер запущен');
  }
  if (!res.ok) {
    const serverMsg = await parseErrorBody(res);
    throw new PublishError(friendlyMessage(res.status, serverMsg, context), res.status);
  }
  return res;
}

export interface LoginResult {
  token: string;
  refreshToken: string | null;
  role?: string;
}

/** POST /v1/auth/login → { user, token[, refreshToken] } */
export async function login(baseUrl: string, email: string, password: string): Promise<LoginResult> {
  const res = await request(`${normalizeBaseUrl(baseUrl)}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  }, 'login');
  const data = await res.json() as { token?: string; refreshToken?: string; user?: { role?: string } };
  if (!data.token) throw new PublishError('Сервер не вернул токен — неожиданный формат ответа');
  if (data.user?.role && data.user.role !== 'admin') {
    throw new PublishError('Вход выполнен, но роль не admin — публикация будет запрещена сервером');
  }
  return { token: data.token, refreshToken: data.refreshToken ?? null, role: data.user?.role };
}

/** POST /v1/auth/refresh (спека 2.1, с ротацией). На старом сервере ручки нет — вернёт null. */
async function tryRefresh(baseUrl: string, refreshToken: string): Promise<LoginResult | null> {
  try {
    const res = await fetch(`${normalizeBaseUrl(baseUrl)}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
    if (!res.ok) return null;
    const data = await res.json() as { token?: string; refreshToken?: string };
    if (!data.token) return null;
    return { token: data.token, refreshToken: data.refreshToken ?? refreshToken };
  } catch {
    return null;
  }
}

/** Выполнить авторизованный запрос; на 401 — один сериализованный refresh и повтор.
 *  Возвращает Response и (возможно обновлённую) пару токенов. */
async function authedRequest(
  settings: PublishSettings,
  path: string,
  init: RequestInit,
  context: 'upload' | 'chapter',
): Promise<{ res: Response; settings: PublishSettings }> {
  if (!settings.token) throw new PublishError('Сначала войдите как администратор');
  const base = normalizeBaseUrl(settings.baseUrl);
  const withAuth = (token: string): RequestInit => ({
    ...init,
    headers: { ...(init.headers || {}), Authorization: `Bearer ${token}` },
  });
  try {
    const res = await request(`${base}${path}`, withAuth(settings.token), context);
    return { res, settings };
  } catch (err) {
    if (err instanceof PublishError && err.status === 401 && settings.refreshToken) {
      const refreshed = await tryRefresh(settings.baseUrl, settings.refreshToken);
      if (refreshed) {
        const next: PublishSettings = { ...settings, token: refreshed.token, refreshToken: refreshed.refreshToken };
        savePublishSettings(next);
        const res = await request(`${base}${path}`, withAuth(refreshed.token), context);
        return { res, settings: next };
      }
    }
    throw err;
  }
}

/** Существует ли новелла на сервере (публичная ручка GET /v1/novels/:id). */
export async function novelExists(baseUrl: string, novelId: string): Promise<boolean> {
  try {
    const res = await fetch(`${normalizeBaseUrl(baseUrl)}/novels/${encodeURIComponent(novelId)}`);
    return res.ok;
  } catch {
    throw new PublishError('Сервер недоступен — проверьте base URL и что сервер запущен');
  }
}

export interface UploadNovelResult {
  settings: PublishSettings;
  message: string;
}

/** Загрузка/перезаливка ZIP новеллы: POST /v1/novels/upload (multipart, поле "file"). */
export async function uploadNovelZip(
  settings: PublishSettings,
  zipBlob: Blob,
  novelId: string,
): Promise<UploadNovelResult> {
  const form = new FormData();
  form.append('file', new File([zipBlob], `${novelId}.zip`, { type: 'application/zip' }));
  const { res, settings: next } = await authedRequest(settings, '/novels/upload', {
    method: 'POST',
    body: form,
  }, 'upload');
  const data = await res.json().catch(() => ({})) as { message?: string };
  return { settings: next, message: data.message || 'Новелла загружена' };
}

/** Upsert одной главы: POST /v1/admin/novels/:id/chapters, JSON { chapter } (спека 2.4). */
export async function uploadChapter(
  settings: PublishSettings,
  novelId: string,
  chapter: Chapter,
): Promise<UploadNovelResult> {
  const { res, settings: next } = await authedRequest(
    settings,
    `/admin/novels/${encodeURIComponent(novelId)}/chapters`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chapter }),
    },
    'chapter',
  );
  const data = await res.json().catch(() => ({})) as { message?: string };
  return { settings: next, message: data.message || `Глава ${chapter.number} отправлена` };
}
