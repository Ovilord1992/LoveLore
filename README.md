# Amoria

Мобильное приложение-движок для интерактивных визуальных новелл (аналог «Клуб Романтики»).  
Одно приложение — множество новелл. Контент отделён от кода: каждая новелла описывается JSON-файлами, которые движок интерпретирует.

## Стек

| Компонент | Технологии |
|-----------|------------|
| **Мобильное приложение** | Flutter 3.41 · Dart 3.11 · Riverpod · Hive |
| **Сервер** | Node.js · Express · TypeScript · Prisma · PostgreSQL |
| **Редактор новелл** | React 18 · TypeScript · Vite · Zustand · @xyflow/react |
| **Админ-панель** | React 18 · TypeScript · Vite · Ant Design |

---

## Структура проекта

```
navell/
├── client/                   # Flutter-приложение (движок новелл)
│   ├── lib/                  # Исходный код
│   │   ├── app/              # MaterialApp, тема, роутинг
│   │   ├── engine/           # Ядро: SceneEngine, VariableEngine, ConditionEvaluator
│   │   ├── models/           # Модели: Novel, Scene, Character, GameState, NovelTranslation
│   │   ├── screens/          # Экраны: библиотека, игра, профиль, настройки, авторизация
│   │   ├── services/         # Сервисы: сохранения, валюта, профиль, API, авторизация
│   │   └── widgets/          # Виджеты: DialogueBox, ChoiceButtons, NovelCard, SceneEffectOverlay, CgOverlay, EmotionBubble, ParallaxBackground
│   ├── assets/               # Ассеты мобильного приложения
│   │   ├── novels/           # Встроенные новеллы (JSON + manifest)
│   │   ├── backgrounds/      # Фоны сцен
│   │   ├── characters/       # Спрайты персонажей
│   │   └── audio/            # Музыка и звуковые эффекты
│   ├── android/              # Android-проект
│   ├── ios/                  # iOS-проект
│   ├── test/                 # Тесты
│   └── pubspec.yaml          # Зависимости Flutter
├── server/                   # REST API сервер (→ см. server/README.md)
│   ├── src/                  # Express роуты, middleware, утилиты
│   ├── prisma/               # Схема БД, миграции, seed
│   └── uploads/              # Загруженные ZIP-паки и обложки
├── admin/                    # Веб-админка (→ см. admin/README.md)
│   └── src/                  # React + Ant Design
├── editor/                   # Веб-редактор для авторов (→ см. editor/README.md)
│   └── src/                  # React + Zustand + @xyflow/react
├── AI_PROMPTS.md             # Промпты для ИИ-генерации контента
└── ROADMAP.md                # Дорожная карта разработки
```

---

## Развёртывание проекта (полное)

### Требования

- **Flutter SDK** ≥ 3.41 (Dart ≥ 3.11)
- **Node.js** ≥ 18
- **Docker** (для PostgreSQL)
- **Git**

### 1. Клонирование

```bash
git clone <repo-url> navell
cd navell
```

### 2. Сервер

```bash
cd server
docker compose up -d              # Поднимает PostgreSQL на порту 5432
npm install
cp .env .env.local                # Отредактируй при необходимости
npx prisma migrate dev --name init
npx prisma db seed                # Создаёт админа + демо-новеллы
npm run dev                       # http://localhost:3000
```

Проверка: `curl http://localhost:3000/health` → `{"status":"ok","version":"1.0.0"}`

### 3. Мобильное приложение

```bash
cd client
flutter pub get
flutter run                       # Запуск на подключённом устройстве/эмуляторе
```

> **Важно:** Для работы с сервером с реального устройства измени IP в  
> `client/lib/services/api_config.dart` на IP своей машины в локальной сети.  
> Эмулятор Android: используй `10.0.2.2` вместо `localhost`.

### 4. Админ-панель

```bash
cd admin
npm install
npm run dev                       # http://localhost:5174
```

Логин по умолчанию: `admin@amoria.app` / `admin123`

### 5. Редактор новелл

