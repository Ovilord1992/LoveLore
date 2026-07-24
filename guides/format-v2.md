# Формат новелл v2 и API-контракт (июль 2026)

Этот документ — **единый контракт** для client/, server/, admin/ и editor/. Все четыре подпроекта реализуют ровно то, что описано здесь. При конфликте со старым кодом побеждает этот документ; при конфликте имён СУЩЕСТВУЮЩИХ полей — побеждает существующий код (документ описывает только новые поля и семантику).

## Принципы

1. **Обратная совместимость обязательна.** Старые JSON-новеллы работают без изменений. Все новые поля — опциональные.
2. **Никаких новых типов событий.** Enum `EventType` не расширяется (старые клиенты падают на неизвестном enum). Вся новая функциональность — опциональные поля на существующих структурах.
3. **Переводы:** ключ перевода — исходная строка **с плейсхолдерами**. Порядок применения: перевод → интерполяция.
4. **Экономика (алмазы) серверно-авторитетна.** Клиент не может поднять баланс произвольно; все начисления идут через леджер с валидацией причин.

---

# Часть 1. Расширения JSON-формата новелл

## 1.1. Составные условия

На `Choice` (и в `branches`, см. 1.2) добавляются:

```json
{
  "text": "Поцеловать его",
  "nextSceneId": "scene_kiss",
  "conditions": [
    { "variable": "love", "operator": ">=", "value": 10 },
    { "variable": "chapter2_met", "operator": "==", "value": true }
  ],
  "conditionsLogic": "and"
}
```

- `conditions` — массив условий той же структуры, что существующее одиночное `condition`.
- `conditionsLogic`: `"and"` (по умолчанию) | `"or"`.
- Легаси-поле `condition` (одиночное) продолжает работать. Если заданы оба — приоритет у `conditions`.

## 1.2. Ветвление по переменным (branches)

Новое опциональное поле на `Scene`:

```json
{
  "id": "scene_party_end",
  "events": [ "..." ],
  "branches": [
    {
      "conditions": [ { "variable": "love_mia", "operator": ">=", "value": 20 } ],
      "conditionsLogic": "and",
      "nextSceneId": "scene_mia_route"
    },
    {
      "conditions": [ { "variable": "brave", "operator": ">", "value": 3 } ],
      "nextSceneId": "scene_brave_route"
    }
  ],
  "nextSceneId": "scene_default_route"
}
```

Семантика: в **конце сцены** (после последнего события), если переход не был выполнен выбором, движок проверяет `branches` по порядку; первое сработавшее условие определяет `nextSceneId`. Если ни одно не сработало — используется `scene.nextSceneId`; если и его нет — стандартная логика конца главы. Это механизм «сюжет сам сворачивает по накопленным очкам» (алмазные маршруты Romance Club).

## 1.3. Концовки

Новое опциональное поле на `Scene`:

```json
{
  "id": "scene_final_good",
  "events": [ "..." ],
  "ending": {
    "id": "good_end",
    "title": "Счастливый финал",
    "description": "Вы остались вместе.",
    "image": "cg/ending_good.png"
  }
}
```

Семантика: при достижении конца сцены с `ending` движок (вместо любого перехода): записывает концовку в профиль (ключ `"<novelId>:<endingId>"` в `unlockedEndings`), показывает экран концовки (title/description/image), затем возвращает в библиотеку. Достижение концовки шлёт аналитику `ending_reached` и триггерит ачивки.

В `meta.json` — опциональный список всех концовок для галереи «N из M»:

```json
"endings": [
  { "id": "good_end", "title": "Счастливый финал" },
  { "id": "secret_end", "title": "Тайная концовка", "hidden": true }
]
```

`hidden: true` — до открытия отображается как «???». Экран деталей новеллы показывает прогресс концовок.

## 1.4. Интерполяция текста

В `text` событий dialogue/narration, в текстах вариантов выбора, в `recap` и в текстах концовок поддерживаются плейсхолдеры:

- `{name}` — имя игрока. Цепочка: переменная `player_name` → `displayName` профиля → `meta.playerNamePrompt.defaultName` → `"Ты"`.
- `{var:key}` — значение переменной `key` (числа без дробной части, если целые).

Интерполяция выполняется **после** перевода (ключи переводов содержат плейсхолдеры как есть).

В `meta.json` — опциональный запрос имени при первом старте новеллы:

```json
"playerNamePrompt": { "enabled": true, "prompt": "Как тебя зовут?", "defaultName": "Алиса" }
```

