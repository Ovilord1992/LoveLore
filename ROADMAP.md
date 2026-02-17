# Amoria — Полный план разработки

## Описание проекта
**Amoria** — мобильное приложение-движок для интерактивных визуальных новелл (аналог "Клуб Романтики").
Одно приложение, множество новелл. Контент отделён от кода — каждая новелла описывается JSON-файлами,
которые движок интерпретирует. Целевая аудитория — женщины и девушки.

**Стек:** Flutter + Riverpod + Hive + json_serializable  
**Платформы:** iOS, Android

---

## Архитектура

### Принцип: Data-Driven Engine
- **Движок** — Flutter-приложение, интерпретирует новеллы из структурированных JSON-данных
- **Новеллы** — JSON файлы + ассеты (изображения, музыка), загружаются из assets или с сервера
- **Редактор** (будущее) — веб/десктоп инструмент для авторов

### Формат данных одной новеллы
```
novel/
├── meta.json          # id, title, cover, description, author, tags
├── characters.json    # персонажи: id, name, sprites, colors
├── variables.json     # начальные переменные (отношения, флаги)
├── chapters/
│   ├── chapter_1.json # сцены с диалогами, выборами, эффектами
│   └── chapter_2.json
└── assets/
    ├── backgrounds/   # фоны сцен
    ├── characters/    # спрайты персонажей
    └── audio/         # музыка и звуки
```

### Структура проекта
```
navell/
├── client/                       # Flutter-приложение (движок новелл)
│   ├── lib/
│   │   ├── main.dart             # Точка входа (Hive + AdMob init)
│   │   ├── app/
│   │   │   ├── app.dart          # MaterialApp, роутинг
│   │   │   └── theme.dart        # Глобальная тема (тёмная, розово-фиолетовая)
│   │   ├── models/               # Модели данных
│   │   ├── engine/               # Ядро движка (SceneEngine, VariableEngine, ConditionEvaluator)
│   │   ├── services/             # Сервисы
│   │   │   ├── novel_loader.dart # Загрузка новелл из assets/файлов
│   │   │   ├── save_service.dart # Сохранение прогресса (Hive)
│   │   │   ├── currency_service.dart # Алмазы, билеты, рефилл
│   │   │   ├── ad_service.dart   # Rewarded Ads (google_mobile_ads)
│   │   │   ├── iap_service.dart  # In-App Purchases (покупка алмазов/билетов)
│   │   │   ├── vip_service.dart  # VIP-подписка (ежедневные алмазы, безлимит)
│   │   │   ├── daily_reward_service.dart # Ежедневные награды (7-дневный цикл)
│   │   │   ├── auth_service.dart # Авторизация (JWT, Google, Apple)
│   │   │   ├── sync_service.dart # Синхронизация с сервером
│   │   │   └── ...               # wardrobe, profile, audio, locale
│   │   ├── screens/              # Экраны
│   │   │   ├── library_screen.dart   # Библиотека новелл
│   │   │   ├── game_screen.dart      # Игровой экран
│   │   │   ├── shop_screen.dart      # Магазин (IAP + реклама + VIP)
│   │   │   ├── profile_screen.dart   # Профиль + валюта + реклама
│   │   │   └── ...               # auth, settings, gallery, wardrobe
│   │   └── widgets/              # UI-компоненты (DialogueBox, NovelCard, DailyRewardDialog)
│   ├── assets/                   # Ассеты (novels, backgrounds, ui)
│   ├── android/                  # Android-проект
│   ├── ios/                      # iOS-проект
│   └── pubspec.yaml              # Зависимости
├── server/                       # REST API (Node.js + Express + Prisma)
├── admin/                        # Веб-админка (React + Ant Design)
├── editor/                       # Веб-редактор новелл (React + Zustand + @xyflow/react)
├── README.md
└── ROADMAP.md
```