```bash
cd editor
npm install
npm run dev                       # http://localhost:5173
```

---

## Как работает приложение

### Три источника новелл

Приложение загружает новеллы из трёх мест (в порядке приоритета):

1. **Встроенные assets** — новеллы из `client/assets/novels/`, прописанные в `manifest.json` и `pubspec.yaml`. Доступны офлайн сразу.
2. **Скачанные файлы** — новеллы, загруженные с сервера. Хранятся в `Documents/novels/<novelId>/` на устройстве.
3. **Каталог сервера** — `GET /v1/novels`. Новеллы, которых нет локально, показываются с кнопкой «Скачать».

При дублировании `id` — побеждает первый найденный источник.

### Поток загрузки серверной новеллы

```
Игрок нажимает «Начать историю»
  → Приложение проверяет: есть ли файлы локально?
  → Нет → Скачивает ZIP с сервера (GET /v1/novels/:id/download)
  → Распаковывает в Documents/novels/<novelId>/
  → Открывает игровой экран
```

### Поглавная загрузка

Модель «живого контента» (как в «Клуб Романтики»): новеллы выходят по главам.

- Основной ZIP содержит спрайты, фоны, обложку + все текущие главы
- Новые главы загружаются отдельно (только JSON сценария, ~5–50 КБ)
- Сервер управляет флагами `isReleased` и `releasedAt` для каждой главы
- Админ может запланировать выход главы заранее

```
Игрок завершает главу N
  → SceneEngine проверяет: есть ли chapter_{N+1}.json локально?
  → Да → Автоматически загружает следующую главу
  → Нет → Запрос к серверу: GET /v1/novels/:id/chapters
  → Глава вышла → Показывает «Скачать главу N+1» → Загрузка JSON
  → Глава не вышла → Показывает «Продолжение следует — скоро!»
  → Глав больше нет → Показывает «Конец истории»
```

### Загрузка изображений

Изображения загружаются из разных источников в зависимости от типа новеллы:

| Источник | Как загружается | Виджеты |
|----------|-----------------|---------|
| **Встроенная** (asset) | `Image.asset()` из `assets/` | AnimatedBackground, AnimatedCharacterSprite |
| **Скачанная** (файл) | `Image.file()` из `Documents/novels/<id>/` | AnimatedBackground, AnimatedCharacterSprite |
| **Обложка с сервера** | `Image.network()` из `http://server/covers/` | NovelCoverImage |

`NovelCoverImage` — умный виджет, который автоматически выбирает источник: файл → asset → сервер → плейсхолдер.

### Локальное хранилище (Hive)

Все данные хранятся в 6 Hive-боксах (инициализируются в `main.dart`):

| Бокс | Данные |
|------|--------|
| `game_saves` | Сохранения игры (JSON по novelId) |
| `app_settings` | Настройки (громкость, скорость текста) |
| `app_locale` | Язык интерфейса |
| `user_profile` | Профиль (аватар, статистика, достижения) |
| `currency` | Валюта (алмазы, билеты, время последнего пополнения) |
| `wardrobe` | Купленные предметы одежды |

### Синхронизация с сервером

При наличии авторизации данные можно синхронизировать:
- **Push** — отправка локальных данных на сервер (`PUT /v1/sync/*`)
- **Pull** — получение серверных данных (`GET /v1/sync/all`)
- **Мерж** — при конфликтах: max для статистики, union для коллекций

---

## Формат данных новеллы

Каждая новелла — это набор JSON-файлов + ассеты:

```
my_novel/
├── meta.json              # Метаданные новеллы
├── characters.json        # Персонажи и спрайты
├── variables.json         # Начальные переменные (опционально)
├── chapters/
│   ├── chapter_1.json     # Глава 1 (сцены, диалоги, выборы)
│   └── chapter_2.json     # Глава 2
├── backgrounds/           # Фоновые изображения
├── sprites/               # Спрайты персонажей (по подпапкам: sprites/alex/)
├── cg/                    # CG-арты (галерея)
└── audio/                 # Музыка и звуки
```

### meta.json

