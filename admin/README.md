# Amoria Admin Panel

Веб-панель администрирования для управления пользователями, новеллами и мониторинга платформы Amoria.

## Стек

- **React 18 + TypeScript** — UI
- **Vite** — сборка и dev-сервер
- **Ant Design** — UI-компоненты (тёмная тема, русская локаль)
- **Axios** — HTTP-клиент с JWT-интерцептором

---

## Быстрый старт

```bash
npm install
npm run dev                    # http://localhost:5174
```

> **Требуется** работающий сервер (`cd ../server && npm run dev`).

### Вход

По умолчанию: `admin@amoria.app` / `admin123`  
(настраивается через `ADMIN_EMAIL` / `ADMIN_PASSWORD` в `server/.env`)

Доступ имеют только пользователи с ролью `admin`.

---

## Структура

```
admin/
├── src/
│   ├── App.tsx               # Роутинг, ConfigProvider (ruRU), AntApp
│   ├── main.tsx              # Точка входа
│   ├── services/
│   │   └── api.ts            # Axios: baseURL + JWT interceptor + auto-logout
│   ├── pages/
│   │   ├── LoginPage.tsx     # Страница входа (email + пароль, проверка роли)
│   │   ├── DashboardPage.tsx # Дашборд: карточки статистики
│   │   ├── UsersPage.tsx     # Таблица пользователей (поиск, детали, CRUD)
│   │   └── NovelsPage.tsx    # Таблица новелл (publish/unpublish, загрузка ZIP)
│   └── components/
│       └── AdminLayout.tsx   # Sidebar + header layout
├── .env                      # VITE_API_URL
├── package.json
├── vite.config.ts
└── tsconfig.json
```

---

## Функциональность

### Дашборд

Карточки со статистикой:
- 👥 Всего пользователей
- 📚 Всего новелл (опубликованных)
- 📥 Всего загрузок
- 📊 Активность: за 24 часа / 7 дней / 30 дней

### Управление пользователями

- Таблица с пагинацией и поиском по email/имени
- Детали пользователя: профиль, валюта, список сохранений
- Редактирование: роль (user/admin), начисление алмазов и билетов
- Удаление пользователя (с подтверждением, нельзя удалить себя)

### Управление новеллами

- Таблица всех новелл (включая скрытые/неопубликованные)
- Переключатель **Publish/Unpublish** — скрытие из каталога приложения
- Загрузка ZIP: кнопка «Загрузить ZIP» → выбор файла → автоматическое извлечение meta.json + обложки
- Удаление новеллы (удаляет ZIP, обложку и запись из БД)
- Информация: название, автор, главы, загрузки, размер файла, версия

---

## Настройка

### .env

```env
VITE_API_URL=http://localhost:3000/v1
```

Для production замени на реальный URL сервера.

### API-интерцептор

JWT-токен хранится в `localStorage`. При 401 ошибке автоматически очищается и редиректится на логин.

---

## Скрипты

| Команда | Описание |
|---------|----------|
| `npm run dev` | Dev-сервер (Vite, порт 5174) |
| `npm run build` | Production-сборка → `dist/` |
| `npm run preview` | Превью production-сборки |
| `npm run lint` | ESLint |

---

## API-эндпоинты (используемые)

Все запросы идут через `VITE_API_URL` с заголовком `Authorization: Bearer <token>`.

| Эндпоинт | Что делает в админке |
|----------|---------------------|
| `POST /auth/login` | Вход (проверка `role === 'admin'`) |
| `GET /admin/stats` | Данные для дашборда |
| `GET /admin/users` | Таблица пользователей |
| `GET /admin/users/:id` | Модал с деталями |
| `PATCH /admin/users/:id` | Редактирование роли/валюты |
| `DELETE /admin/users/:id` | Удаление |
| `GET /admin/novels` | Таблица новелл |
| `PATCH /admin/novels/:id` | Publish/unpublish, метаданные |
| `POST /novels/upload` | Загрузка ZIP |
| `DELETE /novels/:id` | Удаление новеллы |