### Формат сцены (пример JSON)
```json
{
  "id": "ch1_s3",
  "background": "cafe_night.png",
  "music": "romantic_evening.mp3",
  "charactersOnScreen": [
    { "characterId": "alex", "spriteId": "smile", "position": "center", "animation": "fade_in" }
  ],
  "events": [
    { "type": "dialogue", "speaker": "alex", "text": "Я давно хотел тебе кое-что сказать..." },
    { "type": "narration", "text": "Сердце забилось быстрее." },
    {
      "type": "choice",
      "choices": [
        {
          "text": "Я тоже... 💕",
          "condition": { "variable": "alex_love", "operator": ">=", "value": 5 },
          "effects": { "alex_love": "+3", "route": "romance" },
          "nextSceneId": "ch1_s4_romance"
        },
        {
          "text": "💎 Поцеловать его",
          "premium": true,
          "cost": 15,
          "effects": { "alex_love": "+5", "unlocked_cg": "first_kiss" },
          "nextSceneId": "ch1_s4_kiss"
        }
      ]
    }
  ]
}
```

---

## Roadmap

### Фаза 1: Основа ✅ ЗАВЕРШЕНА
- [x] Выбор стека технологий (Flutter + Riverpod + Hive)
- [x] Выбор названия приложения → **Amoria**
- [x] Установка Flutter SDK (brew install --cask flutter)
- [x] Инициализация Flutter-проекта (flutter create)
- [x] Настройка зависимостей (pubspec.yaml): flutter_riverpod, hive_flutter, json_annotation, just_audio, cached_network_image, google_fonts, equatable, uuid, path_provider
- [x] Создание структуры каталогов (lib/models, engine, services, screens, widgets, app)
- [x] Модель Character — персонаж + спрайты (character.dart + .g.dart)
- [x] Модель Scene — сцена, события, выборы, условия (scene.dart + .g.dart)
- [x] Модель Novel — метаданные новеллы, главы (novel.dart + .g.dart)
- [x] Модель GameState — состояние игры, переменные, история (game_state.dart)
- [x] Генерация сериализации (dart run build_runner build)
- [x] Написание демо-новеллы «Тени Петербурга» (8 сцен, 3 ветки, премиум-выбор)
- [x] Манифест новелл (manifest.json)

### Фаза 2: Движок ✅ ЗАВЕРШЕНА
- [x] SceneEngine (scene_engine.dart) — Riverpod StateNotifier, проигрывание сцен, переходы между ними, загрузка новеллы, навигация по событиям, обработка выборов
- [x] VariableEngine (variable_engine.dart) — применение эффектов (+N, -N, toggle, прямое присвоение), инициализация переменных из конфига
- [x] ConditionEvaluator (condition_evaluator.dart) — проверка условий для показа вариантов выбора (операторы: >=, <=, ==, !=, >, <)
- [x] SaveService (save_service.dart) — сохранение/загрузка прогресса в Hive, проверка наличия сохранения, список сохранённых новелл

### Фаза 3: UI ✅ ЗАВЕРШЕНА
- [x] AppTheme (theme.dart) — тёмная тема с розово-фиолетовой цветовой схемой
- [x] NavellApp → AmoriApp (app.dart) — MaterialApp с роутингом
- [x] DialogueBox (dialogue_box.dart) — анимация посимвольной печати текста, имя говорящего с цветом, пропуск анимации по тапу, стрелка «далее»
- [x] ChoiceButtons (choice_buttons.dart) — анимация нажатия (ScaleTransition), премиум-кнопки с иконкой 💎 и стоимостью, градиенты
- [x] NovelCard (novel_card.dart) — карточка с обложкой, названием, автором, описанием, тегами
- [x] LibraryScreen (library_screen.dart) — библиотека новелл с градиентным заголовком «Amoria», загрузка из manifest.json, состояние пустой библиотеки
- [x] GameScreen (game_screen.dart) — полноэкранный игровой экран: фон, отображение персонажей по позициям (left/center/right), диалоги, нарратив, выборы, кнопка «назад»