```json
{
  "id": "my_novel",
  "title": "Название новеллы",
  "description": "Описание сюжета",
  "author": "Имя автора",
  "tags": ["романтика", "мистика"],
  "chaptersCount": 2,
  "coverImage": "assets/novels/my_novel/cover.png"
}
```

### characters.json

```json
{
  "characters": [
    {
      "id": "alex",
      "name": "Александр",
      "color": "#E91E63",
      "sprites": [
        { "id": "neutral", "image": "alex_neutral.png", "label": "Спокойный" },
        { "id": "smile", "image": "alex_smile.png", "label": "Улыбка" },
        { "id": "serious", "image": "alex_serious.png", "label": "Серьёзный" }
      ]
    }
  ]
}
```

> **Важно:** поле спрайта — `image` (не `filename`). Это частая ошибка при создании контента.

### Глава (chapter_1.json)

```json
{
  "id": "chapter_1",
  "title": "Глава 1: Незнакомец",
  "number": 1,
  "firstSceneId": "ch1_s1",
  "scenes": [
    {
      "id": "ch1_s1",
      "background": "city_night.png",
      "music": "mysterious.mp3",
      "charactersOnScreen": [
        { "characterId": "alex", "spriteId": "neutral", "position": "center", "animation": "fade_in" }
      ],
      "events": [
        { "type": "narration", "text": "Дождливый вечер в Петербурге..." },
        { "type": "dialogue", "speaker": "alex", "text": "Мы раньше не встречались?" },
        {
          "type": "choice",
          "choices": [
            {
              "text": "Кажется, нет",
              "effects": { "alex_love": "+1" },
              "nextSceneId": "ch1_s2"
            },
            {
              "text": "💎 Улыбнуться загадочно",
              "premium": true,
              "cost": 10,
              "effects": { "alex_love": "+3" },
              "nextSceneId": "ch1_s2_premium"
            }
          ]
        }
      ]
    }
  ]
}
```

> **Обязательные поля главы:** `id`, `title`, `number` (int), `firstSceneId`, `scenes`.

### Типы событий (EventType)

| Тип | Описание | Поля |
|-----|----------|------|
| `dialogue` | Реплика персонажа | `speaker`, `text` |
| `narration` | Описание / мысли | `text` |
| `choice` | Выбор игрока | `choices[]` (text, effects, nextSceneId, condition, premium, cost), `timeLimit?`, `defaultChoiceIndex?` |
| `changeBackground` | Смена фона | `background` |
| `playSound` | Звуковой эффект | `sound` |
| `changeSprite` | Смена спрайта персонажа | `characterId`, `spriteId`, `spriteDuration?` (cross-fade мс) |
| `effect` | Визуальный эффект | `effectType` (shake/flash/fadeToBlack/rain/snow/particles), `effectDuration`, `effectIntensity` |
| `showCg` | CG-арт (полноэкранная иллюстрация) | `cgImage`, `cgTransition` (fade/zoomIn), `cgDuration` |
| `cameraMove` | Движение камеры | `zoom` (0.5–2.0), `panX`, `panY`, `cameraDuration` |
| `showEmotion` | Эмоция-иконка над персонажем | `characterId`, `emotionType` (heart/sweatDrop/question/exclamation/anger/sparkle/musicNote/zzz) |

#### Анимации и эффекты

Каждая сцена поддерживает:

- **Переходы между сценами** — `transition` в объекте Scene: fade, slideLeft, slideRight, slideUp, slideDown (+ настраиваемая длительность)
- **Визуальные эффекты** — тряска экрана, вспышка, затемнение, дождь, снег, частицы
- **Анимации персонажей** — fade_in, fade_out, slide_in_left, slide_in_right, bounce, shake
- **CG-арт** — полноэкранные иллюстрации с переходами fade/zoomIn, разблокируются в галерее
- **Камера** — zoom и pan по фону с плавной анимацией
- **Эмоции** — 8 типов emoji-иконок, всплывающих над головой персонажа
- **Cross-fade спрайтов** — плавная смена выражений с настраиваемой длительностью
- **Таймер на выбор** — обратный отсчёт с круговым прогресс-баром и авто-выбором
- **Параллакс фонов** — многослойные фоны с разной глубиной для эффекта объёма

