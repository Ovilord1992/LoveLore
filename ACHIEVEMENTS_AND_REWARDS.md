# 🏆 Amoria — Полный каталог достижений и наград

> Анализ и дизайн от профессионального геймдизайнера.
> Все достижения и награды задаются через Remote Config (сервер) и локализуются через систему переводов.

---

## 📊 Аналитика и принципы

### Воронка вовлечения игрока

```
Новичок (1-3 дня)   → Активный (1-2 недели)   → Лояльный (1+ месяц)   → Фанат (3+ месяца)
   ↓                        ↓                         ↓                       ↓
Лёгкие достижения      Прогрессивные            Коллекционные           Хардкорные
(мгновенный дофамин)   (удержание)              (монетизация)           (статус)
```

### Баланс наград
- **Ранние достижения**: щедрые награды → игрок привыкает тратить алмазы
- **Средние**: умеренные → мотивация к покупкам
- **Поздние**: статусные → гордость и social proof

---

## 🎯 Достижения

### 1️⃣ Новичок — Первые шаги (Day 1-3)

| ID | Название | Описание | 💎 | Условие |
|---|---|---|---|---|
| `first_story` | Первая история | Начни свою первую новеллу | 10 | `totalNovelsStarted >= 1` |
| `first_choice` | Первый выбор | Сделай первый выбор в истории | 5 | `totalChoicesMade >= 1` |
| `first_chapter` | Первая глава | Прочитай свою первую главу | 5 | `totalChaptersRead >= 1` |
| `profile_setup` | Свой стиль | Настрой профиль — имя и аватар | 5 | Имя ≠ «Читатель» и аватар ≠ 0 |
| `daily_visitor` | Добро пожаловать | Забери первую ежедневную награду | 5 | `dailyStreak >= 1` |

**Итого**: 30 💎 — хватит на 1 премиум-выбор, игрок видит ценность алмазов.

### 2️⃣ Исследователь — Прогрессивные (Week 1-2)

| ID | Название | Описание | 💎 | Условие |
|---|---|---|---|---|
| `five_chapters` | Книжный червь | Прочитай 5 глав | 15 | `totalChaptersRead >= 5` |
| `ten_choices` | Решительность | Сделай 10 выборов | 10 | `totalChoicesMade >= 10` |
| `two_stories` | Библиотекарь | Начни 2 разные истории | 10 | `totalNovelsStarted >= 2` |
| `first_love` | Первая любовь | Набери 10+ очков отношений | 10 | Любая переменная `*_love >= 10` |
| `brave_heart` | Храброе сердце | Выбери смелый вариант | 5 | `chose_brave == true` |
| `first_premium` | Премиум-опыт | Выбери свой первый премиум-вариант | 10 | `premiumChoicesMade >= 1` |
| `streak_3` | 3 дня подряд | Заходи 3 дня подряд | 10 | `dailyStreak >= 3` |

**Итого**: 70 💎 — достаточно для 2-3 премиум-выборов.

### 3️⃣ Знаток — Коллекционные (Week 2-4)

| ID | Название | Описание | 💎 | Условие |
|---|---|---|---|---|
| `completionist` | Финалист | Пройди новеллу до конца | 25 | `totalNovelsCompleted >= 1` |
| `twenty_chapters` | Марафонец | Прочитай 20 глав | 20 | `totalChaptersRead >= 20` |
| `fifty_choices` | Судьбоносный | Сделай 50 выборов | 15 | `totalChoicesMade >= 50` |
| `collector` | Коллекционер | Разблокируй 3 CG-арта | 15 | `unlockedCGs.length >= 3` |
| `fashionista` | Модница | Разблокируй 3 наряда | 15 | `unlockedOutfits.length >= 3` |
| `mystery_solver` | Детектив | Собери 5 улик | 20 | `mystery_clues >= 5` |
| `streak_7` | Неделя с Amoria | Заходи 7 дней подряд | 20 | `dailyStreak >= 7` |
| `ad_watcher` | Спонсор | Посмотри 10 рекламных роликов | 10 | `adsWatched >= 10` |

**Итого**: 140 💎 — ощутимая награда за приверженность.

### 4️⃣ Эксперт — Для опытных (Month 1-2)