### Фаза 4: Полировка ✅ ЗАВЕРШЕНА
- [x] Переходы между сценами (fade, slide, dissolve анимации)
- [x] Аудио-сервис (фоновая музыка через just_audio, звуковые эффекты)
- [x] Анимации персонажей (появление fade_in, уход fade_out, смена эмоций)
- [x] Реальные фоновые изображения вместо градиентных плейсхолдеров
- [x] Реальные спрайты персонажей вместо плейсхолдеров (буква имени)
- [x] Экран настроек (скорость текста, громкость музыки, автопрокрутка)
- [x] Экран деталей новеллы (обложка на весь экран, описание, список глав, кнопка «Играть»/«Продолжить»)
- [x] Шкала отношений (relationship_bar.dart)
- [x] Автосохранение при выходе из игры
- [x] Индикатор прогресса по главе

### Фаза 5: Контент и ресурсы ⬜ НЕ НАЧАТА
- [ ] Нарисовать/заказать арт: фоны (город ночью, кафе, особняк и т.д.)
- [ ] Нарисовать/заказать арт: спрайты персонажей (разные эмоции)
- [ ] Подобрать/написать фоновую музыку для разных настроений
- [ ] Написать полноценный сценарий для демо-новеллы (все главы)
- [ ] Создать обложку для демо-новеллы
- [ ] Создать иконку приложения Amoria

### Фаза 6: Расширенные функции ✅ ЗАВЕРШЕНА
- [x] Загрузка новелл с сервера (API + скачивание контент-паков)
- [x] Система монетизации (премиум-выборы, внутриигровая валюта — алмазы, билеты)
- [x] Профиль пользователя (аватар, статистика, достижения)
- [x] Галерея разблокированных CG-артов
- [x] Система достижений / бейджей
- [x] Push-уведомления о новых главах/новеллах (готово к интеграции Firebase)
- [x] Мультиязычность (русский / английский)
- [x] Гардероб (смена одежды персонажей)

### Фаза 7: Редактор новелл ✅ ЗАВЕРШЕНА
- [x] Веб-редактор для авторов (React + TypeScript + Vite)
- [x] Модели данных (TypeScript типы, совпадающие с Dart)
- [x] Zustand-стор (CRUD для проекта, персонажей, глав, сцен, событий)
- [x] Визуальный редактор сцен (граф @xyflow/react, drag & drop)
- [x] Редактор событий сцены (диалоги, нарратив, выборы, премиум)
- [x] Панель управления (метаданные, персонажи, главы, переменные)
- [x] Превью сцены в реальном времени (мобильный фрейм)
- [x] Экспорт новеллы в JSON / ZIP-пакет для Amoria
- [x] Импорт проекта из JSON
- [x] Валидация сценария (BFS достижимость, битые ссылки, пустые тексты)

