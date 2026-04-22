# Amoria Server

REST API для каталога и дистрибуции визуальных новелл, авторизации, синхронизации прогресса игроков и администрирования.

## Стек

- **Node.js + Express + TypeScript** — REST API
- **PostgreSQL + Prisma ORM** — база данных
- **JWT** — авторизация (email/пароль + Google + Apple)
- **Multer** — загрузка файлов (до 500 МБ)
- **adm-zip** — извлечение meta.json, обложек и глав из ZIP
- **bcryptjs** — хеширование паролей
- **google-auth-library** — верификация Google OAuth токенов

---

## Быстрый старт

### 1. PostgreSQL

```bash
docker compose up -d
```

Поднимает PostgreSQL 16 на порту `5432` (база `amoria`, пользователь `amoria`).

### 2. Установка зависимостей

```bash
npm install
```

### 3. Настройка окружения

```bash
cp .env .env.local   # Отредактируй при необходимости
```

### 4. Миграция и seed

```bash
npx prisma migrate dev --name init    # Создаёт таблицы
npx prisma db seed                    # Создаёт админа + демо-новеллы
```

Seed создаёт:
- Админа: `admin@amoria.app` / `admin123` (настраивается через `ADMIN_EMAIL` / `ADMIN_PASSWORD`)
- Демо-новеллы: «Тени Петербурга», «Парижские тайны»

### 5. Запуск

```bash
npm run dev                           # Dev-сервер с hot-reload (tsx watch)
```

Сервер стартует на `http://0.0.0.0:3000` (доступен с реальных устройств в сети).

Проверка: `curl http://localhost:3000/health` → `{"status":"ok","version":"1.0.0"}`

---

## Структура проекта

```
server/
├── src/
│   ├── index.ts              # Точка входа: Express app, роуты, статика
│   ├── db.ts                 # Prisma Client singleton
│   ├── routes/
│   │   ├── auth.ts           # Авторизация: register, login, social, me
│   │   ├── novels.ts         # Каталог: list, detail, download, upload, delete
│   │   ├── sync.ts           # Синхронизация: saves, profile, currency
│   │   └── admin.ts          # Админка: stats, users CRUD, novels management
│   ├── middleware/
│   │   ├── auth.ts           # JWT проверка → req.userId
│   │   ├── admin.ts          # Проверка роли admin
│   │   └── upload.ts         # Multer конфигурация (disk storage, 500MB limit)
│   └── utils/
│       └── zip.ts            # Извлечение meta.json, cover и глав из ZIP
├── prisma/
│   ├── schema.prisma         # Схема БД
│   ├── seed.ts               # Тестовые данные
│   └── migrations/           # Миграции
├── uploads/                  # Загруженные файлы (создаётся автоматически)
│   ├── packs/                # ZIP-файлы новелл (UUID.zip)
│   └── covers/               # Обложки (novelId.png)
├── docker-compose.yml        # PostgreSQL
├── .env                      # Переменные окружения
├── package.json
└── tsconfig.json
```

---

## Хранилище файлов

### Загрузка новеллы (POST /v1/novels/upload)

При загрузке ZIP-файла сервер:

1. **Сохраняет ZIP** в `uploads/packs/<uuid>.zip`
2. **Извлекает meta.json** → читает `id`, `title`, `description`, `author`, `tags`
3. **Извлекает обложку** (cover.png/jpg) → сохраняет в `uploads/covers/<novelId>.ext`
4. **Считает главы** (файлы в `chapters/` внутри ZIP)
5. **Создаёт записи Chapter** в БД для каждой найденной главы (isReleased: true)
6. **Создаёт/обновляет** запись Novel в БД (при обновлении инкрементирует `version`)

### Скачивание новеллы (GET /v1/novels/:id/download)

Отдаёт ZIP-файл из `uploads/packs/` и инкрементирует счётчик `downloads`.

### Статическая раздача обложек

Обложки доступны по URL: `http://localhost:3000/covers/<novelId>.png`

---

## API Endpoints

### Health

| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/health` | Health check |

### Каталог новелл

| Метод | Путь | Auth | Описание |
|-------|------|------|----------|
| `GET` | `/v1/novels` | — | Каталог опубликованных новелл (`isPublished: true`) |
| `GET` | `/v1/novels/:id` | — | Детали одной новеллы |
| `GET` | `/v1/novels/:id/download` | — | Скачать ZIP-пак (инкремент downloads) |
| `POST` | `/v1/novels/upload` | — | Загрузить новеллу (multipart, поле `file`) |
| `DELETE` | `/v1/novels/:id` | — | Удалить новеллу + файлы |

### Главы новелл

| Метод | Путь | Auth | Описание |
|-------|------|------|----------|
| `GET` | `/v1/novels/:id/chapters` | — | Список глав (number, title, isReleased, releasedAt) |
| `GET` | `/v1/novels/:id/chapters/:number/download` | — | Скачать JSON одной главы |

### Авторизация

| Метод | Путь | Auth | Описание |
|-------|------|------|----------|
| `POST` | `/v1/auth/register` | — | Регистрация (email + пароль ≥ 6 символов) |
| `POST` | `/v1/auth/login` | — | Вход (email + пароль → JWT, 30 дней) |
| `POST` | `/v1/auth/social` | — | Вход через Google / Apple (`provider` + `idToken`) |
| `GET` | `/v1/auth/me` | 🔒 JWT | Текущий пользователь (id, email, displayName, role) |

Все ответы авторизации возвращают: `{ user: { id, email, displayName, role }, token }`.

### Синхронизация 🔒

Все эндпоинты требуют заголовок `Authorization: Bearer <token>`.

| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/v1/sync/saves` | Все сохранения пользователя |
| `GET` | `/v1/sync/saves/:novelId` | Сохранение конкретной новеллы |
| `PUT` | `/v1/sync/saves/:novelId` | Сохранить/обновить прогресс (`{ data: {...} }`) |
| `DELETE` | `/v1/sync/saves/:novelId` | Удалить сохранение |
| `GET` | `/v1/sync/profile` | Получить профиль (аватар, статистика, CG, достижения) |
| `PUT` | `/v1/sync/profile` | Обновить профиль |
| `GET` | `/v1/sync/currency` | Получить валюту (алмазы, билеты) |
| `PUT` | `/v1/sync/currency` | Обновить валюту |
| `GET` | `/v1/sync/all` | Все данные: saves + profile + currency |

