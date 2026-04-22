# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор репозитория

Amoria — монорепозиторий из четырёх связанных подпроектов. Контент (новеллы) отделён от кода: движок интерпретирует JSON-файлы.

| Папка | Назначение | Стек |
|-------|------------|------|
| `client/` | Мобильное приложение-движок | Flutter 3.41 / Dart 3.11, Riverpod, Hive |
| `server/` | REST API каталога и дистрибуции | Node.js + Express + TS, Prisma, PostgreSQL |
| `admin/` | Веб-админка (управление новеллами, конфигом) | React 19 + Vite + Ant Design |
| `editor/` | Визуальный редактор новелл | React 19 + Vite + Zustand + @xyflow/react |
| `novels/`, `novel_prompts/`, `guides/` | Исходники новелл и промпты для ИИ-генерации | — |

Каждый подпроект имеет свой `README.md` с дополнительными подробностями; общий обзор — в корневом `README.md`.

## Команды разработки

### Сервер (`cd server`)
```bash
docker compose up -d                 # PostgreSQL 16 на :5432
npm run dev                          # tsx watch, hot-reload, :3000
npm run build && npm start           # прод-сборка
npm test                             # vitest (один прогон)
npx vitest run src/__tests__/social.test.ts   # одиночный тест
npx prisma migrate dev --name <name> # миграция
npx prisma db seed                   # tsx prisma/seed.ts (админ + демо-новеллы)
npx prisma studio                    # GUI для БД
```

### Flutter-клиент (`cd client`)
```bash
flutter pub get
flutter run                          # на устройстве/эмуляторе
flutter analyze                      # статический анализ
flutter test                         # все тесты
flutter test test/locale_test.dart   # одиночный тест-файл
dart run build_runner build --delete-conflicting-outputs   # регенерация *.g.dart (json_serializable)
```

### Admin / Editor (одинаковые скрипты)
```bash
npm run dev                          # vite (admin → :5174, editor → :5173)
npm run build                        # tsc -b && vite build
npm run lint                         # eslint .
```

## Архитектура: что нужно знать прежде, чем менять код

### Поток контента: три источника новелл
Клиент склеивает каталог новелл из трёх источников (приоритет сверху вниз) — см. `client/lib/services/novel_loader.dart` и `novel_api_service.dart`:
1. **Assets** — `client/assets/novels/<id>/`, перечисленные в `client/assets/novels/manifest.json` и `pubspec.yaml`.
2. **Скачанные** — `Documents/novels/<id>/` на устройстве (ZIP, распакованный после `GET /v1/novels/:id/download`).
3. **Каталог сервера** — `GET /v1/novels`.

При дублировании `id` побеждает первый найденный источник. Любое изменение, затрагивающее структуру файлов новеллы, должно работать во всех трёх источниках.

### Поглавная загрузка
Ключевое архитектурное решение (модель «Клуб Романтики»). ZIP новеллы содержит только *вышедшие* главы; новые главы подтягиваются отдельно как JSON-файлы (~5–50 КБ) через `GET /v1/novels/:id/chapters`. Флаги `isReleased` / `releasedAt` живут в таблице `Chapter` в Postgres и управляются из админки. При завершении главы N `SceneEngine` сам решает: автопереход / «скачать» / «скоро» / «конец истории». При добавлении фич, связанных с главами, следите за состоянием `ChapterTransition` в `client/lib/engine/scene_engine.dart`.

### Ядро движка
`client/lib/engine/`:
- `scene_engine.dart` — `SceneEngine` (StateNotifier) проигрывает сцены, обрабатывает события, применяет эффекты выборов, выполняет автосохранение, загружает главы и переводы.
- `variable_engine.dart` — применение эффектов выбора (`+1`, `-2`, `=value`) к игровым переменным.
- `condition_evaluator.dart` — проверка условий выбора (`>=`, `<=`, `==`, `!=`, `>`, `<`).

Типы событий (`dialogue`, `narration`, `choice`, `changeBackground`, `playSound`, `changeSprite`, `effect`, `showCg`, `cameraMove`, `showEmotion`) определены в `client/lib/models/scene.dart`. Модели сериализуются через `json_serializable` → при изменении моделей нужен `dart run build_runner build`.