### Фаза 8: Сервер ✅ ЗАВЕРШЕНА
- [x] REST API (Node.js + Express + TypeScript)
- [x] PostgreSQL + Prisma ORM (схема: novels — каталог, файлы, версии, статистика)
- [x] Docker Compose для PostgreSQL (dev окружение)
- [x] GET /v1/novels — каталог опубликованных новелл
- [x] GET /v1/novels/:id — детали одной новеллы
- [x] GET /v1/novels/:id/download — скачать ZIP-пак с отслеживанием прогресса
- [x] POST /v1/novels/upload — загрузить новеллу (multipart/form-data, извлечение meta.json + обложки)
- [x] DELETE /v1/novels/:id — удалить новеллу с файлами
- [x] Автоизвлечение метаданных из ZIP (meta.json, обложка, счёт глав)
- [x] Версионирование новелл (инкремент при обновлении)
- [x] Счётчик загрузок
- [x] Исправлена клиентская распаковка ZIP: Process.run('unzip') → пакет archive (работает на mobile)
- [x] Авторизация (JWT + email/пароль): POST /v1/auth/register, /login, GET /me
- [x] Серверная синхронизация прогресса: saves, profile, currency
- [x] GET/PUT /v1/sync/saves/:novelId — сохранения игры
- [x] GET/PUT /v1/sync/profile — профиль пользователя
- [x] GET/PUT /v1/sync/currency — валюта (алмазы, билеты)
- [x] GET /v1/sync/all — полная синхронизация (pull all)
- [x] Flutter AuthService (login, register, token хранение в Hive)
- [x] Flutter SyncService (push/pull данных с сервером)
- [x] Экран авторизации (login/register, тёмная тема)
- [x] Мерж данных при синхронизации (max статистики, union CG/достижений)
- [x] Интеграция авторизации в UI: кнопка входа в шапке библиотеки, секция аккаунта в профиле
- [x] Кнопка «Синхронизировать» (push all) и «Выйти» с подтверждением
- [x] Приветствие залогиненного пользователя на главном экране
- [x] Вход через Google (google_sign_in v7, OAuth2 верификация на сервере)
- [x] Вход через Apple (sign_in_with_apple, только iOS/macOS)
- [x] POST /v1/auth/social — серверный эндпоинт для соцсетей (Google/Apple)
- [x] Автосоздание пользователя при первом входе через соцсеть
- [x] Кнопки соцсетей на экране авторизации (разделитель «или»)

### Фаза 9: Админ-панель ✅ ЗАВЕРШЕНА
- [x] Роль `admin` в модели User (enum: user, admin) + миграция
- [x] `adminMiddleware` — проверка JWT + role === 'admin'
- [x] Seed для первого админа (admin@amoria.app)
- [x] GET /v1/admin/stats — статистика (пользователи, новеллы, загрузки, активность)
- [x] GET /v1/admin/users — список пользователей (пагинация, поиск)
- [x] GET /v1/admin/users/:id — детали (профиль, валюта, сохранения)
- [x] PATCH /v1/admin/users/:id — редактирование (роль, алмазы, билеты)
- [x] DELETE /v1/admin/users/:id — удаление пользователя
- [x] GET /v1/admin/novels — все новеллы (включая неопубликованные)
- [x] PATCH /v1/admin/novels/:id — редактирование (publish/unpublish, метаданные)
- [x] Веб-админка (React + TypeScript + Vite + Ant Design)
- [x] Страница логина (email + пароль, проверка роли admin)
- [x] Дашборд (карточки статистики: пользователи, новеллы, загрузки, активность)
- [x] Пользователи (таблица с поиском, детали, редактирование, удаление)
- [x] Новеллы (таблица, publish/unpublish switch, загрузка ZIP, удаление)

### Фаза 10: Поглавная загрузка и живой контент ✅ ЗАВЕРШЕНА
- [x] Prisma: модель Chapter (novelId, number, title, isReleased, releasedAt)
- [x] Novel: поле releasedChapters (сколько глав вышло vs запланированных)
- [x] При upload ZIP: автоматическое создание записей Chapter в БД
- [x] GET /v1/novels/:id/chapters — список глав с флагами isReleased
- [x] GET /v1/novels/:id/chapters/:number/download — скачать JSON одной главы
- [x] Admin: PATCH /v1/admin/novels/:id/chapters/:number — выпустить/скрыть главу
- [x] Клиент: ChapterInfo модель, fetchChaptersList(), downloadChapter()
- [x] SceneEngine: умный переход между главами (локально → сервер → скачать / скоро / конец)
- [x] UI: экран перехода «Скачать главу N» / «Продолжение следует» / «Конец истории»
- [x] novel_detail_screen: отображение released/total глав
- [x] Реальная загрузка изображений: фоны и спрайты из скачанных файлов (Image.file)
- [x] NovelCoverImage: умный виджет (файл → asset → сервер → плейсхолдер)
- [x] Автопереход между главами при наличии следующей

