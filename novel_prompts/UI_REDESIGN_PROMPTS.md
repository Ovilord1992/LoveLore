# Amoria — UI Redesign V2: Минималистичный европейский стиль

> Концепция: **«Красивая книга, которую приятно держать в руках»**
> Не мобильная игра, а элегантное приложение для чтения интерактивных историй.
> Вдохновение: Wattpad Premium, Apple Books, The New Yorker, Kindle, европейские инди-новеллы.

---

## Философия дизайна

**Ключевые принципы:**
1. **Воздух** — много свободного пространства, контент дышит
2. **Типографика как основа** — красивые шрифты вместо иконок и градиентов
3. **Приглушённая палитра** — тёплые нейтральные тона, один тонкий акцент
4. **Обложки говорят сами** — крупные иллюстрации, минимум UI поверх них
5. **Без шума** — никаких эмодзи в интерфейсе, никаких кричащих бейджей, никакого визуального спама
6. **Европейская эстетика** — книжная культура, не аниме-гейминг

**Чего НЕ будет:**
- Градиентных кнопок в стиле казино
- Эмодзи-иконок (💎⚡🔥) — заменяются на тонкие пиктограммы
- Неоновых свечений и shimmer-эффектов
- Перегруженных карточек с 5 бейджами одновременно
- Кричащих «КУПИ!» баннеров

---

## Дизайн-система V2

**Цветовая палитра:**

```
Основной фон (тёмная тема):
  Background:     #121218  — почти чёрный, тёплый
  Surface:        #1C1C24  — карточки, панели
  Elevated:       #26262E  — приподнятые элементы
  
Основной фон (светлая тема):
  Background:     #FAFAF8  — тёплый белый, кремовый
  Surface:        #FFFFFF  — карточки
  Elevated:       #F2F0ED  — разделители, подложки

Текст:
  Primary:        #E8E6E1  (тёмная) / #1A1A1A (светлая)
  Secondary:      #9B9A97  — мягкий серый для подписей
  Muted:          #5C5B58  — неактивные элементы

Акцент (один, сдержанный):
  Accent:         #C2785C  — тёплая терракота (кнопки, ссылки, активные элементы)
  Accent soft:    #C2785C / 15% opacity — фон акцентных чипов

Дополнительные:
  Success:        #6B8F71  — приглушённый зелёный
  Warning:        #C9A961  — тёплое золото
  Premium:        #8B7355  — благородный бронзовый
  Divider:        #FFFFFF / 6% (тёмная) или #000000 / 6% (светлая)
```

**Типографика:**

```
Заголовки:      Playfair Display (serif) — книжная элегантность
  H1: 32pt / 600 weight / tracking -0.5
  H2: 24pt / 600 weight
  H3: 18pt / 500 weight

Основной текст: Inter или Source Sans 3 (sans-serif) — чистая читаемость
  Body:   16pt / 400 weight / line-height 1.6
  Caption: 13pt / 400 weight
  Label:  11pt / 500 weight / uppercase / tracking +1.5

Диалоги в игре: Literata (serif) — тёплая, книжная, для длинного чтения
  Dialogue: 18pt / 400 / line-height 1.7
  Speaker:  14pt / 600 / serif
```

**Скругления:**

```
Маленькие:  8px  — чипы, мелкие элементы
Средние:    12px — карточки, кнопки, поля ввода
Большие:    16px — модальные окна, дно-шторки
```

**Тени (только светлая тема):**

```
Card:    0 1px 3px rgba(0,0,0,0.06)
Lifted:  0 4px 12px rgba(0,0,0,0.08)
Modal:   0 8px 32px rgba(0,0,0,0.12)
```

**Анимации:**

```
Длительность:   200ms (микро), 350ms (переходы), 500ms (модальные)
Кривая:         ease-out (появление), ease-in-out (переходы)
Принцип:        тонкие, почти незаметные. Fade, не bounce.
```

---

## Экраны

---

### 1. SPLASH SCREEN

```
Mobile app splash screen, minimal design.

Solid background #121218 (warm near-black). Centered: the word
"amoria" in lowercase, Playfair Display serif font, cream-white
#E8E6E1, 36pt, letter-spacing +2px. Below the name — a thin
horizontal line (40px wide, 1px, #C2785C terracotta) as a subtle
decorative divider. Nothing else.

No icons, no illustrations, no loading bars. Just typography on
dark. Quiet, confident, editorial.

9:16 aspect ratio.
```