Результат пишется в переменную `player_name` сейва.

## 1.5. Гардероб (outfits)

В `characters.json` у персонажа появляется опциональный массив:

```json
{
  "id": "mia",
  "name": "Мия",
  "image": "sprites/mia/default.png",
  "outfits": [
    {
      "id": "casual",
      "name": "Повседневный",
      "default": true,
      "thumbnail": "sprites/mia/casual_thumb.png",
      "sprites": { "default": "sprites/mia/casual_default.png", "happy": "sprites/mia/casual_happy.png" }
    },
    {
      "id": "gala",
      "name": "Вечернее платье",
      "priceDiamonds": 30,
      "thumbnail": "sprites/mia/gala_thumb.png",
      "sprites": { "default": "sprites/mia/gala_default.png" }
    }
  ]
}
```

- Резолв спрайта при показе персонажа: `outfits[экипированный].sprites[спрайт-ключ]` → `outfits[экипированный].sprites["default"]` → базовые спрайты персонажа (полный фолбэк — старые новеллы работают как раньше).
- Разблокировка: покупка в гардеробе за `priceDiamonds` (через экономический леджер, reason `spend_wardrobe`) **или** сюжетно — новое опциональное поле на `Choice`: `"unlockOutfits": ["mia:gala"]`.
- Экипировка хранится per-novel в Hive-боксе `wardrobe`; outfit с `default: true` (или без цены) доступен сразу.

## 1.6. Озвучка реплик

Опциональное поле на событиях dialogue/narration:

```json
{ "type": "dialogue", "characterId": "mia", "text": "Привет!", "voice": "voice/ch1/mia_001.mp3" }
```

Файл проигрывается при показе события (обрывается при переходе к следующему). Файлы лежат в ZIP новеллы (`voice/...`).

## 1.7. Эмоции артом

Опциональное поле на событии `showEmotion`:

```json
{ "type": "showEmotion", "characterId": "mia", "emotion": "love", "image": "emotions/love.png" }
```

Если `image` задан — показывается картинка вместо emoji.

## 1.8. Рекап главы

Опциональное поле на `Chapter`:

```json
{ "id": "chapter_2", "number": 2, "recap": "Ранее: вы познакомились с Мией на вечеринке…", "firstSceneId": "...", "scenes": [] }
```

Показывается один раз перед первой сценой главы (пропускаемый экран «Ранее…»).

## 1.9. Отображение статов (панель отношений)

В `meta.json`:

```json
"statsDisplay": [
  { "variable": "love_mia", "label": "Мия", "icon": "heart", "color": "#E91E63", "max": 100 },
  { "variable": "brave", "label": "Смелость", "icon": "flame", "color": "#FF9800", "max": 10 }
]
```

- `icon`: `heart | star | flame | diamond | moon | sun | leaf` (маппинг на Material-иконки в клиенте).
- Клиент показывает: панель статов (кнопка в игровом UI, bottom sheet с прогресс-барами) и всплывающее уведомление при изменении такой переменной («+1 ♥ Мия»).

## 1.10. Параллакс-фоны

Поле `Scene.backgroundLayers[]` (`image`, `depth` 0.0..1.0, `offsetX/Y`) уже существует в формате — теперь оно **обязано рендериться** в игре: слои сортируются по depth (0.0 — дальний, неподвижный), `cameraMove.panX/panY` умножается на depth каждого слоя.

## 1.11. Что формат НЕ меняет

Сейв-слоты, skip прочитанного, backlog, галерея CG — чисто клиентские фичи без изменений формата. Мини-игры и липсинк — вне скоупа v2.

---

# Часть 2. API-контракт v2

## 2.1. Auth: refresh-токены

- Ответы `POST /v1/auth/login|register|social` дополняются полем `refreshToken` (существующее поле `token` остаётся — это access-токен, TTL **12 часов**, claims `{ userId, role, tv }`).
- `POST /v1/auth/refresh` `{ refreshToken }` → `{ token, refreshToken }` — **ротация**: старый refresh помечается использованным, выдаётся новая пара. Попытка повторного использования уже ротированного токена = кража → отзыв всей цепочки (family revoke).
- `POST /v1/auth/logout` `{ refreshToken }` — отзыв.
- Refresh TTL 90 дней. Таблица `RefreshToken { id, userId, tokenHash, familyId, expiresAt, revokedAt?, replacedById?, createdAt }`.
- `User.tokenVersion` (`tv` в claims): глобальный отзыв access-токенов (смена пароля → `tv++`). Легаси-токены без `tv` считаются валидными, пока `user.tokenVersion == 0`.
- Клиент: единый HTTP-слой — на 401 делает один refresh (сериализованный, без параллельных гонок) и повторяет запрос; при провале refresh — разлогин.