### Фаза 11: Монетизация ✅ ЗАВЕРШЕНА
- [x] Rewarded Ads (google_mobile_ads)
  - [x] AdService: rewarded-реклама с лимитом 5/день, предзагрузка
  - [x] Кнопка «📺 Реклама → +3💎» в профиле
  - [x] Кнопка «📺 Реклама → +1🎫» в диалоге «Нет билетов»
  - [x] AdMob тестовые ID в AndroidManifest.xml и Info.plist (iOS SKAdNetwork)
- [x] In-App Purchases (in_app_purchase)
  - [x] IapService: consumables + subscriptions, purchaseStream
  - [x] 5 продуктов: 20💎 $0.99, 60💎 $2.99, 150💎 $5.99, 500💎 $14.99, 5🎫 $0.99
  - [x] Стартовый бандл: 100💎 + 10⚡ за $0.99 (разовый, x10 ценность)
- [x] Магазин (ShopScreen)
  - [x] Стартовый бандл с градиентом и «Только один раз!»
  - [x] Карточки алмазов/билетов с ценами из магазина
  - [x] Карточка VIP-подписки с перечнем привилегий
  - [x] Бесплатная секция: реклама за алмазы
  - [x] Баланс валюты в AppBar, кнопка «Восстановить покупки»
  - [x] Кнопка «Открыть магазин» в профиле
- [x] VIP-подписка (VipService, $4.99/мес)
  - [x] Ежедневно +5💎 (collectDailyDiamonds)
  - [x] Безлимитные билеты (пропуск spendTicket в GameScreen)
  - [x] Ранний доступ к главам, без рекламы
  - [x] Эксклюзивная рамка профиля
  - [x] Хранение в Hive, проверка expiresAt
- [x] UX монетизации
  - [x] Бейджи валюты с кнопкой «+» → быстрый переход в магазин
  - [x] Таймер восстановления билетов (MM:SS) на главном экране
  - [x] Ежедневные награды (Daily Login): popup при запуске, 7-дневный цикл
  - [x] Промо-баннер спецпредложения на главном экране

### Фаза 12: Remote Config — серверная конфигурация ✅ ГОТОВО
Все параметры игры настраиваются с сервера без перевыпуска приложения.
- [x] Сервер: модель и API
  - [x] Prisma: модель `GameConfig` (JSON-колонки по секциям, version)
  - [x] Seed: начальный конфиг со всеми текущими значениями
  - [x] `GET /v1/config` — публичный, весь конфиг одним JSON (304 если не изменился)
  - [x] `PUT /v1/admin/config` — обновление конфига (admin only)
  - [x] `GET /v1/admin/config` — текущий конфиг для админки
- [x] Клиент: RemoteConfigService
  - [x] `remote_config_service.dart` — загрузка, кеш в Hive, fallback оффлайн
  - [x] Загрузка конфига при старте (`main.dart`)
  - [x] Версионирование: скачивать только если новее
  - [x] Типизированные модели: EconomyConfig, AdsConfig, IapConfig, VipConfig, DailyRewardConfig, AchievementConfig
- [x] Миграция сервисов на RemoteConfig
  - [x] `CurrencyService` → maxTickets, ticketRefillMinutes из конфига
  - [x] `AdService` → maxAdsPerDay, diamondReward, ticketReward из конфига
  - [x] `VipService` → dailyDiamonds, привилегии из конфига
  - [x] `DailyRewardService` → 7-day rewards из конфига
- [x] Админка: страница «Конфигурация»
  - [x] Секции: экономика, реклама, VIP (формы), IAP/Daily/Achievements/Localization (JSON-редактор)
  - [x] Кнопка «Сохранить» по каждой секции

### Фаза 13: Анимации сцен и эффекты ⬜ НЕ НАЧАТА
Полная поддержка анимаций и визуальных эффектов: от редактора до клиента. Сервер изменений не требует (формат ZIP/JSON не зависит от содержимого).