#### Многослойные фоны (backgroundLayers)

```json
{
  "backgroundLayers": [
    { "image": "bg_sky.png", "depth": 0.0 },
    { "image": "bg_mountains.png", "depth": 0.3 },
    { "image": "bg_trees.png", "depth": 0.7 },
    { "image": "bg_ground.png", "depth": 1.0 }
  ]
}
```

Слой с `depth: 0.0` — самый дальний (неподвижный), `depth: 1.0` — ближний (двигается быстрее всего).

### Условия (conditions)

Выбор можно показывать только при выполнении условия:
```json
{
  "text": "Признаться в чувствах",
  "condition": { "variable": "alex_love", "operator": ">=", "value": 5 },
  "nextSceneId": "ch1_confession"
}
```

Поддерживаемые операторы: `>=`, `<=`, `==`, `!=`, `>`, `<`

---

## Как добавить новеллу

### Способ 1: Встроенная (в assets)

1. Создай папку `client/assets/novels/my_novel/`
2. Добавь `meta.json`, `characters.json`, `variables.json`
3. Создай `chapters/chapter_1.json`
4. Положи ассеты в `client/assets/backgrounds/`, `client/assets/characters/`, `client/assets/audio/`
5. Добавь id в `client/assets/novels/manifest.json`:
   ```json
   { "novels": ["demo_novel", "my_novel"] }
   ```
6. Зарегистрируй ассеты в `client/pubspec.yaml` (секция `flutter.assets`)
7. Пересобери приложение (`flutter run`)

### Способ 2: Через редактор → сервер

1. Открой веб-редактор (`http://localhost:5173`)
2. Создай проект, добавь персонажей, главы, сцены
3. Экспортируй в ZIP
4. Загрузи через админку (`http://localhost:5174` → Новеллы → Загрузить ZIP)
5. Новелла появится в каталоге приложения (без пересборки)

### Способ 3: ZIP через API

```bash
curl -X POST http://localhost:3000/v1/novels/upload \
  -H "Authorization: Bearer <admin-token>" \
  -F "file=@my_novel.zip"
```

ZIP должен содержать `meta.json` с полями `id` и `title` в корне архива.

### Требования к ZIP

```
my_novel.zip
├── meta.json              # ОБЯЗАТЕЛЬНО: id + title
├── characters.json
├── variables.json         # Начальные переменные (опционально)
├── cover.png              # Обложка (извлекается автоматически)
├── chapters/
│   ├── chapter_1.json
│   └── chapter_2.json
├── backgrounds/           # Фоновые изображения сцен
│   ├── city_night.png
│   └── park_day.png
├── sprites/               # Спрайты персонажей
│   ├── alex/
│   │   ├── alex_neutral.png
│   │   └── alex_smile.png
│   └── maria/
│       └── maria_neutral.png
└── cg/                    # CG-арты (галерея)
    └── cover.png
```

> `meta.json` должен быть **в корне** архива, а не внутри вложенной папки.  
> Спрайты: `sprites/{characterId}/{characterId}_{emotion}.png`.  
> Фоны: `backgrounds/{name}.png` — должны совпадать с полем `background` в сценах.

---

## Серверное хранилище

Когда новелла загружается через API или админку:

| Что | Куда сохраняется |
|-----|------------------|
| ZIP-файл | `server/uploads/packs/<uuid>.zip` |
| Обложка | `server/uploads/covers/<novelId>.png` |
| Метаданные | PostgreSQL, таблица `Novel` |
| Главы | PostgreSQL, таблица `Chapter` (number, title, isReleased, releasedAt) |
| Статистика (загрузки) | PostgreSQL, поле `downloads` |