## 2.2. Экономика: серверный леджер

`POST /v1/economy/transactions` (auth) — батч операций от клиента (офлайн-очередь):

```json
{ "transactions": [
  { "key": "<uuid>", "currency": "diamonds", "delta": -15, "reason": "spend_choice", "refId": "novel1:scene_5:2", "clientTs": 1753257600000 }
] }
```

Ответ: `{ "results": [ { "key": "...", "status": "applied" | "rejected", "error": "..." } ], "balances": { "diamonds": 120, "tickets": 3 } }`

Валидация по `reason` (суммы берутся из GameConfig на сервере):

| reason | Правило |
|---|---|
| `spend_choice`, `spend_wardrobe` | delta < 0; всегда применяется, баланс клампится ≥ 0 |
| `ticket_entry` | currency=tickets, delta=-1 |
| `ticket_refill` | currency=tickets, +1, не выше `economy.maxTickets`, не чаще ~интервала рефилла |
| `ad_reward` | +`ads.rewardAmount`, максимум `ads.maxAdsPerDay` в UTC-сутки |
| `daily_reward` | +сумма дня из daily-конфига, раз в UTC-сутки, refId = индекс дня |
| `achievement` | +награда ачивки `refId` из конфига, один раз за refId навсегда |
| `vip_daily` | +`vip.dailyDiamonds`, раз в сутки, только при активном `vipExpiresAt` |
| `legacy_sync` | один раз за всю жизнь аккаунта, delta ≤ `economy.legacySyncCap` (миграция старых локальных балансов) |
| `iap` | от клиента ОТКЛОНЯЕТСЯ — пишется только сервером из `/v1/iap/verify` |
| `admin_grant` / `admin_deduct` | только админ-ручка |

- Идемпотентность: unique `(userId, key)`; повтор ключа → прежний результат.
- Таблица `CurrencyLedger { id, userId, currency, delta, reason, refId?, idempotencyKey, createdAt }` + баланс в существующей `CurrencyData` обновляется атомарно в транзакции.
- `PUT /v1/sync/currency` **больше не поднимает балансы** (принимает, логирует, возвращает серверные значения). GET-семантика прежняя.
- `/v1/iap/verify` при начислении пишет записи в леджер (reason `iap`, refId = transactionId) и сохраняет оценку суммы `usdCents` из `iap.products[].usdCents` конфига.
- Клиент: локальный баланс остаётся для офлайн-UX; каждая мутация кладёт операцию в Hive-очередь; флаш при старте/онлайне; серверные `balances` из ответа — авторитетны (локальный баланс приводится к ним). Отклонённые операции удаляются из очереди.

## 2.3. Аналитика событий

`POST /v1/analytics/events` (auth опционален):

```json
{ "deviceId": "<uuid>", "events": [ { "name": "chapter_complete", "params": { "novelId": "n1", "chapter": 3 }, "ts": 1753257600000 } ] }
```

- Таблица `AnalyticsEvent { id, userId?, deviceId, name, params Json?, ts, createdAt }`, индексы `(name, ts)`, `(userId, ts)`.
- Имена событий клиента (фиксированный словарь): `session_start`, `novel_start`, `chapter_start`, `chapter_complete`, `choice_made` (params: premium bool), `ad_reward`, `iap_success`, `ending_reached`, `novel_download`.
- Клиент батчует (Hive-очередь, флаш каждые ~30с / 20 событий / при сворачивании).
- `User.lastActiveAt` обновляется (с троттлингом ~1 раз в час) на аутентифицированных запросах; дашборд активности считается по событиям + lastActiveAt, а не по `updatedAt`.

## 2.4. Admin: конфиг с историей, планировщик, главы, аналитика