### Админка 🔒🛡️

Все эндпоинты требуют JWT + роль `admin`.

| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/v1/admin/stats` | Статистика: пользователи, новеллы, загрузки, активность |
| `GET` | `/v1/admin/users` | Список пользователей (?page, ?limit, ?search, ?sort, ?order) |
| `GET` | `/v1/admin/users/:id` | Детали пользователя (профиль, валюта, сохранения) |
| `PATCH` | `/v1/admin/users/:id` | Редактировать (role, diamonds, tickets) |
| `DELETE` | `/v1/admin/users/:id` | Удалить пользователя (нельзя удалить себя) |
| `GET` | `/v1/admin/novels` | Все новеллы, включая неопубликованные (?page, ?limit) |
| `PATCH` | `/v1/admin/novels/:id` | Редактировать (isPublished, title, description, tags) |
| `GET` | `/v1/admin/novels/:id/chapters` | Список глав новеллы (number, title, isReleased) |
| `PATCH` | `/v1/admin/novels/:id/chapters/:number` | Выпустить/скрыть главу (isReleased, releasedAt) |

---

## Примеры запросов

### Регистрация

```bash
curl -X POST http://localhost:3000/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "123456", "displayName": "Алиса"}'
```

### Вход

```bash
curl -X POST http://localhost:3000/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "123456"}'
```

### Вход через Google

```bash
curl -X POST http://localhost:3000/v1/auth/social \
  -H "Content-Type: application/json" \
  -d '{"provider": "google", "idToken": "eyJhbGci..."}'
```

### Загрузка новеллы

```bash
curl -X POST http://localhost:3000/v1/novels/upload \
  -F "file=@my_novel.zip"
```

> ZIP должен содержать `meta.json` с полями `id` и `title` **в корне архива** (не во вложенной папке).

### Синхронизация

```bash
# Сохранить прогресс
curl -X PUT http://localhost:3000/v1/sync/saves/demo_novel \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"data": {"novelId": "demo_novel", "chapterId": "chapter_1", "sceneId": "ch1_s3"}}'

# Получить все данные
curl http://localhost:3000/v1/sync/all \
  -H "Authorization: Bearer <token>"
```

---

## БД: модели Prisma

| Модель | Описание | Ключевые поля |
|--------|----------|---------------|
| **User** | Пользователь | email, passwordHash, displayName, role (user/admin) |
| **Novel** | Новелла | title, description, author, tags[], zipFilename, coverUrl, chaptersCount, releasedChapters, downloads, isPublished, version |
| **Chapter** | Глава новеллы | novelId, number, title, isReleased, releasedAt (@@unique: novelId + number) |
| **GameSave** | Сохранение игры | userId + novelId → JSON data |
| **UserProfileData** | Профиль | avatarIndex, statistics, unlockedCGs, achievements |
| **CurrencyData** | Валюта | diamonds (50 по умолчанию), tickets (5), lastTicketRefill |

Связи:
- User → GameSave (1:N)
- User → UserProfileData (1:1)
- User → CurrencyData (1:1)
- Novel → Chapter (1:N, onDelete: Cascade)
- При регистрации автоматически создаются Profile + Currency
- При загрузке ZIP автоматически создаются Chapter записи

---

## Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://amoria:amoria@localhost:5432/amoria` |
| `PORT` | Порт сервера | `3000` |
| `UPLOAD_DIR` | Папка для файлов | `./uploads` |
| `JWT_SECRET` | Секрет для JWT | `amoria-dev-secret-...` |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | — |
| `ADMIN_EMAIL` | Email админа (seed) | `admin@amoria.app` |
| `ADMIN_PASSWORD` | Пароль админа (seed) | `admin123` |
| `ALLOWED_ORIGINS` | CORS whitelist (comma-separated). Например: `http://localhost:5173,http://localhost:5174,https://admin.example.com`. Запросы без origin (Flutter mobile, curl) проходят всегда. | `http://localhost:5173,http://localhost:5174` |

---

## Скрипты

| Команда | Описание |
|---------|----------|
| `npm run dev` | Dev-сервер с hot-reload (`tsx watch`) |
| `npm run build` | Сборка TypeScript → `dist/` |
| `npm start` | Production-запуск (`node dist/`) |
| `npm run db:generate` | Генерация Prisma Client |
| `npm run db:migrate` | Миграция БД |
| `npm run db:push` | Push схемы без создания миграции |
| `npm run db:seed` | Заполнение тестовыми данными |

---

## Важные замечания

- Сервер слушает на `0.0.0.0` (не `localhost`) — это нужно для доступа с реальных устройств
- Для Android-эмулятора используй `10.0.2.2:3000` вместо `localhost:3000`
- Если порт 3000 занят: `lsof -ti :3000 | xargs kill -9`
- Максимальный размер ZIP: 500 МБ (настраивается в `middleware/upload.ts`)
