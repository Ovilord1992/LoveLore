# Amoria Server

REST API для каталога, дистрибуции визуальных новелл, авторизации и синхронизации прогресса игроков.

## Стек

- **Node.js + Express + TypeScript** — REST API
- **PostgreSQL + Prisma ORM** — база данных
- **JWT** — авторизация (email/пароль + Google + Apple)
- **Multer** — загрузка файлов
- **bcryptjs** — хеширование паролей
- **google-auth-library** — верификация Google OAuth токенов

## Быстрый старт

### 1. PostgreSQL
```bash
docker compose up -d
```

### 2. Установка зависимостей
```bash
npm install
```

### 3. Настройка окружения
```bash
cp .env .env.local   # отредактируй при необходимости
```

### 4. Миграция БД
```bash
npx prisma migrate dev --name init
npx prisma db seed
```

### 5. Запуск сервера
```bash
npm run dev
```

Сервер запустится на `http://localhost:3000`.

## API Endpoints

### Health
| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/health` | Health check |

### Каталог новелл (публичный)
| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/v1/novels` | Каталог опубликованных новелл |
| `GET` | `/v1/novels/:id` | Детали одной новеллы |
| `GET` | `/v1/novels/:id/download` | Скачать ZIP-пак новеллы |
| `POST` | `/v1/novels/upload` | Загрузить новеллу (multipart, поле `file`) |
| `DELETE` | `/v1/novels/:id` | Удалить новеллу |

### Авторизация
| Метод | Путь | Описание |
|-------|------|----------|
| `POST` | `/v1/auth/register` | Регистрация (email + пароль) |
| `POST` | `/v1/auth/login` | Вход (email + пароль → JWT) |
| `POST` | `/v1/auth/social` | Вход через Google / Apple (idToken → JWT) |
| `GET` | `/v1/auth/me` | Текущий пользователь 🔒 |

### Синхронизация (требует JWT) 🔒
| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/v1/sync/saves` | Все сохранения пользователя |
| `GET` | `/v1/sync/saves/:novelId` | Сохранение конкретной новеллы |
| `PUT` | `/v1/sync/saves/:novelId` | Сохранить/обновить прогресс |
| `DELETE` | `/v1/sync/saves/:novelId` | Удалить сохранение |
| `GET` | `/v1/sync/profile` | Получить профиль |
| `PUT` | `/v1/sync/profile` | Обновить профиль |
| `GET` | `/v1/sync/currency` | Получить валюту (алмазы, билеты) |
| `PUT` | `/v1/sync/currency` | Обновить валюту |
| `GET` | `/v1/sync/all` | Получить все данные пользователя |

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

ZIP должен содержать `meta.json` с полями `id` и `title`.

### Синхронизация сохранения
```bash
# Сохранить прогресс
curl -X PUT http://localhost:3000/v1/sync/saves/demo_novel \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"data": {"novelId": "demo_novel", "chapterId": "ch1", ...}}'

# Получить все данные
curl http://localhost:3000/v1/sync/all \
  -H "Authorization: Bearer <token>"
```

## БД: модели Prisma

- **User** — пользователь (email, passwordHash, displayName)
- **Novel** — новелла (title, description, tags, version, zipFilename, downloads)
- **GameSave** — сохранение игры (userId + novelId → JSON data)
- **UserProfileData** — профиль (статистика, достижения, CG)
- **CurrencyData** — валюта (алмазы, билеты, lastTicketRefill)

## Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://amoria:amoria@localhost:5432/amoria` |
| `PORT` | Порт сервера | `3000` |
| `UPLOAD_DIR` | Папка для ZIP-файлов | `./uploads` |
| `JWT_SECRET` | Секрет для JWT токенов | `amoria-dev-secret-...` |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | — |

## Скрипты

| Команда | Описание |
|---------|----------|
| `npm run dev` | Запуск с hot-reload (tsx watch) |
| `npm run build` | Сборка TypeScript → dist/ |
| `npm start` | Запуск production (node dist/) |
| `npm run db:generate` | Генерация Prisma Client |
| `npm run db:migrate` | Миграция БД |
| `npm run db:push` | Push схемы без миграции |
| `npm run db:seed` | Заполнение тестовыми данными |