---

### 2. ONBOARDING — Слайд 1: «Истории, в которых решаешь ты»

```
Mobile app onboarding screen, first of three. Minimalist, editorial.

Full-screen soft watercolor-style illustration (NOT anime):
a woman's silhouette reading by a tall window, warm afternoon light
streaming in, European city rooftops visible outside. Muted warm
palette — soft ochre, dusty rose, warm grey. Painterly, not
cartoonish.

Bottom third: semi-transparent dark gradient overlay (#121218 at 80%).
Over it, left-aligned text:
  "Истории, в которых" — 14pt, Inter, #9B9A97
  "решаешь ты" — 32pt, Playfair Display, #E8E6E1

Three thin dots at bottom center, first dot solid #C2785C,
others #5C5B58. No buttons yet — swipe to continue.

9:16 aspect ratio. Feels like a book cover, not a game tutorial.
```

---

### 3. ONBOARDING — Слайд 2: «Каждый выбор меняет финал»

```
Mobile app onboarding, slide 2 of 3. Minimalist.

Full-screen soft illustration: an old European writing desk with
a quill pen, two sealed letters lying on it, candlelight, evening
window behind. Watercolor style, muted warm tones — amber, ivory,
deep burgundy. No people visible.

Bottom third with dark gradient overlay:
  "Каждый выбор" — 14pt, Inter, grey
  "меняет финал" — 32pt, Playfair Display, cream-white

Second dot active (terracotta). Swipe indicator.

9:16 aspect ratio. Atmospheric, literary, intimate.
```

---

### 4. ONBOARDING — Слайд 3: «Начни свою историю»

```
Mobile app onboarding, slide 3 of 3. Minimalist.

Full-screen illustration: two people walking along a European
embankment at golden hour, seen from behind, warm light, soft
bokeh of city lights ahead. Painterly watercolor, NOT anime.
Warm tones — gold, soft pink sky, grey stone of the embankment.

Bottom third with dark overlay:
  "Начни свою" — 14pt, grey
  "историю" — 32pt, Playfair Display, cream

Third dot active. Below the text: a single button — rounded
rectangle (12px radius), solid #C2785C fill, text "Начать"
in white, 16pt Inter medium. Button width ~200px, centered.

9:16 aspect ratio. Warm, inviting, not aggressive.
```

---

### 5. ГЛАВНЫЙ ЭКРАН (Home)

```
Mobile app home screen for a reading/visual novel app. Minimalist
dark theme, editorial design. NO anime, NO gaming aesthetic.

HEADER (top, simple):
  Left: "amoria" in lowercase Playfair Display, 20pt, cream.
  Right: a small bell outline icon (#9B9A97) — notifications.
  Below: thin 1px divider line (#FFFFFF at 6%).

STATUS BAR (subtle, under header):
  A single unobtrusive row, small text:
  Left: diamond outline icon + "245" — 13pt, #9B9A97
  Thin vertical separator.
  Right: lightning outline icon + "3/5" — 13pt, #9B9A97
  Whole row sits inside a subtle rounded pill (#1C1C24).
  Not prominent — just info, not a call to action.

SECTION "Продолжить" (if user has saves):
  Section label: "ПРОДОЛЖИТЬ" — 11pt, uppercase, Inter,
  letter-spacing +1.5, #9B9A97. Left-aligned, 20px padding.

  Horizontal scroll of cards (260px wide, 160px tall):
  Each card = novel cover image filling the card, rounded 12px.
  A thin frosted-glass bar at the bottom (16px tall) with:
    — title in white, 13pt, one line, left-aligned
    — thin progress line underneath (terracotta #C2785C, e.g. 60%)
  No badges, no ratings, no extra text. Just image + title + progress.

SECTION "Новое":
  Label: "НОВОЕ" — same uppercase style.
  Vertical list of 2-3 cards:
  Each card = full-width, 200px tall, rounded 12px.
  Cover image fills card. Bottom gradient overlay (dark, 40%).
  Over the gradient:
    — Title: Playfair Display, 20pt, white, 1 line
    — Author: Inter, 13pt, #9B9A97, 1 line
    — Small chip: "Романтика" — 11pt, uppercase, terracotta text,
      terracotta/15% background, rounded 8px. Just one genre tag.
  Nothing else on the card. Clean.

SECTION "Все истории":
  Label: "ВСЕ ИСТОРИИ" + right-aligned "Все →" link in #C2785C.
  Horizontal scroll of smaller cover thumbnails (120x170px),
  only the cover image, rounded 12px. Title below each (13pt,
  white, 1 line). No ratings, no badges.

BOTTOM NAVIGATION:
  4 icons, line-style (not filled), on #121218:
  Book (home, active — #C2785C), Search, Diamond (shop), Person (profile).
  Labels below each: "Главная", "Каталог", "Магазин", "Профиль" — 10pt.
  Active label also terracotta. Others #5C5B58.
  Thin top border (#FFFFFF at 6%).

Overall feel: a curated bookshelf, not an app store. Quiet,
elegant, spacious. 9:16 aspect ratio.
```