При загрузке ZIP сервер автоматически:
- Извлекает `meta.json` → создаёт/обновляет запись `Novel`
- Извлекает обложку (`cover.png/jpg` или `cg/cover.png`) → `uploads/covers/<novelId>.ext`
- Сканирует `chapters/` → создаёт записи `Chapter` в БД (с `isReleased: true`)

Обложки раздаются статически: `http://localhost:3000/covers/<novelId>.png`

---

## Клиентское хранилище (на устройстве)

| Что | Где на устройстве |
|-----|-------------------|
| Скачанные новеллы | `Documents/novels/<novelId>/` |
| Отдельные главы | `Documents/novels/<novelId>/chapters/chapter_N.json` |
| Фоны и спрайты | `Documents/novels/<novelId>/backgrounds/`, `sprites/` |
| Сохранения | Hive box `game_saves` |
| Профиль | Hive box `user_profile` |
| Валюта | Hive box `currency` |
| Настройки | Hive box `app_settings` |
| JWT токен | Hive box `app_settings` (ключ `auth_token`) |
| VIP-статус | Hive box `app_settings` (ключ `vip_state`) |

---

## Монетизация

### Архитектура

```
Игрок
  ├── Бесплатный путь
  │   ├── Rewarded Ads → +3💎 или +1🎫 (макс 5/день)
  │   ├── Таймер билетов → +1🎫 каждые 30 мин (макс 5)
  │   ├── Ежедневные награды → 7-дневный цикл (5💎 → 1⚡ → ... → 30💎)
  │   └── Стартовый бонус → 50💎
  │
  ├── In-App Purchases (consumable)
  │   ├── 20💎 → $0.99
  │   ├── 60💎 → $2.99 (популярный)
  │   ├── 150💎 → $5.99
  │   ├── 500💎 → $14.99
  │   ├── 5🎫 → $0.99
  │   └── 🎁 Стартовый бандл → 100💎 + 10🎫 за $0.99 (разовый)
  │
  └── VIP-подписка → $4.99/мес (auto-renewable subscription)
      ├── +5💎 ежедневно
      ├── Безлимитные билеты
      ├── Ранний доступ к главам
      ├── Без рекламы
      └── Эксклюзивная рамка профиля
```

### Сервисы

| Сервис | Файл | Описание |
|--------|------|----------|
| `AdService` | `ad_service.dart` | Google Mobile Ads, rewarded видео, лимит/день |
| `IapService` | `iap_service.dart` | In-App Purchase, consumables + subscriptions |
| `VipService` | `vip_service.dart` | VIP-статус, ежедневные алмазы, безлимит билетов |
| `CurrencyService` | `currency_service.dart` | Алмазы + билеты, рефилл, Hive-персистенция |
| `DailyRewardService` | `daily_reward_service.dart` | Ежедневные награды, 7-дневный цикл, серия |
| `RemoteConfigService` | `remote_config_service.dart` | Серверная конфигурация, кеш в Hive, fallback |

### Настройка перед релизом

1. **AdMob:** заменить тестовые `ca-app-pub-3940256099942544~*` на боевые ID
   - Android: `client/android/app/src/main/AndroidManifest.xml`
   - iOS: `client/ios/Runner/Info.plist` (`GADApplicationIdentifier`)
2. **IAP:** создать продукты в App Store Connect / Google Play Console с ID из `ProductIds`
3. **VIP:** настроить auto-renewable subscription в обоих сторах

### Remote Config — серверная конфигурация

Все параметры игры управляются с сервера через админ-панель (`#/config`).
Клиент загружает конфиг при старте, кеширует в Hive, при оффлайне использует кеш/defaults.

**API:**
- `GET /v1/config?v=<version>` — весь конфиг (304 если не изменился)
- `GET /v1/admin/config` — для админки
- `PUT /v1/admin/config` — обновить одну или несколько секций

**Вкладки в админке:**