#### Клиент (Flutter) — модели данных
- [ ] Добавить поле `transition` в Dart-модель `Scene` (`type`: fade/slide_left/slide_right/dissolve/none, `duration`: мс). Пересоздать `.g.dart`
- [ ] Добавить тип `effect` в enum `EventType` (Dart). Добавить поля `effectType`, `effectDuration`, `effectIntensity` в `SceneEvent`
- [ ] Типизировать поле `animation` в `SceneCharacter` — enum вместо String (`fade_in`, `fade_out`, `slide_in_left`, `slide_in_right`, `bounce`, `shake`)

#### Клиент (Flutter) — движок и рендеринг
- [ ] SceneEngine: использовать `scene.transition` при переходе между сценами (передавать тип/длительность в UI)
- [ ] GameScreen: подключить `scene_transitions.dart` (fade/slideLeft/dissolve уже написаны, но не используются) с настраиваемой длительностью
- [ ] GameScreen: обработка события `effect` — реализовать shake (вибрация экрана), flash (белая вспышка), fade_to_black (затемнение)
- [ ] GameScreen: добавить оверлеи для погодных эффектов (rain, snow, particles) — виджет поверх сцены
- [ ] AnimatedCharacterSprite: использовать поле `animation` из SceneCharacter (сейчас только fade_in + slide_up захардкожен)
- [ ] Поддержка fade_out, slide_in_left/right, bounce, shake анимаций для персонажей

#### Редактор (React) — типы данных
- [ ] Добавить поле `transition` в TypeScript тип `Scene` (type + duration)
- [ ] Добавить тип `effect` в `EventType`, поля `effectType`, `effectDuration`, `effectIntensity` в `SceneEvent`
- [ ] Расширить поле `animation` в `SceneCharacter` определённым набором значений

#### Редактор (React) — UI
- [ ] Блок «Переход» в редакторе сцены: выпадающий список типа перехода + слайдер длительности
- [ ] Блок «Анимация персонажа» при добавлении персонажа на сцену: выбор анимации появления
- [ ] Новый тип события `effect` в выпадающем списке EventEditor
- [ ] Форма эффекта: выбор типа, длительность, интенсивность (слайдер)
- [ ] Иконка эффекта (✨) в списке событий сцены

#### Редактор (React) — превью
- [ ] CSS-анимации в ScenePreview для переходов между сценами (fade, slide)
- [ ] CSS-анимации для эффектов (shake, flash, fade_to_black)
- [ ] Анимации появления/ухода персонажей в превью

#### Экспорт и совместимость
- [ ] Поддержка полей `transition`, `effect`, `animation` в JSON/ZIP экспорте
- [ ] Обратная совместимость: все новые поля опциональны, старые новеллы работают без изменений

### Фаза 14: Продвинутые визуальные фичи ⬜ НЕ НАЧАТА
Фичи, вдохновлённые «Клубом Романтики» и топовыми визуальными новеллами. Делают игру более кинематографичной и атмосферной.

#### CG-арт вставки (полноэкранные иллюстрации)
- [ ] Новый тип события `show_cg` в SceneEvent (Dart + TypeScript): поля `cgImage`, `cgTransition` (fade/zoom_in), `cgDuration`
- [ ] Клиент: полноэкранный оверлей CG-арта поверх сцены с fade/zoom анимацией + tap для закрытия
- [ ] Автоматическая разблокировка в галерее CG при показе
- [ ] Редактор: тип события `show_cg` в EventEditor, загрузка CG-изображения, превью

#### Zoom и Pan камеры (движение по фону)
- [ ] Добавить поле `camera` в `Scene` и/или новый тип события `camera_move`: `zoom` (0.5–2.0), `panX`/`panY` (смещение), `duration`
- [ ] Клиент: `AnimatedContainer` / `Transform.scale` + `Transform.translate` для плавного zoom/pan фона
- [ ] Примеры использования: медленное приближение к лицу персонажа, панорама по городу, zoom-out для показа масштаба
- [ ] Редактор: визуальный блок камеры (слайдеры zoom, panX, panY, длительность)