### Локальное состояние (Hive)
Шесть Hive-боксов открываются в `client/lib/main.dart` ДО `runApp()`:
`game_saves`, `app_settings`, `app_locale`, `user_profile`, `currency`, `wardrobe`. Любая фича, читающая локальное состояние, должна полагаться на то, что эти боксы уже открыты. JWT-токен и VIP-статус хранятся как ключи внутри `app_settings`.

### Remote Config
`client/lib/services/remote_config_service.dart` подтягивает `GET /v1/config?v=<version>` (сервер возвращает `304`, если не изменилось), кеширует в Hive и используется с fallback'ом при офлайне. Fetch происходит ДО `runApp` в `main.dart` с таймаутом 5с. Экономика/реклама/VIP/IAP/daily/achievements/локализация — всё живёт в Postgres-таблице `GameConfig` (singleton-строка). Админка правит конфиг через `PUT /v1/admin/config`.

### Переводы новелл (гибрид Ren'Py + Naninovel)
Оригинал пишется на `sourceLanguage` из `meta.json`; переводы хранятся отдельно в `translations/<lang>.json`. Маппинг — по оригинальному тексту (ключ = исходная строка). `SceneEngine.tr()` прозрачно подставляет перевод; при его отсутствии fallback на оригинал. Таблица переводов загружается при старте новеллы через `NovelTranslation` (см. `client/lib/models/novel_translation.dart`). API: `GET|POST /v1/novels/:id/translations/:lang`, `GET /v1/novels/:id/languages`.

### Сервер: структура
`server/src/index.ts` монтирует пять роутеров под `/v1/*`: `auth`, `novels`, `sync`, `admin`, `config`. Middleware — `auth.ts` (JWT), `admin.ts` (проверка роли), `upload.ts` (Multer до 500 МБ). `utils/zip.ts` извлекает `meta.json`, обложку и главы из загруженного ZIP-файла. Обложки раздаются статически из `uploads/covers/`. Миграции и seed — в `server/prisma/`. Синхронизация (`routes/sync.ts`) использует стратегию "max для счётчиков, union для коллекций".

### Сеть: конфигурация адреса сервера
`client/lib/services/api_config.dart` определяет `baseUrl` через `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/v1')`. Дефолт `10.0.2.2` — это IP хост-машины с эмулятора Android, поэтому в типичном дев-сценарии (Android-эмулятор + локальный сервер на :3000) ничего настраивать не нужно. Для физических устройств, iOS-симулятора (`localhost`) или другого окружения адрес передаётся при запуске:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.112:3000/v1
flutter build apk --dart-define=API_BASE_URL=https://api.example.com/v1
```

Чтобы не повторять флаг — можно сохранить его в `--dart-define-from-file=env.json` (файл не коммитим). Менять `api_config.dart` для смены адреса больше не нужно.

## Важные особенности формата новелл

- `meta.json` должен лежать **в корне** ZIP-архива (не во вложенной папке), с обязательными полями `id` и `title`.
- Поле спрайта в `characters.json` называется `image`, а не `filename` — частая ошибка при генерации контента.
- Обязательные поля `Chapter`: `id`, `title`, `number` (int), `firstSceneId`, `scenes`.
- Спрайты ожидаются по пути `sprites/{characterId}/{имя}.png`; фоны — `backgrounds/{name}.png` (должны совпадать с полем `background` в сценах).
- Многослойные фоны (`backgroundLayers[]`) используют `depth: 0.0..1.0` — 0.0 — самый дальний (неподвижный).

## Что полезно помнить

- При изменении моделей в `client/lib/models/` (c `@JsonSerializable`) — запустите `dart run build_runner build --delete-conflicting-outputs`, иначе `*.g.dart` устареет.
- Prisma-клиент генерируется автоматически при `npm install` (postinstall), но после правок `schema.prisma` запустите `npm run db:generate` или `npx prisma migrate dev`.
- Roadmap и подробная история фич — в `ROADMAP.md`. Гайды по конкретным системам (ачивки, Remote Config, промпты) — в `guides/` и `novel_prompts/`.
- Тесты сервера — Vitest (`server/src/__tests__/`). Тесты клиента — стандартные `flutter_test` (`client/test/`). Юнит-тестов в admin/editor нет.