---

### 6. КАТАЛОГ (Catalog / Search)

```
Mobile app catalog screen for novel reading app. Minimalist dark.

TOP: "Каталог" — 24pt, Playfair Display, cream. Left-aligned.

SEARCH FIELD: rounded rectangle (12px), #1C1C24 background,
  left magnifying glass icon (#5C5B58), placeholder "Название
  или автор..." in #5C5B58, 15pt Inter. Full width minus 20px
  horizontal padding.

GENRE FILTER (horizontal scroll, below search):
  Rounded pill chips, 12px radius:
  "Все" — active: #C2785C background, white text
  "Романтика" — inactive: #1C1C24 bg, #9B9A97 text, 1px border #FFFFFF/10%
  "Фэнтези", "Драма", "Мистика", "Детектив"
  No emoji. Just clean text labels. 13pt Inter medium.

SORT (small, right-aligned):
  "По популярности ▾" — 12pt, #9B9A97. Dropdown.

RESULTS (vertical list):
  Each item: horizontal layout, 80px tall.
    Left: small cover thumbnail (56x80px, rounded 8px)
    Right column:
      Title — 16pt, Inter medium, white. 1 line.
      Author — 13pt, #9B9A97. 1 line.
      Bottom row: "Романтика · 12 глав" — 12pt, #5C5B58
    No badges, no ratings, no hearts, no price tags.
    
  Thin separator line between items (#FFFFFF at 4%).

  If story is completed: small "Завершена" text in #6B8F71 (green)
  next to chapter count. That's the only status indicator.

EMPTY STATE (if no results):
  Centered: "Ничего не нашлось" — 16pt, #5C5B58
  Subtitle: "Попробуйте другой запрос" — 13pt, #5C5B58

9:16. Clean list, scannable, zero visual noise.
```

---

### 7. СТРАНИЦА ИСТОРИИ (Novel Detail)

```
Mobile app novel detail/about screen. Minimalist editorial dark.

COVER (top, 55% of screen height):
  Full-width cover illustration, top-to-bottom.
  European-style painted cover (watercolor/oil, NOT anime).
  Bottom: long gradient from transparent to #121218 (smooth, 40%).
  Top-left: back arrow icon, thin white, over the image.
  Top-right: share icon (arrow-up-from-box), thin white.

CONTENT (scrollable below cover, on #121218):
  Title: "Тени Петербурга" — 28pt, Playfair Display, cream.
  Author: "Анна Мирова" — 14pt, Inter, #C2785C. Below title.
  
  Spacing 16px.
  
  Genre tags (1-2 max):
  "Романтика" "Мистика" — pill chips, #1C1C24 bg, #9B9A97 text,
  1px border, rounded 8px. Small, quiet.

  Spacing 20px.

  Description:
  3-4 lines of text — 16pt, Inter, #9B9A97, line-height 1.6.
  "Показать полностью" link in #C2785C at end if truncated.

  Spacing 20px.

  Info row (one simple line of text, not icons-in-boxes):
  "12 глав · ~15 мин на главу · Обновлено вчера"
  13pt, Inter, #5C5B58. Just text. No icons.

  Spacing 24px.

  CHAPTER LIST:
  Section label: "ГЛАВЫ" — 11pt uppercase #9B9A97
  Numbered list, each row:
    "1. Прибытие" — 15pt Inter, white. Right side: thin check ✓ (#6B8F71) if done.
    "2. Тайное приглашение" — same, with ✓
    "3. Ночь в особняке" — no check (current chapter)
    "4. Развязка" — 15pt, #5C5B58 (locked, dimmed text)
  Thin separators. No lock icons, no elaborate states.

  Spacing 32px.

  MAIN BUTTON (full width):
  Solid #C2785C, rounded 12px, 52px height.
  "Продолжить" or "Начать чтение" — 16pt Inter medium, white. Centered.
  
  If save exists: secondary button below —
  "Начать сначала" — text-only button, 14pt, #9B9A97. No border.

  Spacing 40px bottom.

9:16. Feels like opening a book. Calm, focused on the story.
```

