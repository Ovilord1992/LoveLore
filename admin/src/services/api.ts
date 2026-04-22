import axios from 'axios';

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

// При 401 — перенаправляем на логин
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('admin_token');
      window.location.hash = '#/login';
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
