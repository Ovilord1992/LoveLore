# Amoria — UI Redesign V3 (Global): красивый, практичный, «понравится всем»

> Цель V3: **не “аниме‑новелла” и не “стерильный минимализм”**, а современный, тёплый, понятный продукт для чтения интерактивных историй.
> Подходит для **US / EU / RU** аудитории: читаемо, привычно, без визуального шума, но достаточно «живое», чтобы чувствовалась игра.

---

## 0) Что показывает рынок (срез топ‑категории story apps)

По описаниям и позиционированию крупных приложений класса **Choices / Episode / Chapters** видно, что рынок продаёт не интерфейс, а **“бесконечную библиотеку + регулярные апдейты + кастомизацию + VIP”**:

- **Библиотека историй** с жанрами и постоянными обновлениями/главами (ритм: «каждую неделю есть новый контент»)
- **Персонализация** (аватар/внешность/одежда) как удержание
- **Монетизация через VIP + валюты** (алмазы/ключи/билеты), плюс «ограниченные предложения»
- **Комьюнити‑механики** (у Episode — book clubs / челленджи, у других — события, коллекции)

Что важно по UX‑трендам для чтения (все рынки):
- **скорость и читаемость** (типографика, контраст, line height)
- **простая навигация** (4 таба, clear “Continue”)
- **умный discovery** (поиск + фильтры + подборки)
- **ненавязчивая монетизация** (магазин не должен ломать доверие)

---

## 1) Дизайн‑направление: Global Modern Romance

**Суть:** визуально — как современный стриминговый сервис для историй (Netflix‑логика секций), но в эстетике книжного приложения.

**Ключевые принципы:**
1. **Content-first:** обложка/текст важнее UI
2. **Стабильная архитектура:** пользователь всегда знает где «продолжить», где «найти», где «купить», где «профиль»
3. **Один акцент + нейтрали:** спокойная палитра, без неона
4. **Премиум без агрессии:** VIP и покупки есть, но выглядят как «upgrade», а не как «донат»
5. **Одинаково хорошо в RU/EN:** шрифты и плотность интерфейса рассчитаны на длинные русские строки

---

## 2) Дизайн-система V3

### 2.1 Цвета

**Темная тема (основная):**
- Background: `#12131A`
- Surface: `#1A1C24`
- SurfaceElevated: `#222533`
- Divider: `rgba(255,255,255,0.08)`

**Светлая тема (вторичная, но полноценная):**
- Background: `#F7F6F3`
- Surface: `#FFFFFF`
- SurfaceElevated: `#F0EFEB`
- Divider: `rgba(0,0,0,0.08)`

**Текст:**
- Primary (dark): `#F1F0EC`
- Secondary (dark): `rgba(241,240,236,0.72)`
- Muted (dark): `rgba(241,240,236,0.45)`
- Primary (light): `#1B1D26`
- Secondary (light): `rgba(27,29,38,0.70)`

**Акцент (универсальный, “всем нравится”):**
- Accent: `#E35C7A` (приглушённая роза, не неон)
- AccentSoft: `rgba(227,92,122,0.16)`

**Статусы:**
- Success: `#59B37A`
- Warning: `#D6B15E`
- Premium: `#B08D57` (бронза)

### 2.2 Типографика (безопасно для кириллицы)

- UI / Body: **Inter** (или SF Pro на iOS)
- Заголовки / обложечные: **Fraunces** *или* **Playfair Display** (оба с кириллицей проверять; если нужно 100% — **Noto Serif**)
- Текст диалогов (игровой): **Source Serif 4** или **Literata**

Рекомендованные размеры:
- H1: 28–32
- H2: 20–22
- Body: 16
- Caption: 12–13

### 2.3 Радиусы и сетка

- Radius: 12 (карточки), 14 (кнопки), 10 (чипы)
- Spacing: 8/12/16/24
- Cards: всегда одинаковая логика отступов (предсказуемость)

### 2.4 Иконки

- Только **outline** (Material Symbols Rounded / SF Symbols)
- Никаких emoji в интерфейсе

---

## 3) Информационная архитектура (что понравится US/EU/RU)

**Bottom tabs (4):**
1) Home
2) Explore
3) Shop
4) Profile

**Home (главная):**
- “Continue” (первый экранный блок)
- Featured carousel (1 карточка на фокус)
- “For you” (по тегам)
- “New chapters” (обновления)
- “Popular” (соц.доказательство)

**Explore (каталог):**
- Search
- Genre chips
- Filters (status: ongoing/completed, language)
- Sort (popular/new/rating/updated)
- Results list (понятная, быстрая)

**Novel detail:**
- Cover hero
- Title/author/tags
- CTA: Continue / Start
- Chapters list
- Ratings + короткие отзывы (соц.доверие)

**Reader/Game:**
- Максимум “reading”, минимум “UI”
- Меню по tap / swipe
- Log / text size / auto-play / skip