---

### 8. ИГРОВОЙ ЭКРАН — Диалог (Game Screen: Dialogue)

```
Mobile app game/reading screen for visual novel. FULL IMMERSION.
Minimalist HUD. European painted art style, NOT anime.

BACKGROUND: oil-painting-style illustration of a St. Petersburg
embankment at dusk. Warm street lamps, Neva river, hazy sky.
Muted palette — slate blue, warm amber, grey stone. Atmospheric,
cinematic, European.

CHARACTER: a man painted in the same art style (NOT anime sprite),
visible from chest up, positioned right-of-center. Dark hair,
thoughtful expression, wearing a dark coat. Painted, not cell-shaded.
Semi-transparent blend into the background.

TOP HUD (minimal, nearly invisible):
  Thin progress bar across full width at very top — a 2px line,
  #C2785C, ~40% filled. That's it. No chapter title cluttering
  the image.

DIALOGUE AREA (bottom 25%):
  No box border. Just a gentle vertical gradient from transparent
  to #121218 (starting at ~75% screen height).
  
  Over the gradient:
  Speaker name: "Алексей" — 14pt, Playfair Display, #C2785C.
  Dialogue text: "Я давно хотел тебе кое-что сказать..."
  18pt, Literata serif, #E8E6E1, line-height 1.7.
  
  Bottom-right: small "›" chevron, #5C5B58, pulsing gently
  to indicate "tap to continue".

  No avatar circle, no box, no gradient card. Text floats
  naturally over the darkened bottom of the scene.

MENU ACCESS: single thin "≡" icon top-right, #9B9A97.
  Only visible for 2 seconds after tap, then fades out.

9:16. Maximum immersion. The UI disappears. You read a story,
not interact with an app.
```

---

### 9. ИГРОВОЙ ЭКРАН — Момент выбора (Choice)

```
Mobile app game screen showing a CHOICE moment. Minimalist.

Same background and character. Character expression: expectant.

The dialogue area shows the last line:
"Так что скажешь?" — 18pt, Literata, cream.

CHOICE OPTIONS appear below, centered, with gentle fade-in
(200ms stagger between each):

Choice 1:
  Full-width rounded rectangle (12px), #1C1C24 background,
  1px border #FFFFFF/10%. Padding 16px.
  Text: "Мне нужно подумать..." — 16pt, Inter, #E8E6E1.
  Left-aligned.

Choice 2:
  Same style.
  Text: "Я тоже это чувствую" — 16pt, Inter, #E8E6E1.

Choice 3 (premium):
  Same shape but border is 1px #C2785C (terracotta).
  Text: "Поцеловать его" — 16pt, Inter, #E8E6E1.
  Right side: small text "15 ◇" — 13pt, #C2785C.
  (◇ = small diamond outline, not emoji)
  That's the only indicator it's premium — the border and cost.

No sparkles, no glow, no gradient borders. Premium is distinct
but elegant — a single warm border line.

Spacing between choices: 8px. All three centered in lower 40%.

9:16. Choices feel weighty, not gamified.
```

---

### 10. МЕНЮ ПАУЗЫ (Pause Menu)