- `PUT /v1/admin/config` — **валидация zod** всех секций (структура и типы; неизвестные ключи сохраняются с warning). Каждое изменение пишет снапшот в `ConfigHistory { id, version, data Json, changedBy, createdAt }`.
- `GET /v1/admin/config/history` → список `{ version, changedBy, createdAt }`; `GET /v1/admin/config/history/:version` → полный снапшот; `POST /v1/admin/config/rollback` `{ version }` → копирует снапшот в GameConfig с инкрементом версии.
- **Планировщик релиза глав**: `PATCH /v1/admin/novels/:id/chapters/:number` принимает `{ releasedAt: "<future ISO>" }` с `isReleased: false` → глава «запланирована»; фоновый job на сервере (интервал 60с) автоматически выставляет `isReleased: true`, когда время пришло, и пересчитывает `releasedChapters`.
- **Upsert одной главы**: `POST /v1/admin/novels/:id/chapters` (JSON body `{ chapter: { ...полный JSON главы... } }`) — валидирует обязательные поля, вставляет/заменяет `chapters/chapter_<number>.json` внутри ZIP, upsert строки `Chapter` (сохраняя `isReleased` существующей), `version++`, инвалидация ZIP-кеша. Это основной сценарий «выпустить новую главу без перезаливки всего архива».
- **Перезаливка ZIP** новеллы: сохраняет `isReleased`/`releasedAt` существующих глав по `number`; новые главы создаются с `isReleased: false`.
- `GET /v1/admin/analytics/summary?days=30` → `{ dau: [{date, count}], wau, mau, newUsers: [{date,count}], revenueEstimateUsdCents, revenueByDay: [{date, usdCents}], topNovels: [{id, title, chapterCompletes}] }`.
- Админ-ручка гранта валюты пишет в леджер (`admin_grant`/`admin_deduct`); `GET /v1/admin/users/:id/ledger?limit=50` — последние операции.

## 2.5. Каталог: пагинация

`GET /v1/novels?page=1&limit=50`: **с параметром `page`** ответ — `{ items, total, page, limit }`; **без параметров** — легаси-массив (для старых клиентов), ограниченный 200. Индексы: `Novel(isPublished, updatedAt)`, `Chapter(novelId, isReleased)`.

## 2.6. IAP: server-to-server нотификации

- `POST /v1/iap/notifications/apple` — App Store Server Notifications V2 (`{ signedPayload }`): верификация подписи JWS (официальная библиотека `@apple/app-store-server-library`; окружение задаёт environment). REFUND / REVOKE / EXPIRED → пометить `IapTransaction.revokedAt`, отозвать VIP (если продукт VIP), компенсирующая запись в леджер (баланс ≥ 0).
- `POST /v1/iap/notifications/google` — RTDN через Pub/Sub push: верификация OIDC Bearer-токена (`google-auth-library`, audience из env `GOOGLE_RTDN_AUDIENCE`), декод `message.data`; voided/`SUBSCRIPTION_REVOKED` → как выше. Идемпотентность по `messageId`.
- **Без валидной подписи никакие действия не выполняются** (сырой payload сохраняется в таблицу `StoreNotification` для разбора, ответ 200).

## 2.7. Разное

- CORS: allowlist из env `CORS_ORIGINS` (через запятую) + дефолты `http://localhost:5173,http://localhost:5174` (editor, admin).
- Rate-limit: при заданном `REDIS_URL` — общий стор (rate-limit-redis); иначе in-memory + warning в prod-логе.
- Seed: пароль админа из env `SEED_ADMIN_PASSWORD` (без него — случайный, печатается в stdout один раз).
- GameConfig, новые поля: `ads.rewardedAdUnitIdAndroid`, `ads.rewardedAdUnitIdIos` (клиент: в release при пустых ID реклама отключается, в debug — тестовые ID Google); `economy.legacySyncCap` (дефолт 1000), `economy.maxTickets`; `iap.products[].usdCents` (для оценки выручки).
- Прямая публикация из редактора: существующие админ-ручки создания/перезаливки новеллы (multipart ZIP) + upsert главы из 2.4; редактору нужен только admin-логин и base URL.

---

# Часть 3. Клиентские фичи без изменения формата (для справки)

- **Сейв-слоты**: автосейв (как сейчас) + 3 ручных слота (`<novelId>#slot<N>` в боксе `game_saves`); меню Сохранить/Загрузить в паузе; «Продолжить» в библиотеке берёт самый свежий.
- **Skip прочитанного**: множество прочитанных `sceneId:eventIndex` per novel (Hive) + кнопка-тумблер fast-forward (~120 мс/событие) до первого непрочитанного или выбора.
- **Backlog**: история реплик (спикер+текст+выборы, кап 200) + существующий `DialogueLogScreen` подключается кнопкой в игровом UI.
- **CG-галерея**: unlocked-ключи формата `<novelId>|<путь картинки>`; галерея рендерит реальные изображения через загрузчик новелл, группировка по новеллам.