#### 💰 Экономика (формы)
Управляет балансом энергии и стартовыми ресурсами.
```json
{
  "maxTickets": 5,
  "ticketRefillMinutes": 30,
  "startDiamonds": 50,
  "startTickets": 5,
  "diamondCostPerTicket": 10
}
```
- `maxTickets` — максимальное кол-во билетов (энергии)
- `ticketRefillMinutes` — одна ⚡ восстанавливается раз в N минут
- `startDiamonds` / `startTickets` — стартовый баланс нового игрока
- `diamondCostPerTicket` — цена покупки билета за алмазы

#### 📺 Реклама (формы)
Настройки rewarded-рекламы.
```json
{
  "maxAdsPerDay": 5,
  "diamondReward": 3,
  "ticketReward": 1
}
```
- `maxAdsPerDay` — сколько раз в день можно смотреть рекламу
- `diamondReward` — алмазы за один просмотр
- `ticketReward` — билеты за просмотр (в game_screen)

#### 👑 VIP (формы)
Привилегии подписчиков.
```json
{
  "dailyDiamonds": 5,
  "unlimitedTickets": true,
  "earlyAccess": true,
  "noAds": true,
  "exclusiveFrame": true
}
```

#### 🛒 IAP (JSON)
Маппинг product ID → награды. Ключи должны совпадать с `ProductIds` в коде.
```json
{
  "diamonds_20":    { "diamonds": 20 },
  "diamonds_60":    { "diamonds": 60 },
  "diamonds_150":   { "diamonds": 150 },
  "diamonds_500":   { "diamonds": 500 },
  "tickets_5":      { "tickets": 5 },
  "starter_bundle": { "diamonds": 100, "tickets": 10 }
}
```

#### 🎁 Daily (JSON)
Массив наград по дням (7-дневный цикл). Каждый элемент:
```json
[
  { "day": 1, "diamonds": 5,  "tickets": 0, "label": "5 💎" },
  { "day": 2, "diamonds": 0,  "tickets": 1, "label": "1 ⚡" },
  { "day": 3, "diamonds": 10, "tickets": 0, "label": "10 💎" },
  { "day": 4, "diamonds": 0,  "tickets": 2, "label": "2 ⚡" },
  { "day": 5, "diamonds": 15, "tickets": 0, "label": "15 💎" },
  { "day": 6, "diamonds": 0,  "tickets": 3, "label": "3 ⚡" },
  { "day": 7, "diamonds": 30, "tickets": 0, "label": "30 💎" }
]
```
- `day` — номер дня в цикле
- `diamonds` / `tickets` — награда
- `label` — текст в UI ячейке

#### 🏆 Достижения (JSON)
Массив из 102 достижений с категориями, редкостью и триггерами:
```json
[
  {
    "id": "first_story",
    "category": "story",
    "rarity": "common",
    "icon": "auto_stories",
    "diamondReward": 10,
    "hidden": false,
    "trigger": "novels_started",
    "targetValue": 1
  },
  {
    "id": "speed_reader_5",
    "category": "speed",
    "rarity": "rare",
    "icon": "speed",
    "diamondReward": 25,
    "hidden": false,
    "trigger": "chapters_read",
    "targetValue": 5
  }
]
```
- `id` — уникальный идентификатор
- `category` — категория: story, chapters, relationships, cg, economy, daily, vip, exploration, secret
- `rarity` — редкость: common / rare / epic / legendary
- `icon` — имя Material Icon (53 уникальные иконки, фоллбэк на `emoji_events`)
- `diamondReward` — награда за разблокировку
- `hidden` — скрытое достижение (показывает «???» до разблокировки)
- `trigger` — событие-триггер (novels_started, chapters_read, choices_made, cg_unlocked, diamonds_spent и др.)
- `targetValue` — целевое значение для разблокировки

Заголовки и описания берутся из локализации по ключам `ach_{id}_title` / `ach_{id}_desc`.