```
Mobile app pause overlay for visual novel. Minimalist.

Background: the game screen, gaussian blurred, dimmed to 30% brightness.

CENTER: no modal box. Just a vertical list of text options,
centered on screen, floating over the blur:

  "Сохранить" — 18pt, Inter medium, #E8E6E1
  "Загрузить" — 18pt, #E8E6E1
  "Отношения" — 18pt, #E8E6E1
  "Настройки" — 18pt, #E8E6E1
  "Выйти" — 18pt, #9B9A97 (dimmer, less prominent)

Each option separated by 24px. No icons. No boxes.
Just centered text on blurred background.

Below the list, 40px spacing, then:
  "Вернуться" — 14pt, #C2785C (terracotta). Tap to dismiss.

Top center: "amoria" in 14pt Playfair, #5C5B58. Decorative.

9:16. Calm, literary pause. Like a bookmark page.
```

---

### 11. ЛОГ ДИАЛОГОВ (Dialogue Log)

```
Mobile app dialogue history screen. Minimal dark theme.

TOP BAR: back arrow + "Лог" — 18pt Inter medium, cream.

Full-screen scrollable text, styled like a printed page:

Each entry is left-aligned text with generous line spacing:

  Speaker entries:
  "Алексей" — 13pt, Inter 500, #C2785C. Left-aligned.
  "Я давно хотел тебе кое-что сказать..." — 16pt, Literata,
  #E8E6E1, line-height 1.7. Below the name.
  
  Spacing 20px.

  Narration entries:
  No name. Just italic text:
  "Сердце забилось быстрее." — 16pt, Literata italic, #9B9A97.

  Spacing 20px.

  Choice entries:
  "→ Я тоже это чувствую" — 15pt, Inter, #C2785C.
  (The → arrow indicates it was a player choice.)

Simple, readable, like reading a manuscript. No avatars,
no timestamps, no borders. Just text.

9:16.
```

---

### 12. ОТНОШЕНИЯ (Relationship Screen)

```
Mobile app character relationship screen. Minimalist.

TOP BAR: back arrow + "Персонажи" — 18pt, Playfair, cream.

VERTICAL LIST of characters:

Each character block:
  Name: "Алексей" — 20pt, Playfair Display, cream.
  Subtitle: "Загадочный незнакомец" — 13pt, Inter, #9B9A97.
  
  Below: thin horizontal bar, full width.
  Background of bar: #1C1C24. Filled portion: #C2785C (terracotta).
  Width represents relationship level (e.g. 70%).
  Right of bar: "35" — 13pt, #9B9A97 (numeric value).
  Label below bar: "Близость" — 11pt, #5C5B58.

  Spacing 32px between characters.

Second character:
  "Дмитрий" — same layout, bar at 45%.
  
Third character:
  "Каэль" — bar at 25%.

No icons, no hearts, no color coding by emotion type.
One relationship metric per character. Clean and clear.

Bottom note: "Ваши выборы влияют на отношения" — 13pt,
Inter italic, #5C5B58. Centered.

9:16. Data visualization as simple as possible.
```

---

### 13. МАГАЗИН (Shop)

```
Mobile app minimal shop/store screen for novel app. Dark theme.
Not aggressive, not gamified — feels like a polite bookstore.

TOP BAR: "Магазин" — 24pt, Playfair Display, cream.
Right: current balance — "◇ 245" — 14pt, #9B9A97 (diamond outline icon).

SECTION "Подписка" (top, most important):
  A single elegant card, full width, rounded 12px.
  Background: #1C1C24. Left: a thin vertical accent line, #C2785C.
  Inside:
    "Amoria Premium" — 18pt, Playfair, cream.
    "Безлимитное чтение · Без рекламы · Бонусные алмазы" — 13pt, #9B9A97.
    Price: "$4.99/мес" — 14pt, Inter, #C2785C.
    Right side: "Попробовать" — text button, #C2785C.

SECTION "Алмазы":
  Label: "АЛМАЗЫ" — 11pt, uppercase, #9B9A97.
  Vertical list of 4 options, each a simple row:
    Left: "20 алмазов" — 16pt, Inter, cream.
    Right: "$0.99" — 14pt, Inter, #C2785C.
    Thin separator below.
  
  One row has a small label "Популярное" — 10pt, #C2785C,
  next to the title. That's the only badge.

  "60 алмазов"  — $2.99 (Популярное)
  "150 алмазов" — $5.99
  "500 алмазов" — $14.99

SECTION "Бесплатно":
  Label: "БЕСПЛАТНО" — 11pt, uppercase, #9B9A97.
  Row: "Посмотреть рекламу" — 15pt, cream.
    Right: "+3 ◇" — 13pt, #C2785C. Then: "2 из 5" — 12pt, #5C5B58.
  Row: "Ежедневная награда" — with status "Доступно" or "Завтра".

Bottom: "Восстановить покупки" — text link, 13pt, #5C5B58.

9:16. A price list, not a casino. Respectful, clear.
```