---

# Часть 4. Дополнение v2.1 — live-ops дозакрытие (июль 2026)

Контракты волны 2. Принципы те же: обратная совместимость, никаких новых типов событий, экономика только через леджер.

## 4.1. Версионирование формата

`meta.json`, новые опциональные поля:

```json
"formatVersion": 2,
"minAppVersion": "1.0.0"
```

- `formatVersion` — целое; при отсутствии считается `1`. Клиент объявляет `supportedFormatVersion = 2` (константа). Если `formatVersion` новеллы больше поддерживаемого — новелла не запускается: экран «Обновите приложение» (в каталоге — бейдж, вход заблокирован).
- `minAppVersion` — semver-строка; сравнивается с версией приложения. Клиент: версию берём из package_info_plus, если пакет уже есть; иначе — константа, синхронизированная с pubspec (с комментарием).
- Редактор пишет `formatVersion: 2` в экспорт автоматически; `minAppVersion` — опциональное поле в редакторе меты.

## 4.2. Защита сейвов при обновлении контента

Восстановление сейва обязано переживать любое изменение контента:

1. `sceneId` из сейва не найден в главе → откат к `firstSceneId` главы + snackbar «История была обновлена — прогресс возвращён к началу главы».
2. Глава из сейва отсутствует/не выпущена → откат к последней доступной главе (или главе 1) с тем же уведомлением.
3. `eventIndex` за пределами `scene.events` → кламп к началу сцены.
4. Переход в несуществующую сцену в рантайме (`nextSceneId`/branch указывает в никуда) → лог + стандартный поток конца главы, не крэш.
5. Ключи skip-read (`sceneId:eventIndex`) при рассинхроне просто не совпадают — это допустимо (события покажутся как непрочитанные), падать нельзя.

## 4.3. Версии контента и откат (сервер)

- Таблица `NovelArchive { id, novelId, version, filePath, sizeBytes, createdAt }`. При каждой перезаливке ZIP/upsert главы текущий архив сначала копируется в `uploads/history/<novelId>/v<version>.zip`; храним последние **5** версий (старшие удаляются вместе с файлами).
- `GET /v1/admin/novels/:id/versions` → `{ versions: [{version, sizeBytes, createdAt}] }`.
- `POST /v1/admin/novels/:id/rollback` `{ version }` → восстанавливает ZIP из архива, перечитывает главы (merge release-состояния как при перезаливке), `version++` (история линейна, как у конфига), инвалидация ZIP-кеша. 404 если версии нет.

## 4.4. Аналитика: ретеншн и воронки (сервер + админка)

- `GET /v1/admin/analytics/retention?days=30` → `{ cohorts: [{ date, installs, d1, d7, d30 }] }`. Когорта = deviceId с первым `session_start` в дату date; dN = число устройств когорты с любым событием в date+N (для неполных когорт dN = null).
- `GET /v1/admin/analytics/funnel?novelId=<id>` → `{ novelId, novelStarts, chapters: [{ chapter, starts, completes }] }` — distinct deviceId по `chapter_start`/`chapter_complete` (params.novelId/params.chapter).

## 4.5. Промокоды

- Таблицы: `PromoCode { id, code unique (upper-case), diamonds, tickets, vipDays, maxRedemptions (0 = безлимит), redemptionsCount, expiresAt?, isActive, createdAt }`, `PromoRedemption { id, codeId, userId, createdAt, unique(codeId, userId) }`.
- `POST /v1/promo/redeem` (auth, limiter) `{ code }` → `200 { reward: { diamonds, tickets, vipDays }, balances }`. Ошибки: `404` нет кода / неактивен, `410` истёк или исчерпан, `409` уже погашен этим пользователем. Начисление атомарно через леджер (reason `promo`, refId = code); `vipDays` продлевает `vipExpiresAt` (от max(now, текущего)).
- Админ-CRUD: `GET /v1/admin/promo` (список с redemptionsCount), `POST /v1/admin/promo`, `PATCH /v1/admin/promo/:id` (isActive, expiresAt, maxRedemptions).
- Клиент: поле «Промокод» в профиле/настройках; balances из ответа авторитетны.

## 4.6. Эксперименты (A/B) и сегменты — секции GameConfig

```json
"experiments": [
  { "id": "price_test_1", "enabled": true, "variants": [
    { "key": "control", "weight": 50, "overrides": {} },
    { "key": "cheap",   "weight": 50, "overrides": { "economy.premiumChoiceBaseCost": 10 } }
  ] }
],
"segments": [
  { "id": "ios_vip", "conditions": { "platform": "ios", "vip": true },
    "overrides": { "ads.maxAdsPerDay": 0 } }
]
```