#### 🌍 Локализация (JSON)
Словари строк по языкам:
```json
{
  "ru": {
    "app_title": "Amoria",
    "tab_home": "Главная",
    "tab_catalog": "Каталог",
    "btn_play": "Начать историю",
    "btn_continue": "Продолжить",
    "no_tickets_title": "Нет билетов",
    "daily_title": "Ежедневная награда",
    "daily_claim": "Забрать награду!"
  },
  "en": {
    "app_title": "Amoria",
    "tab_home": "Home",
    "tab_catalog": "Catalog",
    "btn_play": "Start Story",
    "btn_continue": "Continue",
    "no_tickets_title": "No Tickets",
    "daily_title": "Daily Reward",
    "daily_claim": "Claim Reward!"
  }
}
```
Можно добавлять новые языки (например `"de"`, `"fr"`) без перевыпуска.

#### 📚 Локализация книг (контент)

Помимо интерфейса, переводится и содержание книг — диалоги, нарратив, выборы, имена персонажей и названия глав.

**Архитектура:** гибрид Ren'Py + Naninovel — автор пишет на одном языке, переводы хранятся отдельно.

**Структура в ZIP:**
```
novel_id.zip/
├── meta.json                   # sourceLanguage: "ru"
├── chapters/                   # оригинальные тексты
├── translations/
│   ├── en.json                 # английский перевод
│   ├── es.json                 # испанский
│   └── fr.json                 # французский
└── ...
```

**Формат файла перевода** (`translations/en.json`):
```json
{
  "meta": {
    "language": "en",
    "sourceLanguage": "ru",
    "novelId": "forgotten_gods",
    "version": 1
  },
  "novel": {
    "title": "Forgotten Gods",
    "description": "An ancient temple hides a secret..."
  },
  "characters": {
    "lera": { "name": "Lera" },
    "mysterious_stranger": { "name": "Mysterious Stranger" }
  },
  "chapters": {
    "chapter_1": { "title": "Chapter 1: Awakening" }
  },
  "texts": {
    "Привет! Как твои дела?": "Hey! How are you doing?",
    "Пойти в парк": "Go to the park",
    "Остаться дома": "Stay at home"
  }
}
```

**Как добавить перевод:**
1. **Через редактор** — вкладка 🌍 (Переводы) в сайдбаре: выбрать язык, перевести все тексты, экспортировать ZIP
2. **Через админку** — кнопка 🌐 на строке новеллы: вставить JSON перевода и загрузить на сервер
3. **Через API** — `POST /v1/novels/:id/translations/:lang` с JSON-телом