---

### 14. ПРОФИЛЬ (Profile)

```
Mobile app profile screen. Minimal dark theme.

TOP: large centered layout.
  
  Avatar: 80px circle, solid fill with muted color (#26262E),
  containing user's initial letter in Playfair Display, 32pt, cream.
  (No emoji, no gradient ring. Just a letter in a circle.)

  Name: "Алиса" — 22pt, Playfair Display, cream. Below avatar.
  
  Subtitle: "12 историй прочитано" — 13pt, Inter, #9B9A97.

Spacing 32px.

SECTION "Мои истории":
  Label: "МОИ ИСТОРИИ" — 11pt uppercase, #9B9A97.
  Vertical list:
    Cover (40x56px, rounded 6px) + "Тени Петербурга" — 15pt, cream.
    Right: "75%" — 13pt, #9B9A97. Thin progress bar below text.
  2-3 items.

SECTION "Галерея":
  Label: "ГАЛЕРЕЯ" — 11pt.
  "8 из 24 иллюстраций" — 13pt, #9B9A97.
  "Открыть →" — text link, #C2785C.

SECTION "Статистика":
  Label: "СТАТИСТИКА" — 11pt.
  Simple two-column text (no cards, no icons):
    "Глав пройдено       47"
    "Выборов сделано      89"
    "Достижений            5"
  15pt Inter, cream left, #9B9A97 right. Like a ledger.

SECTION "Аккаунт":
  Label: "АККАУНТ" — 11pt.
  "user@email.com" — 14pt, cream.
  "Синхронизировано" — 13pt, #6B8F71.
  "Выйти" — text link, 13pt, #9B9A97.

Bottom: "Настройки" — text link, 14pt, #C2785C.

9:16. Like a library card. Minimal, functional, personal.
```

---

### 15. НАСТРОЙКИ (Settings)

```
Mobile app settings screen. Minimal dark theme.

TOP BAR: back arrow + "Настройки" — 18pt, Inter medium, cream.

Simple list of setting rows, grouped by thin label headers:

"ЧТЕНИЕ" — 11pt, uppercase, #9B9A97.
  "Скорость текста" — slider row. Label 15pt cream left,
    thin slider right (#1C1C24 track, #C2785C thumb/fill).
  "Автопрокрутка" — toggle row. Label left, toggle right
    (off: #26262E, on: #C2785C). Small, iOS-style.
  "Размер шрифта" — row with "A" and "A+" on a segmented control.

"ЗВУК" — label.
  "Музыка" — slider.
  "Эффекты" — slider.

"ОФОРМЛЕНИЕ" — label.
  "Тема" — row with three text options: "Тёмная" (active, underlined
    in #C2785C), "Светлая", "Системная" — 14pt each.
  "Язык" — row: "Русский ▾" — dropdown.

"ПРИЛОЖЕНИЕ" — label.
  "Уведомления" — toggle.
  "Очистить кеш" — row, right: "45 МБ" in #9B9A97.
  "О приложении" — row, right: "v2.1" in #5C5B58.

Thin 1px separators between rows (#FFFFFF at 4%).

9:16. Standard settings, nothing unusual. Clean.
```

---

### 16. ЕЖЕДНЕВНАЯ НАГРАДА (Daily Reward)

```
Mobile app daily reward popup. Minimalist, not gamified.

Background: dimmed app (60% dark overlay), no blur.

CENTER: a card, rounded 16px, #1C1C24 background, centered.
Width 85% of screen. No decorations, no sparkles.

Inside the card:

  "День 5" — 24pt, Playfair Display, cream. Centered.
  "из 7" — 14pt, Inter, #9B9A97. Below.

  Spacing 20px.

  Progress indicator: 7 small circles in a row (12px each).
  Days 1-4: filled #C2785C (solid terracotta).
  Day 5: filled #C2785C with a subtle ring/border (current).
  Days 6-7: outlined, #26262E fill, #5C5B58 border.
  
  Spacing 16px.

  Reward: "+5 алмазов" — 18pt, Inter medium, #C2785C. Centered.

  Spacing 24px.

  Button: solid #C2785C, full card width minus padding, rounded 12px.
  "Забрать" — 16pt, Inter medium, white.

  Below button: "Заходите каждый день" — 12pt, #5C5B58. Centered.

Card has no border. Subtle shadow in light theme, none in dark.

9:16. Reward without the circus. Clean, appreciative.
```