#### Эмоции-иконки над персонажами
- [ ] Добавить новый тип события `show_emotion` в SceneEvent: `characterId`, `emotionType` (heart, sweat_drop, question, exclamation, anger, sparkle, music_note, zzz)
- [ ] Клиент: анимированная иконка над спрайтом персонажа (popup + fade, 1–2 сек)
- [ ] Встроенный набор SVG/PNG иконок эмоций (не требует загрузки от автора)
- [ ] Редактор: тип события `show_emotion`, выбор персонажа + выбор эмоции из набора иконок

#### Cross-fade смена спрайтов
- [ ] Клиент: при событии `changeSprite` — плавный cross-fade между старым и новым спрайтом (300–500 мс) вместо мгновенной замены
- [ ] Опциональное поле `spriteDuration` в SceneEvent для настройки длительности
- [ ] Редактор: слайдер длительности в форме события `changeSprite`

#### Таймер на выбор
- [ ] Добавить поле `timeLimit` (секунды) в SceneEvent для событий типа `choice`
- [ ] Добавить поле `defaultChoiceIndex` — какой вариант выбирается при истечении времени
- [ ] Клиент: обратный отсчёт (круговой прогресс-бар), auto-select при timeout
- [ ] Редактор: чекбокс «Ограничить время» + поле ввода секунд + выбор варианта по умолчанию

#### Параллакс фонов (многослойные фоны)
- [ ] Расширить `background` в Scene: массив слоёв `backgroundLayers` (image, depth, offsetX, offsetY) вместо одной строки
- [ ] Клиент: Stack из слоёв с лёгким смещением при переходах/движении камеры (эффект глубины)
- [ ] Обратная совместимость: если `background` — строка, работает как раньше (один слой)
- [ ] Редактор: управление слоями фона (добавить/удалить слой, загрузить изображение, настроить глубину)

### Фаза 15: Мини-игры ⬜ ОТЛОЖЕНА
- [ ] QTE (Quick Time Events) — нажми в нужный момент
- [ ] Простые пазлы
- [ ] Другие интерактивные вставки между сценами
_(отложено — требует отдельного проектирования UI/UX)_

### Фаза 16: Публикация ⬜ НЕ НАЧАТА
- [ ] Подготовка скриншотов для сторов
- [ ] Описание и ключевые слова для ASO
- [ ] Публикация в Google Play
- [ ] Публикация в App Store
- [ ] Лендинг-страница amoria.app (или подобный домен)
- [ ] Страницы в соцсетях (Instagram, TikTok, VK)

---

## Ключевые технические решения
| Решение | Выбор | Почему |
|---------|-------|--------|
| Фреймворк | Flutter | Кроссплатформа + мощный кастомный UI + анимации |
| State Management | Riverpod | Мощный, но простой, автодиспоуз |
| Локальное хранение | Hive | Быстрая NoSQL БД, идеальна для сохранений |
| Сериализация | json_serializable | Типобезопасность, codegen |
| Аудио | just_audio | Лучшая библиотека для аудио во Flutter |
| Изображения | cached_network_image | Кеширование при загрузке с сервера |

---

## Как добавить новую новеллу
1. Создай папку `client/assets/novels/my_novel/`
2. Добавь `meta.json` (id, title, description, author, tags)
3. Добавь `characters.json` (персонажи и их спрайты)
4. Добавь `variables.json` (начальные переменные)
5. Создай `chapters/chapter_1.json` (сцены с событиями)
6. Положи арт в `client/assets/backgrounds/`, `client/assets/characters/`, `client/assets/audio/`
7. Добавь id новеллы в `client/assets/novels/manifest.json`
8. Зарегистрируй ассеты в `client/pubspec.yaml`
