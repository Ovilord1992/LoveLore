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

### Структура Flutter-проекта
```
lib/
├── main.dart                     # Точка входа
├── app/
│   ├── app.dart                  # MaterialApp, роутинг
│   └── theme.dart                # Глобальная тема (тёмная, розово-фиолетовая)
├── models/                       # Модели данных
│   ├── models.dart               # Экспорт всех моделей
│   ├── novel.dart                # NovelMeta, Chapter
│   ├── scene.dart                # Scene, SceneEvent, Choice, Condition, SceneCharacter
│   ├── character.dart            # Character, CharacterSprite
│   └── game_state.dart           # GameState (прогресс игрока)
├── engine/                       # Ядро движка
│   ├── scene_engine.dart         # Логика проигрывания сцен, переходы, выборы
│   ├── variable_engine.dart      # Управление переменными (инкремент, присвоение, toggle)
│   └── condition_evaluator.dart  # Проверка условий (>=, <=, ==, !=, >, <)
├── services/                     # Сервисы
│   ├── novel_loader.dart         # Загрузка новелл из assets (JSON → модели)
│   └── save_service.dart         # Сохранение/загрузка прогресса (Hive)
├── screens/                      # Экраны
│   ├── library_screen.dart       # Библиотека новелл (главный экран)
│   └── game_screen.dart          # Игровой экран (фон, персонажи, диалоги, выборы)
└── widgets/                      # UI-компоненты
    ├── dialogue_box.dart         # Окно диалога с анимацией печати текста
    ├── choice_buttons.dart       # Кнопки выбора с анимацией нажатия + премиум
    └── novel_card.dart           # Карточка новеллы в библиотеке
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

### Фаза 10: Публикация ⬜ НЕ НАЧАТА
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
1. Создай папку `assets/novels/my_novel/`
2. Добавь `meta.json` (id, title, description, author, tags)
3. Добавь `characters.json` (персонажи и их спрайты)
4. Добавь `variables.json` (начальные переменные)
5. Создай `chapters/chapter_1.json` (сцены с событиями)
6. Положи арт в `assets/backgrounds/`, `assets/characters/`, `assets/audio/`
7. Добавь id новеллы в `assets/novels/manifest.json`
8. Зарегистрируй ассеты в `pubspec.yaml`