---

### 17. УВЕДОМЛЕНИЯ (Notifications)

```
Mobile app notification screen. Minimal dark.

TOP BAR: back arrow + "Уведомления" — 18pt, cream.

VERTICAL LIST:

Each notification is a text block (no cards, no colored accents):
  
  Unread:
  "Новая глава: Тени Петербурга" — 15pt, Inter medium, cream.
  "Глава 5 теперь доступна" — 13pt, #9B9A97.
  "2 часа назад" — 12pt, #5C5B58.
  Left edge: tiny 4px-wide vertical terracotta line (unread indicator).

  Read:
  Same but title in #9B9A97 (dimmer). No left line.

  Spacing 20px between items. Thin separator lines.

EMPTY STATE:
  "Пока ничего нового" — 16pt, #5C5B58. Centered.
  No illustration. Just text.

9:16. Quiet, informative.
```

---

### 18. АВТОРИЗАЦИЯ (Auth Screen)

```
Mobile app login screen. Minimal dark theme.

TOP (40% of screen): empty dark space with centered:
  "amoria" — 28pt, Playfair Display, cream. Letter-spacing +2.
  Below: thin line (40px, 1px, #C2785C).
  Below: "Сохраняйте прогресс" — 14pt, Inter, #9B9A97.

BOTTOM (60%):
  
  TAB: "Вход" | "Регистрация" — 15pt, Inter.
  Active tab: cream text, terracotta underline.
  Inactive: #5C5B58.

  Form fields (stacked):
  Email — rounded input (12px), #1C1C24 bg, #5C5B58 placeholder,
    cream text when typing. 1px border #FFFFFF/6%. No icon.
  Password — same style. Small eye toggle icon right.

  "Забыли пароль?" — 13pt, #C2785C, right-aligned.

  Button: "Войти" — solid #C2785C, full width, rounded 12px, 48px tall.
  White text, 16pt Inter medium.

  Divider: thin line with "или" centered, #5C5B58.

  Social buttons (horizontal):
  "Google" — rounded 12px, #1C1C24 bg, 1px border, Google "G" logo, text.
  "Apple" — same style, Apple logo, text.
  Both 48px tall, equal width, 8px gap.

  Bottom: "Продолжить без аккаунта" — 13pt, #5C5B58.

9:16. Clean auth, minimal friction.
```

---

### 19. ГАЛЕРЕЯ CG

```
Mobile app CG/illustration gallery. Minimal dark.

TOP BAR: back arrow + "Галерея" — 18pt, Playfair, cream.
Right: "8/24" — 14pt, #9B9A97.

FILTER: small text tabs — "Все" (active, underlined #C2785C),
  novel names in #9B9A97.

GRID (2 columns, square cells):
  Unlocked: European-style painted illustrations (oil/watercolor,
  NOT anime). Romantic scenes. Rounded 8px corners. No overlays.
  
  Locked: same size squares, #1C1C24 solid fill with a small
  outline lock icon (20px, #5C5B58) centered. No blur effect,
  no question marks. Just a dark placeholder with a lock.

Tapping unlocked CG opens fullscreen view with black background.

9:16. A personal art collection. Simple, elegant.
```

---

### 20. СВЕТЛАЯ ТЕМА — Главный экран

```
Mobile app home screen, LIGHT THEME variant. Minimalist, editorial.

Same layout as dark home screen but:

  Background: #FAFAF8 (warm cream white)
  Surface/cards: #FFFFFF with subtle shadow (0 1px 3px rgba(0,0,0,0.06))
  Text primary: #1A1A1A
  Text secondary: #7A7A78
  Text muted: #AEADAB
  Accent: same #C2785C (terracotta)
  Dividers: #000000 at 6%
  Bottom nav: #FFFFFF bg, thin top shadow
  
  Cards have white background, gentle shadow, warm feel.
  Cover images still provide color.
  Feels like a well-designed reading app on paper.

9:16. Airy, warm, bookish. Like reading on a café table.
```