---

## 4) Практичные решения под три сегмента

**US:** любят персональные подборки, “New this week”, подписку как «upgrade». Делай “For you”, “Popular this week”, аккуратные review snippets.

**EU:** ценят приватность/спокойствие/типографику. Избегай агрессии, дай light theme и хороший reader.

**RU:** любят “понятно и сразу”: “Продолжить”, “Новое”, “Завершено”, меньше скрытых жестов; в каталог — фильтры и сортировки.

---

# 5) MASTER PROMPT (единый промпт на полный редизайн)

Скопируй и отправь в Figma AI / Midjourney / другой генератор UI.

```
You are a senior product designer.
Redesign the mobile app UI for “Amoria” — an interactive stories / visual novel reader.
Audience: women 16–35, but style must appeal broadly across US/EU/RU.
Goal: beautiful, practical, modern, clean UI (NOT anime, NOT overly minimal), content-first reading experience.

Create a cohesive design system + screen set.

STYLE:
- Global modern romance: warm, premium, calm.
- No emoji icons, no neon gradients, no casino-like shop.
- Use plenty of whitespace, simple rounded cards, outline icons.
- Typography is key: elegant serif for titles, neutral sans for UI.

COLOR THEMES:
- Dark theme primary: background #12131A, surfaces #1A1C24 / #222533.
- Light theme secondary: background #F7F6F3, surfaces white.
- Single accent: muted rose #E35C7A.

TYPOGRAPHY:
- UI: Inter.
- Titles: Fraunces or Noto Serif.
- Reader text: Source Serif 4 or Literata.

NAVIGATION:
Bottom tabs: Home, Explore, Shop, Profile.

SCREENS TO DESIGN (9:16 iPhone):
1) Splash
2) Onboarding (3 slides)
3) Home (continue, featured, for you, new chapters, popular)
4) Explore/catalog (search, genre chips, filters, results list)
5) Novel detail (hero cover, title/author/tags, chapters list, rating & reviews snippet)
6) Reader/game screen (minimal HUD, dialogue text on gradient, menu, choices)
7) Shop (VIP, bundles, free rewards section — calm and clear)
8) Profile (library-like, reading stats, favorites, settings)

COMPONENTS:
- Story cover cards with subtle bottom gradient for text.
- “Continue” cards with thin progress bar.
- Filter chips with selected state using accent soft background.
- Buttons: solid accent for primary, outline for secondary.

OUTPUT:
Provide pixel-perfect UI mockups + a component list.
```

---

# 6) Экранные промпты (если хочешь генерировать по одному)

## 6.1 HOME (главная)

```
Design a mobile app Home screen for Amoria (interactive stories).
Dark theme: #12131A background.
Top bar: Amoria wordmark (serif), right side notification icon.
Section 1: Continue — horizontal cards, each with cover + title + thin progress bar.
Section 2: Featured — single large hero card with cover image and one CTA.
Section 3: For you — 2-row horizontal carousel.
Section 4: New chapters — compact list with “Updated” timestamp.
Bottom nav 4 tabs: Home active with muted rose accent.
Minimal badges, no emojis.
```

## 6.2 EXPLORE (каталог)

```
Design a mobile app Explore screen.
Search bar at top, genre chips below, filter button, sort dropdown.
Results as clean vertical list: cover thumbnail + title + author + short meta line.
Completed stories marked with small green “Completed” text only.
No rating stars on every card; ratings only on detail page.
```

## 6.3 NOVEL DETAIL

```
Design a Novel detail screen.
Hero cover image with gradient overlay.
Title (serif), author, 1-2 tags.
Primary CTA button: Continue/Start.
Chapters list with checkmarks for read chapters.
Below: rating summary + 2 short review snippets.
Calm, editorial, premium.
```

## 6.4 READER / GAME

```
Design the Reader screen.
Full-screen background illustration (European painterly style allowed).
Minimal HUD: thin progress line top, menu icon.
Dialogue text appears on bottom gradient overlay (no heavy box).
Choices: 3 stacked buttons, simple bordered cards; premium choice has only a subtle bronze border and small cost text.
```

## 6.5 SHOP

```
Design a Shop screen that feels trustworthy.
Sections: Subscription (VIP), Bundles, Free rewards.
Use neutral cards, clear prices, no flashing banners.
Primary buttons in accent rose, secondary outline.
```

## 6.6 PROFILE

```
Design a Profile screen like a personal library.
Avatar + name, reading stats, favorites list, reading history.
Settings entry and account sync status.
No gamified fireworks.
```

---

## 7) Как использовать это в Amoria (Flutter)

- V3 отлично ложится на текущую архитектуру: просто меняется тема/компоненты.
- Самый быстрый ROI: **Home (Continue + New chapters)**, **Explore (поиск+фильтры)**, **Reader (типографика)**.