**API:**
| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/v1/novels/:id/languages` | Список доступных языков |
| GET | `/v1/novels/:id/translations/:lang` | Скачать перевод |
| POST | `/v1/novels/:id/translations/:lang` | Загрузить перевод |

**Как работает на клиенте:**
- При запуске новеллы движок загружает перевод по текущему языку интерфейса
- Все диалоги, нарратив и выборы автоматически подставляются из перевода
- Имена персонажей переводятся отдельно (могут отличаться по культурам)
- Если перевода нет — показывается оригинальный текст (fallback)

---

## Возможности

### Движок
- 📖 Проигрывание сцен с диалогами, нарративом и ветвлением
- 🎭 Персонажи со спрайтами, эмоциями и анимациями (fade_in/fade_out)
- 🔀 Система выборов с условиями (переменные, операторы сравнения)
- 💎 Премиум-выборы за алмазы
- 🎵 Фоновая музыка и звуковые эффекты
- 💾 Автосохранение и восстановление прогресса
- 🎬 Переходы между сценами (fade, slide, dissolve)
- 📥 Поглавная загрузка: автопереход, скачивание новых глав, «скоро» / «конец»
- 🖼️ Загрузка изображений из файлов, ассетов и сервера (NovelCoverImage, AnimatedBackground)
- 🌍 Локализация книг — автоматическая подстановка переводов диалогов, нарратива и выборов

### Монетизация и геймплей
- 💎 Алмазы — внутриигровая валюта для премиум-выборов (начальный баланс: 50)
- ⚡ Билеты (энергия) — 1 на главу, пополнение каждые 30 мин (макс. 5)
- 📺 Rewarded Ads — реклама за алмазы (+3💎) и билеты (+1🎫), лимит 5/день
- 🛒 Магазин (ShopScreen) — покупка алмазов, билетов, стартовый бандл
- 🎁 Стартовый бандл — 100💎 + 10🎫 за $0.99 (разовый, x10 ценность)
- ⭐ VIP-подписка ($4.99/мес) — +5💎/день, безлимит билетов, ранний доступ, без рекламы
- 🎁 Ежедневные награды (Daily Login) — 7-дневный цикл, серия с нарастающими бонусами
- 👗 Гардероб — смена одежды персонажей
- 🖼️ Галерея CG-артов
- 🏆 Система достижений (102 достижения, 9 категорий, 4 уровня редкости, скрытые достижения)

### Иммерсивный режим
- 🎬 Автоскрытие верхней панели — чистый кинематографический вид
- 💬 Хвостик речевого пузыря — SVG-path, направлен к говорящему персонажу
- 🎭 Имя говорящего со стороны персонажа

### Авторизация и синхронизация
- 📧 Вход по email + пароль (JWT, 30 дней)
- 🔵 Вход через Google (OAuth2)
- 🍎 Вход через Apple (iOS/macOS)
- ☁️ Серверная синхронизация: сохранения, профиль, валюта
- 📱 Работает оффлайн — все данные в Hive, синхронизация при подключении

### UI
- 🏠 Главная: баннер-карусель, «Продолжить чтение», горизонтальная лента
- ➕ Бейджи валюты с кнопкой «+» → быстрый переход в магазин
- ⏱️ Таймер восстановления билетов (MM:SS) рядом с ⚡
- 🎁 Ежедневные награды (Daily Login) — popup при запуске, 7-дневный цикл
- 🏷️ Промо-баннер спецпредложения на главном экране (скрывается после покупки)
- 📚 Каталог: полный вертикальный список новелл
- 👤 Профиль: аватар, статистика, настройки, аккаунт
- 🔽 Нижняя навигация: Главная / Каталог / Профиль
- 🌙 Тёмная тема (розово-фиолетовая палитра)
- 🌍 11 языков интерфейса (ru, en, it, fr, de, es, pt, tr, ja, ko, zh)

---

## Настройка OAuth

### Google Sign-In

1. Создай проект в [Google Cloud Console](https://console.cloud.google.com)
2. Включи Google Sign-In API
3. Создай OAuth 2.0 Client ID (Web + Android + iOS)
4. Пропиши `GOOGLE_CLIENT_ID` в `server/.env`
5. Настрой `client/ios/Runner/Info.plist` и `client/android/app/src/main/res/values/strings.xml`

### Apple Sign-In

1. Включи Sign in with Apple в Apple Developer → Capabilities
2. Настрой Service ID в Apple Developer Console
3. Добавь capability в Xcode → Runner → Signing & Capabilities

---

## Переменные окружения (server/.env)

```env
DATABASE_URL=postgresql://amoria:amoria@localhost:5432/amoria?schema=public
PORT=3000
UPLOAD_DIR=./uploads
JWT_SECRET=your-secret-key-change-in-production
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
ADMIN_EMAIL=admin@amoria.app
ADMIN_PASSWORD=admin123
```

---

## Полезные команды

### Flutter

```bash
cd client
flutter pub get                          # Установка зависимостей
flutter run                              # Запуск на устройстве
flutter run --release                    # Release-сборка
flutter build apk                        # APK для Android
flutter build ios                        # Сборка для iOS
dart run build_runner build              # Кодогенерация (json_serializable)
flutter analyze                          # Анализ кода
```

### Сервер

```bash
cd server
npm run dev                              # Dev-сервер с hot-reload
npm run build && npm start               # Production-сборка
npx prisma studio                        # Визуальный интерфейс БД
npx prisma migrate dev --name <name>     # Создать миграцию
npx prisma db seed                       # Заполнить тестовыми данными
docker compose up -d                     # Запустить PostgreSQL
docker compose down                      # Остановить PostgreSQL
```

### Админка и редактор

```bash
cd admin && npm run dev                  # Админ-панель на :5174
cd editor && npm run dev                 # Редактор на :5173
```

---

## Лицензия

Private project.