---

### 21. ПЛАНШЕТ (iPad Layout)

```
Mobile app tablet layout, landscape, dark theme. Minimalist.

NO sidebar navigation. Instead:

Full-screen content area, wider breathing room.
Top bar spans full width: "amoria" left, navigation links center
  ("Главная · Каталог · Магазин · Профиль" — text links,
  active one underlined in #C2785C), currency right.

Content: novel cards in 3-4 column grid, larger covers.
More whitespace between elements. Like a magazine spread.

4:3 aspect ratio (iPad). Elegant, spacious, editorial.
```

---

### 22. ПУСТЫЕ СОСТОЯНИЯ (Empty States)

```
Mobile app empty state designs. Minimalist. Dark theme. Three variants.

Variant A — "Нет избранного":
  Centered on screen:
  "—" (em-dash) — 48pt, Playfair Display, #26262E. Decorative.
  "У вас пока нет избранных историй" — 16pt, Inter, #5C5B58.
  "Перейти в каталог" — 14pt, #C2785C, underlined.
  No illustrations. Just typography.

Variant B — "Пустой каталог":
  "Ничего не нашлось" — 16pt, #5C5B58.
  "Попробуйте другой запрос" — 13pt, #5C5B58.

Variant C — "Нет уведомлений":
  "Всё прочитано" — 16pt, #5C5B58.

All variants use only text, centered. No cartoon illustrations,
no emoji, no sad-face icons.

9:16.
```

---

### 23. SKELETON LOADING

```
Mobile app skeleton/loading state for catalog screen. Dark theme.

Same layout structure as catalog but content replaced with
solid #1C1C24 rectangles (no shimmer animation, no gradient sweep):

  Search bar: rounded rectangle, #1C1C24
  Genre chips: 4 small rounded pills, #1C1C24, slightly different widths
  List items: each has small rectangle (thumbnail) left, two thin
    horizontal bars right (title + author), different widths

Static, not animated. Or very subtle opacity pulse (0.5 to 1.0,
2s duration, ease-in-out). Not a flashy shimmer — a quiet breathe.

9:16. Patient, unhurried loading.
```

---

## Сравнение V1 и V2

| Аспект | V1 (Азиатский) | V2 (Европейский) |
|--------|----------------|-------------------|
| Стиль арта | Аниме, cell-shading | Масло, акварель, живопись |
| Палитра | Яркий розовый + фиолетовый неон | Тёплая терракота + нейтральные тона |
| Шрифты | Sans-serif (Nunito) | Serif заголовки (Playfair) + sans тело |
| Иконки | Emoji (💎⚡🔥🏆) | Тонкие outline пиктограммы |
| Карточки | Бейджи, рейтинги, прогрессы, сердечки | Обложка + название. Минимум |
| Монетизация | Кричащие баннеры, shimmer, countdown | Тихий прайс-лист |
| Анимации | Confetti, bounce, shimmer, glow | Fade, opacity. Почти незаметные |
| Игровой экран | Glassmorphism box, аватар, HUD | Текст на градиенте, UI исчезает |
| Выборы | Градиентные рамки, sparkle | Тонкая цветная рамка, мелкий ценник |
| Пустые состояния | Иллюстрация + emoji | Одна строка текста |
| Навигация | Filled icons + emoji labels | Outline icons + text labels |
| Ощущение | Мобильная игра для подростков | Приложение для чтения для взрослых |

---

## Рекомендации по арт-стилю

Для обложек и CG-артов в европейском стиле:

```
STYLE REFERENCE (использовать во всех промптах для арта):

"European visual novel illustration. Painterly style —
oil painting meets digital art. NOT anime, NOT cell-shaded.
Realistic proportions, soft brushwork, visible paint texture.
Muted warm palette: ochre, dusty rose, slate blue, ivory, amber.
Cinematic composition, atmospheric lighting.
Think: book cover illustration, classical European art direction.
References: Dishonored concept art, Florence (game), Old Man's Journey,
Gris (game), Gorogoa."
```
