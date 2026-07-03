import axios from 'axios';
import { message } from 'antd';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:3000/v1';

const api = axios.create({ baseURL: API_BASE });

// Добавляем JWT токен к каждому запросу
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Сбрасываем сессию и уводим на логин (с дедупликацией сообщений/редиректа)
const handleAuthFailure = (msg?: string) => {
  const alreadyOnLogin = window.location.hash === '#/login';
  localStorage.removeItem('admin_token');
  if (!alreadyOnLogin) {
    if (msg) message.error(msg);
    // Смена hash — App.tsx слушает 'hashchange' и разлогинивает UI
    window.location.hash = '#/login';
  }
};

// 401 — нет/просрочен токен; 403 — роль не admin. Оба ведут на логин.
api.interceptors.response.use(
  (res) => res,
  (err) => {
    const status = err.response?.status;
    if (status === 401) {
      handleAuthFailure();
    } else if (status === 403) {
      handleAuthFailure('Доступ запрещён: требуется роль администратора');
    }
    return Promise.reject(err);
  },
);

export const getReviews = (params?: { status?: string; page?: number; limit?: number }) =>
  api.get('/admin/reviews', { params });
export const approveReview = (id: string) =>
  api.patch(`/admin/reviews/${id}`, { status: 'approved' });
export const rejectReview = (id: string) =>
  api.patch(`/admin/reviews/${id}`, { status: 'rejected' });
export const deleteReview = (id: string) =>
  api.delete(`/admin/reviews/${id}`);

export default api;