- **Порядок применения на клиенте:** базовый конфиг → overrides всех подошедших segments (по порядку массива) → overrides варианта каждого включённого эксперимента. Overrides — плоские dot-пути внутри секций, значение заменяется целиком.
- **Бакетирование:** детерминированное, стабильное между сессиями: `fnv1a("<deviceId>:<experimentId>") % totalWeight` → вариант по кумулятивным весам. Один раз за сессию на каждый применённый эксперимент клиент шлёт событие `experiment_exposure` `{ experimentId, variant }` (добавить в словарь имён на сервере).
- **Условия сегментов:** `platform` ("android"|"ios"), `vip` (bool), `installedAfter`/`installedBefore` (ISO; дата первого запуска хранится в `app_settings.first_launch_ts`, проставляется при первом старте).
- Сервер: zod-схемы обеих секций (веса > 0, уникальные id), админка — типизированные редакторы.

## 4.7. Удаление аккаунта и экспорт данных (требования сторов/GDPR)

- `DELETE /v1/auth/account` (auth) — анонимизация: email → `deleted-<id>@deleted.local`, passwordHash → случайный, displayName очищен, `tokenVersion++`, все refresh-токены отозваны; удаляются GameSave, UserProfileData, CurrencyData, Favorite, Rating, Review пользователя; CurrencyLedger/IapTransaction/AnalyticsEvent остаются привязанными к анонимизированной записи (финансовый учёт). → `200 { deleted: true }`.
- `GET /v1/auth/export` (auth) → JSON со всеми данными пользователя (user без hash, saves, profile, currency, ledger, transactions без чувствительных полей, redemptions).
- Клиент (настройки): «Скачать мои данные» (сохранить JSON в Documents + snackbar с путём, без новых зависимостей) и «Удалить аккаунт» (двойное подтверждение → запрос → локальный wipe токенов/профиля → экран входа).

## 4.8. Мелочь

- Сброс расписания главы: `PATCH /v1/admin/novels/:id/chapters/:number` с `releasedAt: null` очищает дату (серверная поддержка уже есть) — в админке кнопка «Убрать из расписания».

## 4.9. Тест-режим контента (админ видит черновики)

- Каталог `GET /v1/novels`, детали, список глав и обе download-ручки принимают **опциональный** Bearer. Для пользователя с ролью `admin`: каталог включает неопубликованные новеллы (в ответе добавляется поле `isPublished`), проверки `isReleased` глав пропускаются, ZIP отдаётся полным (без фильтрации невыпущенных глав, мимо кеша).
- Для обычных пользователей и анонимов поведение НЕ меняется.
- Клиент: шлёт токен на этих ручках, если залогинен; новеллы с `isPublished: false` помечаются бейджем «Черновик». Логика переходов глав не меняется (сервер сам отвечает админу, что глава доступна).

## 4.10. Согласия, возраст, ссылки (стор-комплаенс)

- Новая секция GameConfig `links: { privacyPolicyUrl, termsUrl }` (zod, опциональные строки-URL; редактируется в админке).
- Клиент, первый запуск (до онбординга): экран согласий — подтверждение возраста 16+, тумблер аналитики (по умолчанию вкл), тумблер персонализированной рекламы, ссылки на privacy/terms из конфига. Ключи в `app_settings`: `age_confirmed`, `consent_analytics`, `consent_ads_personalized`. Изменение — в настройках.
- `analytics_service`: при выключенном согласии события не логируются и не отправляются (очередь не пополняется).
- `ad_service`: при выключенной персонализации — non-personalized запросы (`npa=1`); на iOS перед персонализированной рекламой — запрос ATT (`app_tracking_transparency`), отказ → npa.
- Локальные уведомления (`flutter_local_notifications`, без точных алармов): «билеты восстановились» (время полного рефилла), напоминание о daily reward (локальный вечерний час, если не забран); отмена при открытии приложения; тумблеры в настройках; разрешения Android 13+/iOS запрашиваются при включении.
- In-app review (`in_app_review`): после первой концовки или 5 завершённых глав, не чаще раза в 30 дней (флаги в `app_settings`).
- Диплинки (`app_links`): `amoria://novel/<id>` → экран деталей новеллы; регистрация схемы в Android/iOS конфигах.