| ID | Название | Описание | 💎 | Условие |
|---|---|---|---|---|
| `three_novels` | Ценитель | Пройди 3 новеллы до конца | 30 | `totalNovelsCompleted >= 3` |
| `hundred_chapters` | Эрудит | Прочитай 100 глав | 30 | `totalChaptersRead >= 100` |
| `hundred_choices` | Архитектор судеб | Сделай 100 выборов | 25 | `totalChoicesMade >= 100` |
| `cg_master` | Галерист | Разблокируй 10 CG-артов | 25 | `unlockedCGs.length >= 10` |
| `diamond_spender` | Щедрая душа | Потрать 50 алмазов на премиум-выборы | 20 | `diamondsSpent >= 50` |
| `streak_14` | Две недели верности | Заходи 14 дней подряд | 25 | `dailyStreak >= 14` |
| `all_outfits_novel` | Стилист | Собери все наряды одной истории | 20 | Все outfit'ы 1 новеллы |
| `perfect_ending` | Идеальный финал | Получи лучшую концовку | 25 | `got_best_ending == true` |

**Итого**: 200 💎

### 5️⃣ Легенда — Хардкорные (Month 3+)

| ID | Название | Описание | 💎 | Условие |
|---|---|---|---|---|
| `five_novels` | Мастер историй | Пройди 5 новелл | 50 | `totalNovelsCompleted >= 5` |
| `all_cg` | Хранитель галереи | Разблокируй все CG одной новеллы | 40 | Все CG 1 новеллы |
| `streak_30` | Месяц с Amoria | Заходи 30 дней подряд | 50 | `dailyStreak >= 30` |
| `five_hundred_choices` | Повелитель судеб | Сделай 500 выборов | 40 | `totalChoicesMade >= 500` |
| `all_endings` | Альтернативные миры | Открой все концовки одной новеллы | 50 | Все endings 1 новеллы |
| `true_fan` | Истинный фанат | Открой 50 достижений | 100 | `achievements.length >= 50` |

**Итого**: 330 💎

---

## 🎁 Ежедневные награды (7-дневный цикл)

После 7 дней цикл повторяется с увеличенными наградами.

### Цикл 1 (базовый)

| День | Награда | Описание |
|---|---|---|
| 1 | 5 💎 | Алмазы |
| 2 | 1 ⚡ | Билет |
| 3 | 10 💎 | Алмазы |
| 4 | 2 ⚡ | Билеты |
| 5 | 15 💎 | Алмазы |
| 6 | 3 ⚡ | Билеты |
| 7 | 30 💎 + 5 ⚡ | Супер-награда! |

**За неделю**: 60 💎 + 11 ⚡

### Цикл 2+ (бонусный, множитель ×1.5)

| День | Награда |
|---|---|
| 1 | 8 💎 |
| 2 | 2 ⚡ |
| 3 | 15 💎 |
| 4 | 3 ⚡ |
| 5 | 20 💎 |
| 6 | 5 ⚡ |
| 7 | 50 💎 + 8 ⚡ |

---

## 💰 Экономика — Баланс валют

### Источники алмазов (F2P игрок в месяц)

| Источник | 💎 в месяц |
|---|---|
| Ежедневные награды | ~240 |
| Достижения (первые 2 месяца) | ~200 |
| Реклама (5 в день × 3💎) | ~450 |
| **Итого F2P** | **~890** |

### Расход алмазов

| Элемент | Стоимость |
|---|---|
| Премиум-выбор | 15-30 💎 |
| Эксклюзивный наряд | 50-100 💎 |
| Разблокировать главу раньше | 20-40 💎 |
| Обменять на билеты (1 шт) | 10 💎 |

### Вывод
F2P игрок может позволить ~2-3 премиум-выбора в день.
Для «собрать всё» — нужна покупка или VIP.
Это здоровый баланс, мотивирующий покупки, но не запирающий контент.

---

## 🏪 IAP продукты

| ID | Содержимое | Рекомендуемая цена |
|---|---|---|
| `starter_bundle` | 100 💎 + 10 ⚡ | $0.99 |
| `diamonds_20` | 20 💎 | $0.99 |
| `diamonds_60` | 60 💎 | $2.99 |
| `diamonds_150` | 150 💎 | $5.99 |
| `diamonds_500` | 500 💎 | $14.99 |
| `tickets_5` | 5 ⚡ | $1.99 |
| `vip_monthly` | VIP-подписка | $4.99/мес |

### VIP привилегии (настраиваются через Remote Config)

| Привилегия | Описание |
|---|---|
| `dailyDiamonds` | +N алмазов каждый день |
| `unlimitedTickets` | Безлимитные билеты |
| `earlyAccess` | Ранний доступ к новым главам |
| `noAds` | Без рекламы |
| `exclusiveFrame` | Эксклюзивная рамка профиля |

