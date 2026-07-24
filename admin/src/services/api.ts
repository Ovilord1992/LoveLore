import axios, { AxiosError, type InternalAxiosRequestConfig } from 'axios';
import { message } from 'antd';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:3000/v1';

const TOKEN_KEY = 'admin_token';
const REFRESH_TOKEN_KEY = 'admin_refresh_token';

const api = axios.create({ baseURL: API_BASE });

export const saveTokens = (token: string, refreshToken?: string) => {
  localStorage.setItem(TOKEN_KEY, token);
  if (refreshToken) localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
};

export const clearTokens = () => {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
};

// Добавляем JWT токен к каждому запросу
api.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Сбрасываем сессию и уводим на логин (с дедупликацией сообщений/редиректа)
const handleAuthFailure = (msg?: string) => {
  const alreadyOnLogin = window.location.hash === '#/login';
  clearTokens();
  if (!alreadyOnLogin) {
    if (msg) message.error(msg);
    // Смена hash — App.tsx слушает 'hashchange' и разлогинивает UI
    window.location.hash = '#/login';
  }
};

// ─── Refresh-токены (ротация, спека 2.1) ─────────────────────────────────────
// Один сериализованный refresh на все параллельные 401: первый запрос запускает
// обмен, остальные ждут тот же промис — без гонок и двойной ротации.
let refreshPromise: Promise<string | null> | null = null;

const refreshAccessToken = (): Promise<string | null> => {
  if (!refreshPromise) {
    refreshPromise = (async () => {
      const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY);
      if (!refreshToken) return null;
      try {
        // Чистый axios: интерсепторы api сюда не применяются (иначе рекурсия на 401)
        const { data } = await axios.post(`${API_BASE}/auth/refresh`, { refreshToken });
        saveTokens(data.token, data.refreshToken);
        return data.token as string;
      } catch {
        return null;
      }
    })().finally(() => {
      refreshPromise = null;
    });
  }
  return refreshPromise;
};

type RetriableConfig = InternalAxiosRequestConfig & { _retry?: boolean };

// 401 — пробуем один refresh и повторяем запрос; при провале — логин.
// 403 — роль не admin, сразу на логин.
api.interceptors.response.use(
  (res) => res,
  async (err: AxiosError) => {
    const status = err.response?.status;
    const original = err.config as RetriableConfig | undefined;
    const url = original?.url || '';
    const isAuthEndpoint = url.includes('/auth/');

    if (status === 401 && original && !original._retry && !isAuthEndpoint) {
      const newToken = await refreshAccessToken();
      if (newToken) {
        original._retry = true;
        original.headers.Authorization = `Bearer ${newToken}`;
        return api(original);
      }
      handleAuthFailure();
    } else if (status === 401) {
      handleAuthFailure();
    } else if (status === 403) {
      handleAuthFailure('Доступ запрещён: требуется роль администратора');
    }
    return Promise.reject(err);
  },
);

// Отзыв refresh-токена на сервере + очистка локальной сессии
export const logoutAdmin = async () => {
  const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY);
  clearTokens();
  if (refreshToken) {
    try {
      await axios.post(`${API_BASE}/auth/logout`, { refreshToken });
    } catch {
      // Сервер недоступен/токен уже отозван — сессия всё равно очищена локально
    }
  }
};

export const getReviews = (params?: { status?: string; page?: number; limit?: number }) =>
  api.get('/admin/reviews', { params });
export const approveReview = (id: string) =>
  api.patch(`/admin/reviews/${id}`, { status: 'approved' });
export const rejectReview = (id: string) =>
  api.patch(`/admin/reviews/${id}`, { status: 'rejected' });
export const deleteReview = (id: string) =>
  api.delete(`/admin/reviews/${id}`);

export default api;
