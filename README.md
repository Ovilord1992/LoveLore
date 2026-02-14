# Amoria

Мобильное приложение-движок для интерактивных визуальных новелл (аналог «Клуб Романтики»).  
Одно приложение — множество новелл. Контент отделён от кода: каждая новелла описывается JSON-файлами, которые движок интерпретирует.

## Стек

| Компонент | Технологии |
|-----------|------------|
| **Мобильное приложение** | Flutter 3.41 · Dart 3.11 · Riverpod · Hive |
| **Сервер** | Node.js · Express · TypeScript · Prisma · PostgreSQL |
| **Редактор новелл** | React 18 · TypeScript · Vite · Zustand · @xyflow/react |

## Структура проекта

```
navell/
├── lib/                  # Flutter-приложение (движок, UI, сервисы)
│   ├── app/              # MaterialApp, тема
│   ├── engine/           # Ядро: SceneEngine, VariableEngine, ConditionEvaluator
│   ├── models/           # Модели: Novel, Scene, Character, GameState
│   ├── screens/          # Экраны: библиотека, игра, профиль, настройки, авторизация
│   ├── services/         # Сервисы: сохранения, валюта, профиль, API, авторизация, синхронизация
│   └── widgets/          # Виджеты: DialogueBox, ChoiceButtons, NovelCard
├── server/               # REST API сервер
│   ├── src/              # Express роуты, middleware, утилиты
│   └── prisma/           # Схема БД, миграции, seed
├── editor/               # Веб-редактор для авторов
│   └── src/              # React компоненты, Zustand стор
├── assets/novels/        # Демо-новелла «Тени Петербурга»
└── test/                 # Тесты
```

## Быстрый старт

### Мобильное приложение

```bash
flutter pub get
flutter run
```

### Сервер

```bash
cd server
docker compose up -d          # PostgreSQL
npm install
npx prisma migrate dev --name init
npm run dev                   # http://localhost:3000
```

### Редактор новелл

```bash
cd editor
npm install
npm run dev                   # http://localhost:5173
```

## Возможности

### Движок
- 📖 Проигрывание сцен с диалогами, нарративом и ветвлением
- 🎭 Персонажи со спрайтами, эмоциями и анимациями (fade_in/fade_out)
- 🔀 Система выборов с условиями (переменные, операторы сравнения)
- 💎 Премиум-выборы за алмазы
- 🎵 Фоновая музыка и звуковые эффекты
- 💾 Автосохранение и восстановление прогресса
- 🎬 Переходы между сценами (fade, slide, dissolve)

### Монетизация и геймплей
- 💎 Алмазы — внутриигровая валюта для премиум-выборов
- ⚡ Билеты (энергия) — 1 на главу, пополнение каждые 30 мин (макс. 5)
- 👗 Гардероб — смена одежды персонажей
- 🖼️ Галерея CG-артов
- 🏆 Система достижений

### Профиль и статистика
- 📊 Статистика: новеллы начаты/пройдены, главы прочитаны, выборы сделаны
- 🎨 Выбор аватара (8 вариантов)
- ✏️ Редактирование имени

### Авторизация и синхронизация
- 📧 Вход по email + пароль (JWT, 30 дней)
- 🔵 Вход через Google (OAuth2)
- 🍎 Вход через Apple (iOS/macOS)
- ☁️ Серверная синхронизация: сохранения, профиль, валюта
- 📱 Работает оффлайн — все данные в Hive, синхронизация при подключении

### Сервер
- 📚 Каталог новелл с метаданными, тегами, версионированием
- 📦 Загрузка/скачивание ZIP-паков новелл с прогрессом
- 📈 Счётчик загрузок
- 🔐 JWT авторизация + Google/Apple OAuth
- 💾 Серверные сохранения (saves, profile, currency)

### Редактор
- 🗺️ Визуальный граф сцен (drag & drop)
- ✏️ Редактор событий: диалоги, нарратив, выборы, премиум
- 👥 Управление персонажами, главами, переменными
- 📱 Превью сцены в мобильном фрейме
- ✅ Валидация сценария (BFS, битые ссылки)
- 📤 Экспорт в JSON / ZIP для Amoria
- 📥 Импорт проекта

### Локализация
- 🇷🇺 Русский
- 🇬🇧 Английский

## Как добавить новеллу

1. Создай папку `assets/novels/my_novel/`
2. Добавь `meta.json` (id, title, description, author, tags)
3. Добавь `characters.json`, `variables.json`
4. Создай `chapters/chapter_1.json`
5. Положи ассеты в `assets/backgrounds/`, `assets/characters/`, `assets/audio/`
6. Добавь id в `assets/novels/manifest.json`
7. Зарегистрируй ассеты в `pubspec.yaml`

Или используй **веб-редактор** → экспортируй ZIP → загрузи через API:
```bash
curl -X POST http://localhost:3000/v1/novels/upload -F "file=@my_novel.zip"
```

## Настройка Google Sign-In

1. Создай проект в [Google Cloud Console](https://console.cloud.google.com)
2. Включи Google Sign-In API
3. Создай OAuth 2.0 Client ID
4. Пропиши `GOOGLE_CLIENT_ID` в `server/.env`
5. Настрой `ios/Runner/Info.plist` и `android/app/src/main/res/values/strings.xml`

## Настройка Apple Sign-In

1. Включи Sign in with Apple в Apple Developer → Capabilities
2. Настрой Service ID в Apple Developer Console
3. Добавь capability в Xcode → Runner → Signing & Capabilities

## Переменные окружения (server/.env)

```env
DATABASE_URL=postgresql://amoria:amoria@localhost:5432/amoria?schema=public
PORT=3000
UPLOAD_DIR=./uploads
JWT_SECRET=your-secret-key
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
```

## Лицензия

Private project.