---

## 🔧 Remote Config формат для достижений

Достижения загружаются с сервера через `GET /v1/config` → поле `achievements`:

```json
{
  "achievements": [
    {
      "id": "first_story",
      "title": "first_story",
      "icon": "book",
      "diamondReward": 10,
      "description": "first_story_desc"
    },
    {
      "id": "five_chapters",
      "title": "five_chapters",
      "icon": "menu_book",
      "diamondReward": 15,
      "description": "five_chapters_desc"
    }
  ]
}
```

> **Важно**: `title` и `description` должны быть **ключами перевода** (не текстом),
> чтобы клиент мог их перевести через `ref.tr(achievement.title)`.
> Пока это НЕ реализовано — title/description хранятся как plain text на русском.

---

## 🌍 Локализация достижений — текущее состояние и план

### ❌ Текущее состояние
- `AchievementDef.title` и `.description` — хардкожены на русском
- Remote config отдаёт plain text без привязки к языку
- При смене языка достижения остаются на русском

### ✅ Рекомендуемый подход
1. В `AchievementDef.title` хранить **ключ перевода** (например `ach_first_story`)
2. В `locale_service.dart` добавить переводы для всех достижений
3. В UI отображать `ref.tr(achievement.title)` вместо `achievement.title`
4. Remote config может переопределять ключи

### Ключи перевода для достижений

```
ach_first_story / ach_first_story_desc
ach_first_choice / ach_first_choice_desc
ach_first_chapter / ach_first_chapter_desc
ach_profile_setup / ach_profile_setup_desc
ach_daily_visitor / ach_daily_visitor_desc
ach_five_chapters / ach_five_chapters_desc
ach_ten_choices / ach_ten_choices_desc
ach_two_stories / ach_two_stories_desc
ach_first_love / ach_first_love_desc
ach_brave_heart / ach_brave_heart_desc
ach_first_premium / ach_first_premium_desc
ach_streak_3 / ach_streak_3_desc
ach_completionist / ach_completionist_desc
ach_twenty_chapters / ach_twenty_chapters_desc
ach_fifty_choices / ach_fifty_choices_desc
ach_collector / ach_collector_desc
ach_fashionista / ach_fashionista_desc
ach_mystery_solver / ach_mystery_solver_desc
ach_streak_7 / ach_streak_7_desc
ach_ad_watcher / ach_ad_watcher_desc
ach_three_novels / ach_three_novels_desc
ach_hundred_chapters / ach_hundred_chapters_desc
ach_hundred_choices / ach_hundred_choices_desc
ach_cg_master / ach_cg_master_desc
ach_diamond_spender / ach_diamond_spender_desc
ach_streak_14 / ach_streak_14_desc
ach_all_outfits_novel / ach_all_outfits_novel_desc
ach_perfect_ending / ach_perfect_ending_desc
ach_five_novels / ach_five_novels_desc
ach_all_cg / ach_all_cg_desc
ach_streak_30 / ach_streak_30_desc
ach_five_hundred_choices / ach_five_hundred_choices_desc
ach_all_endings / ach_all_endings_desc
ach_true_fan / ach_true_fan_desc
```

---

## 📈 Метрики для отслеживания

| Метрика | Цель | Зачем |
|---|---|---|
| D1/D7/D30 Retention | 40%/20%/10% | Удержание |
| Средний DAU streak | 5+ дней | Привычка |
| % игроков с 5+ достижений | >60% | Вовлечение |
| Конверсия IAP | 3-5% | Монетизация |
| ARPU (средний доход на юзера) | $0.5-2 | Бизнес |
| Среднее кол-во глав / сессию | 2-3 | Контент |
| % использования премиум-выборов | 20-30% | Ценность алмазов |

---

## 🎮 Сравнение с конкурентами

| Фича | Клуб Романтики | Choices | Amoria |
|---|---|---|---|
| Достижения | ~50 | Нет | 34 (план) |
| Daily rewards | 7-дневный цикл | Нет | 7-дневный цикл ✅ |
| VIP | Да | Да | Да ✅ |
| Стартовый набор | Да | Да | Да ✅ |
| CG галерея | Да | Нет | Да ✅ |
| Гардероб | Да | Частично | Да ✅ |
| Локализация | 10+ языков | 5+ языков | 11 языков ✅ |
