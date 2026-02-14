# Amoria Server

REST API для каталога и дистрибуции визуальных новелл.

## Стек
- Node.js + Express + TypeScript
- PostgreSQL + Prisma ORM
- Multer (загрузка файлов)

## Быстрый старт

### 1. PostgreSQL
```bash
docker compose up -d
```

### 2. Установка зависимостей
```bash
npm install
```

### 3. Миграция БД
```bash
npx prisma migrate dev --name init
npx prisma db seed
```

### 4. Запуск сервера
```bash
npm run dev
```

Сервер запустится на `http://localhost:3000`.

## API Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/health` | Health check |
| `GET` | `/v1/novels` | Каталог опубликованных новелл |
| `GET` | `/v1/novels/:id` | Детали одной новеллы |
| `GET` | `/v1/novels/:id/download` | Скачать ZIP-пак новеллы |
| `POST` | `/v1/novels/upload` | Загрузить новеллу (multipart, поле `file`) |
| `DELETE` | `/v1/novels/:id` | Удалить новеллу |

## Загрузка новеллы

ZIP-файл должен содержать `meta.json` с полями `id` и `title`:
```bash
curl -X POST http://localhost:3000/v1/novels/upload \
  -F "file=@my_novel.zip"
```
