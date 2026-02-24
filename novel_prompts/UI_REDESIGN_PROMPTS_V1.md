# Amoria — Промпты для редизайна интерфейса

> Подробнейшие промпты для генерации UI-макетов каждого экрана приложения Amoria.
> Используй в Midjourney, DALL-E, Figma AI или аналогичных инструментах.
> Каждый промпт самодостаточен — можно отправлять отдельно.

---

## 🎨 Дизайн-система Amoria

**Цветовая палитра:**
- Primary: `#E91E63` (розовый, акцент)
- Secondary: `#9C27B0` (фиолетовый)
- Background: `#1A1A2E` (тёмно-синий)
- Surface: `#16213E` (карточки)
- Deep surface: `#0F0F1E` (нижняя панель)
- Accent gradient: `#E91E63 → #9C27B0`
- Cyan accent: `#00BCD4` (билеты/таймеры)
- Success: `#4CAF50`
- Text primary: `#FFFFFF`
- Text secondary: `rgba(255,255,255,0.7)`
- Text muted: `rgba(255,255,255,0.38)`

**Типографика:** Google Fonts (Nunito или Inter), округлые шрифты
**Скругления:** 16px (карточки), 20px (кнопки/чипы), 24px (модальные окна)
**Стиль:** Тёмный UI, glassmorphism, градиенты, мягкие тени, мобильное приложение для девушек/женщин

---

## 📱 1. SPLASH SCREEN (Заставка)

```
UI design, mobile app splash screen for "Amoria" — a romantic visual novel app.
Dark background color #1A1A2E. Centered logo: the word "Amoria" in elegant serif font, white with subtle pink-to-purple gradient shimmer effect (#E91E63 to #9C27B0). Below the logo, a delicate glowing heart icon made of particles.
Subtle animated sparkles/stars scattered around the logo.
Bottom: thin loading progress bar in pink gradient.
Aspect ratio 9:16, iPhone 15 Pro frame. Premium, feminine, romantic aesthetic.
No text other than "Amoria". Minimalist, cinematic lighting.
```

---

## 📱 2. ONBOARDING — Слайд 1: «Открой мир историй»

```
UI design, mobile app onboarding screen, slide 1 of 3.
Dark background #1A1A2E. Top 60% — beautiful anime-style illustration: a girl silhouette standing in front of a magical glowing library with floating books and sparkles, warm golden and pink lighting, dreamy atmosphere.
Bottom 40% — white text on dark: large title "Открой мир историй" (bold, 24pt), subtitle below "Сотни интерактивных новелл — романтика, фэнтези, мистика и драма" (16pt, white 70% opacity).
Three dot indicators at bottom, first one active (pink #E91E63), others grey.
Large rounded pink gradient button (#E91E63 → #9C27B0) at bottom: "Далее →"
Aspect ratio 9:16, iPhone frame. Feminine, magical, inviting design.
```

---

## 📱 3. ONBOARDING — Слайд 2: «Влияй на сюжет»

```
UI design, mobile app onboarding screen, slide 2 of 3.
Dark background #1A1A2E. Top 60% — anime-style illustration: two dialogue choice buttons floating in the air, one glowing pink with heart icon, one neutral with question mark, beautiful male character looking at the viewer, romantic garden background with cherry blossoms, soft pink and purple lighting.
Bottom 40% — title "Влияй на сюжет" (bold, 24pt white), subtitle "Каждый выбор меняет историю. Твои решения определяют финал" (16pt, 70% white).
Three dots, second active. Pink gradient "Далее →" button.
Aspect ratio 9:16. Romantic, interactive, empowering.
```

---

## 📱 4. ONBOARDING — Слайд 3: «Открой романтику»

```
UI design, mobile app onboarding screen, slide 3 of 3.
Dark background #1A1A2E. Top 60% — anime illustration: close-up of a beautiful scene — two characters almost kissing under starry sky, city lights below, soft bokeh, cinematic composition, emotional atmosphere, pink and gold tones.
Bottom 40% — title "Открой романтику" (bold, 24pt), subtitle "Встречай незабываемых персонажей и переживай невероятные истории" (16pt, 70% white).
Three dots, third active (pink). Large rounded button "Начать приключение 💕" with pink-to-purple gradient, subtle glow.
Aspect ratio 9:16. Emotional, cinematic, premium.
```

---

## 📱 5. ЭКРАН ВЫБОРА ПРЕДПОЧТЕНИЙ (Genre Picker)

```
UI design, mobile app preference selection screen for visual novel app.
Dark background #1A1A2E. Top: "Что тебе нравится?" (bold, 24pt white), subtitle "Выбери жанры для персональных рекомендаций" (14pt, grey).

Grid of 6 genre cards (2 columns, 3 rows), each card is a rounded rectangle (16px radius) with:
- Semi-transparent gradient background
- Large emoji icon on top
- Genre name below (14pt, white)
- When selected: pink border #E91E63 + checkmark

Genre cards:
Row 1: 💕 Романтика (selected, pink border), ✨ Фэнтези
Row 2: 🎭 Драма, 🔍 Детектив
Row 3: 🌙 Мистика, 😂 Комедия

Bottom: pink gradient button "Продолжить" + skip link "Пропустить" in grey text.
Aspect ratio 9:16, dark premium aesthetic, feminine design.
```

---

## 📱 6. ГЛАВНЫЙ ЭКРАН — HOME (Полный редизайн)

```
UI design, mobile app home screen for "Amoria" romantic visual novel app. Dark theme.

TOP BAR: Status bar area, then a row with:
- Left: small pink bell icon 🔔 with red notification badge "3"
- Center: "Amoria" logo text in elegant pink gradient
- Right: currency badges — "💎 245" and "⚡ 3/5" in dark pill shapes (#16213E) with tiny "+" circles

FEATURED BANNER (full width carousel):
Large rounded card (16px radius) showing a gorgeous anime-style novel cover with gradient overlay at bottom. Title "Тени Петербурга" in bold white over the image, subtitle "Новая глава!" badge in pink. Dot indicators (3 dots) below. Card has subtle shadow and pink glow.

SECTION "Продолжить чтение" (horizontal scroll):
Section header with bookmark icon and "Продолжить чтение" text in pink.
Two horizontal cards (140x200px each): novel cover with rounded corners, thin pink progress bar at bottom (showing ~60% progress), title overlay at bottom. Soft shadow.

SECTION "Рекомендации для тебя":
Header with sparkle icon ✨ and text.
Horizontal scroll of 3 novel cover cards with genre badge, star rating "⭐ 4.8", and chapter count.

SECTION "🔥 Тренды":
Header with fire icon.
Numbered list (#1, #2, #3) with small cover thumbnails, title, and genre tag.

BOTTOM NAVIGATION:
4 tabs with icons: 🏠 Главная (active, pink), 🔍 Каталог, 🛒 Магазин, 👤 Профиль
Dark background #0F0F1E, thin top border. Small pink dot on "Магазин" tab.

Background: #1A1A2E. Aspect ratio 9:16, iPhone 15 Pro. Premium dark UI with pink accents, feminine aesthetic, clean layout, lots of visual hierarchy.
```

---

## 📱 7. КАТАЛОГ / ОБНАРУЖЕНИЕ (Discovery Screen)

```
UI design, mobile app catalog/discovery screen for visual novel app. Dark theme #1A1A2E.

TOP: Large bold title "Каталог" (28pt white).

SEARCH BAR: Rounded rectangle (#16213E), magnifying glass icon, placeholder text "Поиск по названию, автору..." in grey. Right side: filter icon.

GENRE CHIPS (horizontal scroll):
Row of rounded pill-shaped chips: "Все" (active, filled with pink gradient), "💕 Романтика", "✨ Фэнтези", "🎭 Драма", "🔍 Детектив", "🌙 Мистика". Inactive chips have dark bg with border.

SORT ROW: "Сортировка:" label + dropdown "По популярности ▾" in small text.
VIEW TOGGLE: two icons — grid (active) and list view.

NOVEL GRID (2 columns):
4 novel cards in grid layout. Each card:
- Tall cover image (rounded 16px) filling most of the card
- Gradient overlay at bottom with title (14pt bold white) and author (12pt pink)
- Top-right corner: badge "NEW" (green) or "🔥" (orange gradient)
- Bottom: thin stars row "⭐⭐⭐⭐⭐ 4.7" (tiny, 10pt)
- Heart icon ❤️ top-left (favorite toggle, outlined white)
- If started: thin progress line at very bottom

One card shows "ЗАВЕРШЕНА ✅" badge. Another shows "VIP 👑" badge with golden border.

BOTTOM NAVIGATION: same 4 tabs, "Каталог" tab active (pink icon).

Aspect ratio 9:16, clean grid, dark premium, feminine. No clutter, lots of spacing.
```

---

## 📱 8. КАТАЛОГ — Режим списка

```
UI design, mobile app catalog screen in LIST VIEW mode for visual novel app. Dark theme.

Same top section (title, search, genre chips, sort).
VIEW TOGGLE: list icon active.

LIST ITEMS (vertical):
Each item is a horizontal card: left — small cover image (80x110px, rounded), right — column with:
- Title (16pt bold white)
- Author (13pt pink #E91E63)
- Genre tags (small chips: "Романтика", "Драма")
- Row: "⭐ 4.8 · 12 глав · 45K 👁"
- Bottom-right: pink "Читать →" text button
- If in progress: "Продолжить" with green accent
- Thin separator line between items

3-4 list items visible on screen.

Background #1A1A2E. Aspect ratio 9:16, clean list layout, easy to scan.
```

---

## 📱 9. КАРТОЧКА НОВЕЛЛЫ — Детализация (Novel Detail Screen)

```
UI design, mobile app novel detail screen for visual novel app. Dark theme.

FULL-SCREEN COVER at top (350px height): gorgeous anime-style illustration, parallax-ready.
Gradient overlay from transparent to #1A1A2E at bottom.
Back arrow (top-left), share icon (top-right) over the image.

Below the cover, scrollable content on #1A1A2E:

TITLE: "Тени Петербурга" (28pt bold white)
AUTHOR ROW: pink person icon + "Анна Мирова" (14pt pink)
RATING ROW: "⭐⭐⭐⭐⭐ 4.8 (1.2K оценок)" + "Оценить" button outline

TAGS: rounded chips — "Романтика", "Мистика", "Петербург" in dark bg with white border.

DESCRIPTION: 3 lines of text (16pt, white 70%, line-height 1.6), "Читать полностью ▾" link.

INFO ROW: three info chips with icons:
- 📖 "12 глав" — book icon
- ⏱ "~15 мин/глава" — clock icon
- 📅 "Обновлено 2 дня назад" — calendar icon

CHARACTER CARDS (horizontal scroll, "Персонажи" header):
3 circular character avatars (64px) with name below and tiny heart meter (3 of 5 hearts filled). Pink border on main love interest.

CHAPTER LIST ("Главы" header):
Numbered rows:
- Ch 1 "Прибытие" — ✅ green check (completed)
- Ch 2 "Тайное приглашение" — ✅ check
- Ch 3 "Ночь в особняке" — 🔓 unlocked, not started
- Ch 4 "Развязка" — 🔒 locked (grey)

BIG BUTTON (full width): pink gradient, "Продолжить чтение" (or "Начать историю" if new).
Below: outlined button "Начать сначала" (white 60%, white border 24%).

48 REVIEWS SECTION: "Отзывы (48)" header, 2 mini review cards with avatar, name, stars, 2-line text.

Aspect ratio 9:16, rich detail, cinematic feel, premium. iPhone frame.
```

---

## 📱 10. ИГРОВОЙ ЭКРАН — Game Screen (Полировка)

```
UI design, mobile app game/reading screen for visual novel app. Dark theme, fullscreen.

BACKGROUND: beautiful anime-style night cityscape of St. Petersburg, Neva river, bridges, warm lights reflecting on water, atmospheric fog.

CHARACTER: anime-style handsome man (dark hair, grey-blue eyes, navy coat) standing at center-right, expression: gentle smile. Semi-transparent, slightly above dialogue box.

TOP HUD (semi-transparent, glassmorphism):
- Left: "Глава 2 · Сцена 5" (small text, white 60%)
- Center: thin progress bar (pink gradient, ~40% filled)
- Right: hamburger menu icon ☰ (white 50%)

DIALOGUE BOX (bottom 30% of screen):
Glassmorphism card: blurred background, semi-transparent dark (#000 70% opacity), rounded top corners (20px).
- Top-left: small circular character avatar (32px) + speaker name "Алекс" in pink #E91E63 (bold, 16pt)
- Text: "Я давно хотел тебе кое-что сказать..." (18pt white, line-height 1.5)
- Animated typing cursor at the end of text (blinking pink line)
- Bottom-right: small arrow icon "▶" (white 54%) indicating tap to continue

No choice buttons visible (they appear separately).

Aspect ratio 9:16, immersive, cinematic, no UI clutter. Focus on atmosphere and story.
```

---

## 📱 11. ИГРОВОЙ ЭКРАН — Момент выбора

```
UI design, mobile app game screen showing CHOICE moment in visual novel. Dark theme.

Same background and character as previous. Character expression: expectant, looking at viewer.

DIALOGUE BOX (shorter, only speaker line visible):
"Алекс" name + "Так что скажешь?" text.

CHOICE BUTTONS (centered, stacked vertically, 3 options):

Choice 1 (normal): Dark rounded rectangle (#16213E), white border 20%, text "Мне нужно подумать..." (16pt white). Subtle slide-up animation implied.

Choice 2 (normal): Same style, text "Я тоже чувствую это 💕" with small heart. Left border accent pink.

Choice 3 (premium): Pink-to-purple gradient border, sparkle icon ✨ on left, text "💎 Поцеловать его" (16pt white bold), right side "15 💎" cost badge in small pink pill. Premium glow effect around the card.

Top HUD and progress bar same as before.
All three buttons have rounded corners (16px), vertical spacing 12px between them.

Aspect ratio 9:16, dramatic moment, emotional, premium choices stand out.
```

---

## 📱 12. ИГРОВОЙ ЭКРАН — Меню паузы (Pause Menu)

```
UI design, mobile app pause/settings overlay for visual novel game screen. Dark theme.

Background: blurred game screen (gaussian blur, dark overlay 60%).

CENTER MODAL (rounded 24px, #16213E background, pink gradient top border 2px):

Title: "⏸ Пауза" (20pt bold white), centered.

MENU OPTIONS (vertical list, each is a row with icon + text):
- 💾 Сохранить — white text
- 📂 Загрузить — white text
- 💕 Отношения — pink accent (shows relationship map)
- 👗 Гардероб — white text
- 📜 Лог диалогов — white text
- ⚙️ Настройки — white text
- 🚪 Выход — red accent text

Thin separator lines between items (#FFFFFF 10%).

Bottom of modal: "Вернуться к игре" pink gradient button (full width).

RELATIONSHIP PREVIEW (small section at bottom of modal):
3 tiny character avatars in a row with heart meters (pink bars) showing love level. "Алекс ❤️❤️❤️○○" format.

Aspect ratio 9:16. Clean, organized, easy to navigate with one hand.
```

---

## 📱 13. ЛОГ ДИАЛОГОВ (Dialogue History)

```
UI design, mobile app dialogue history/log screen for visual novel. Dark theme #1A1A2E.

TOP BAR: back arrow + "Лог диалогов" title (white) + search icon.

SCROLLABLE LIST of past dialogue entries:

Each entry is a row:
- Small character avatar (24px circle) or narration icon (book) on left
- Speaker name in their color (pink for Алекс, blue for Каэль, grey for narration)
- Dialogue text below (14pt, white 80%)
- Timestamp or scene number on right (tiny, grey)

Narration entries have italic text and book icon instead of avatar.
Choice entries marked with "→" arrow icon and highlighted in dark pink tint.

10-12 entries visible, scrollable. Most recent at bottom.
Semi-transparent gradient at top (fade from content to bar).

Aspect ratio 9:16, clean reading layout, easy to scroll through.
```

---

## 📱 14. КАРТА ОТНОШЕНИЙ (Relationship Map)

```
UI design, mobile app relationship/character status screen for visual novel. Dark theme.

TOP BAR: back arrow + "Отношения" title + heart icon (pink).

CHARACTER CARDS (vertical list, 3 cards):

Each card is a horizontal rounded rectangle (#16213E, 16px radius):
- Left: character portrait (circular, 72px, pink border for romance interest)
- Center column:
  - Name "Алекс" (18pt bold white)
  - Role subtitle "Загадочный незнакомец" (12pt grey)
  - Relationship bar: labeled "❤️ Любовь" — gradient bar (pink, 70% filled) with "35/50" text
  - Second bar: "🤝 Доверие" — gradient bar (cyan, 45% filled) with "22/50"
  - Third bar: "🔥 Страсть" — gradient bar (orange, 30% filled) with "15/50"
- Right: small arrow "›" for detail view

Second card "Каэль" with different bar levels.
Third card "Дмитрий" with different bar levels.

Bottom text: "Совет: ваши выборы влияют на отношения с персонажами" (12pt, grey, italic).

Aspect ratio 9:16, clean data visualization, emotional color coding.
```

---

## 📱 15. МАГАЗИН — Полный редизайн (Shop Screen)

```
UI design, mobile app premium shop/store screen for visual novel app. Dark theme #1A1A2E.

TOP BAR: back arrow + "Магазин" title + currency badges "💎 245" and "⚡ 3/5"

TAB BAR (horizontal, below top bar):
4 tabs: "💎 Алмазы" (active, pink underline), "⚡ Билеты", "👑 VIP", "🎁 Акции"

VIP BANNER (top, full width):
Animated shimmer gradient card (gold → pink → purple). Crown icon 👑, text "Amoria VIP" (bold, 20pt), subtitle "Безлимитные билеты + 5💎/день", price "$4.99/мес", "Попробовать" button (white pill). Star sparkles.

DIAMOND PACKS (2x2 grid):
Each card: rounded (#16213E), diamond stack illustration at top, amount "60 💎" (bold, 24pt), price "$2.99" in pink button at bottom.
- Pack 1: "20 💎" — $0.99
- Pack 2: "60 💎" — $2.99 (badge "ПОПУЛЯРНОЕ" in pink)
- Pack 3: "150 💎" — $5.99 (badge "ЛУЧШЕЕ ПРЕДЛОЖЕНИЕ 🏆" in gold)
- Pack 4: "500 💎" — $14.99

FREE SECTION (below):
Header "Бесплатные алмазы ✨"
- Row: "📺 Смотреть рекламу → +3💎" with progress "2/5 сегодня" (cyan accent card)
- Row: "🎁 Ежедневная награда" with "Собрать" button (if available) or "Завтра" grey text
- Row: "🔑 Промокод" with text input field and "Применить" button

Aspect ratio 9:16, premium feel, clear pricing, inviting design. Cards have subtle glow effects.
```

---

## 📱 16. ПРОФИЛЬ — Полный редизайн

```
UI design, mobile app profile screen for visual novel app. Dark theme.

HEADER SECTION (full width, 200px height):
Gradient background (dark purple #2D1854 → #16213E).
Large circular avatar (96px) with gradient ring (pink → purple), emoji or illustration inside.
Name "Алиса" (22pt bold white) below avatar.
Level badge: "🌸 Книголюб · Уровень 7" in small pink text.
XP progress bar below: thin pink bar, "720/1000 XP" text.

STATS CARDS (2x2 grid, below header):
4 small rounded cards (#16213E):
- 📚 "12" — Прочитано новелл (icon + big number + label)
- 📖 "47" — Глав пройдено
- 💕 "89" — Выборов сделано
- 🏆 "5" — Достижений

SECTION "❤️ Избранное" (horizontal scroll):
3 small novel cover thumbnails (80x120px), rounded. "Все →" link on right.

SECTION "📊 История чтения":
2 novel rows: cover thumbnail + title + progress bar + "75%" text. "Все →" link.

SECTION "🏆 Достижения":
Horizontal scroll of achievement badges (circular icons with labels).
One badge shows progress ring "3/5" around it.

SECTION "🖼 Галерея CG":
Grid of 4 small CG thumbnails (square, rounded). Locked ones have blur + lock icon 🔒.
"Все (8/24) →" link.

ACCOUNT SECTION:
"☁️ user@email.com — Синхронизировано" green status.
Buttons: "Синхронизировать" outline, "Выйти" red outline.

BOTTOM: "Настройки ⚙️" link.

Aspect ratio 9:16, rich profile, gamified, engaging. Premium dark aesthetic.
```

---

## 📱 17. НАСТРОЙКИ (Settings Screen)

```
UI design, mobile app settings screen for visual novel app. Dark theme #1A1A2E.

TOP BAR: back arrow + "Настройки" title.

SECTIONS with grouped settings:

SECTION "📖 Чтение":
- Скорость текста: slider (pink thumb) with labels "Медленно — Быстро"
- Автопрокрутка: toggle switch (pink when on) + "Задержка: 3 сек" stepper
- Размер шрифта: slider or A/A+ buttons with preview text below

SECTION "🔊 Звук":
- Музыка: slider with volume icon (0-100%)
- Звуковые эффекты: slider
- Вибрация: toggle switch

SECTION "🎨 Оформление":
- Тема: 3 option cards — "🌙 Тёмная" (selected, pink border), "☀️ Светлая", "📱 Системная"
- Язык: dropdown "Русский 🇷🇺 ▾"

SECTION "📱 Приложение":
- Уведомления: toggle
- Очистить кеш: button with size "45 MB"
- Восстановить покупки: button
- О приложении: row with "v2.1.0" text

Each section has a pink section title (14pt, uppercase, letter-spacing).
Settings rows: icon + label left, control right. Separated by thin lines.

Aspect ratio 9:16, clean settings layout, easy to use.
```

---

## 📱 18. ЦЕНТР УВЕДОМЛЕНИЙ (Notification Center)

```
UI design, mobile app notification center screen for visual novel. Dark theme.

TOP BAR: back arrow + "Уведомления" + "Прочитать все" link (pink).

NOTIFICATION LIST (scrollable):

Notification card 1 (unread, left pink border accent):
- Icon: 📖 (book) in pink circle
- Title: "Новая глава: Тени Петербурга" (bold white, 15pt)
- Text: "Глава 5 'Маскарад' теперь доступна!" (13pt, grey)
- Time: "2 часа назад" (11pt, grey)
- Unread dot (pink) on right

Notification card 2 (unread):
- Icon: 🎁 (gift) in green circle
- Title: "Ежедневная награда"
- Text: "Заберите 5💎 за 5-й день подряд!"
- Time: "5 часов назад"

Notification card 3 (read, no border, dimmer):
- Icon: 🏆 (trophy) in yellow circle
- Title: "Достижение разблокировано!"
- Text: "Вы получили бейдж «Книголюб»"
- Time: "Вчера"

Notification card 4 (read):
- Icon: 🛍 (shopping) in purple circle
- Title: "Спецпредложение заканчивается"
- Text: "Стартовый набор 100💎 за $0.99 — осталось 12 часов"
- Time: "Вчера"

Empty state (if no notifications): illustration of sleeping cat + "Пока ничего нового" grey text.

Aspect ratio 9:16, clean cards, clear hierarchy between read/unread.
```

---

## 📱 19. ЕЖЕДНЕВНЫЕ НАГРАДЫ — Redesign (Daily Rewards Modal)

```
UI design, mobile app daily reward popup/modal for visual novel app. Dark theme.

BACKDROP: blurred dark overlay over the app.

MODAL (centered, rounded 24px, #16213E):
Top: decorative sparkle banner illustration (gold + pink stars).
Title: "🎁 Ежедневная награда" (22pt bold white).
Subtitle: "День 5 из 7" (14pt grey).

7-DAY CALENDAR ROW (horizontal):
7 circular day indicators:
- Days 1-4: filled green check ✅, small reward icon below (1💎, 2💎, 3💎, 1⚡)
- Day 5: active/current — large glowing pink border, pulsing, "5💎" in center, "Сегодня!" label
- Days 6-7: locked grey, "?" icon, outlined circle

REWARD REVEAL:
Below the calendar: large reward display "✨ +5 💎" (32pt, pink gradient text), diamond animation sparkle.

BUTTON: "Забрать награду! 🎉" — full width pink gradient, rounded 20px, bold text.
Below button: "Заходи завтра за следующей наградой!" (12pt, grey italic).

Aspect ratio 9:16, celebratory feel, gamified, satisfying.
```

---

## 📱 20. ЭКРАН АВТОРИЗАЦИИ — Redesign

```
UI design, mobile app login/registration screen for visual novel app. Dark theme #1A1A2E.

TOP SECTION:
"Amoria" logo in pink gradient (elegant serif), centered.
Subtitle: "Сохраняй прогресс и играй на любом устройстве" (14pt, grey).

TABS: "Вход" (active, pink underline) | "Регистрация"

FORM (login mode):
- Email field: rounded input (#16213E bg), envelope icon, placeholder "Email"
- Password field: rounded input, lock icon, eye toggle icon, placeholder "Пароль"
- "Забыли пароль?" link (pink, 12pt, right-aligned)
- "Войти" button: full width, pink gradient, rounded 16px, bold

DIVIDER: line with "или" text in center (grey).

SOCIAL BUTTONS (horizontal row):
- Google button: white rounded rectangle, Google logo, "Google"
- Apple button: dark rounded rectangle, Apple logo, "Apple"

Bottom: "Продолжить без аккаунта" grey text link.

Aspect ratio 9:16, clean auth flow, minimal friction. Premium feel.
```

---

## 📱 21. ЭКРАН ГАЛЕРЕИ CG — Redesign

```
UI design, mobile app CG gallery screen for visual novel app. Dark theme.

TOP BAR: back arrow + "Галерея CG" + filter icon.

NOVEL FILTER: horizontal chip scroll: "Все", "Тени Петербурга" (active, pink), "Пасынки Небосвода"

CG GRID (3 columns):
Square thumbnails with rounded corners (12px).

Unlocked CGs: full color anime-style romantic illustrations (various scenes: kiss under stars, dance at ball, cafe moment). Tap to view fullscreen.

Locked CGs: same size, but heavily blurred/dark with centered lock icon 🔒 and "?" text. Subtle pink glow hint.

Bottom counter: "Собрано: 8/24 (33%)" with progress bar.

One CG has "NEW" badge (just unlocked).

Aspect ratio 9:16, gallery aesthetic, collectible feel, mystery for locked items.
```

---

## 📱 22. ГАРДЕРОБ (Wardrobe Screen)

```
UI design, mobile app wardrobe/outfit customization screen for visual novel. Dark theme.

TOP BAR: back arrow + "Гардероб" title + character name "Алекс" dropdown.

CHARACTER PREVIEW (center, 60% of screen):
Full anime character sprite wearing selected outfit, standing on subtle gradient platform, sparkle effects around new items.

OUTFIT CATEGORIES (horizontal tab bar below character):
Tabs with icons: "👔 Верх", "👖 Низ", "🧥 Верхняя одежда", "👞 Обувь", "💍 Аксессуары"

ITEM GRID (bottom section, horizontal scroll):
Outfit item cards (80x80px, rounded):
- Available items: clear thumbnail, name below
- Premium items: pink border, "💎 25" price tag in corner
- Equipped item: pink checkmark overlay
- Locked items: grey, lock icon

"Надеть" pink gradient button at bottom (if selected item differs from equipped).

Aspect ratio 9:16, fashion/dress-up feel, clean item selection. Fun and feminine.
```

---

## 📱 23. СВЕТЛАЯ ТЕМА — Home Screen вариант

```
UI design, mobile app home screen in LIGHT THEME for visual novel app "Amoria".

Same layout as dark home screen but with light color scheme:
- Background: #F5F5FA (light lavender-grey)
- Surface cards: #FFFFFF with subtle shadow
- Text primary: #1A1A2E (dark)
- Text secondary: #666680
- Accent: same pink #E91E63
- Bottom nav: white background, thin top shadow

Featured banner, sections, cards — all same structure but adapted to light palette.
Pink gradient accents remain. Novel cover cards have white background with soft shadow.

Clean, airy, modern. Suitable for daytime reading.
Aspect ratio 9:16, iPhone frame.
```

---

## 📱 24. ЭКРАН «ЧТО НОВОГО» (What's New Modal)

```
UI design, mobile app "What's New" update modal for visual novel app. Dark theme.

BACKDROP: blurred dark overlay.

MODAL (rounded 24px, #16213E, centered):
Top: "🎉 Что нового в v2.2" (20pt bold white)

UPDATE LIST:
- ✨ "Новый каталог с фильтрами и поиском" — icon + text row
- 📖 "Новая новелла: Огни Парижа" — icon + text row, "НОВИНКА" pink badge
- 👗 "3 новых наряда в гардеробе" — icon + text row
- 🏆 "Новые достижения" — icon + text row
- 🐛 "Исправления и улучшения" — icon + text row

Bottom: "Понятно!" pink gradient button.

Aspect ratio 9:16, informative, celebratory. Clean list.
```

---

## 📱 25. SKELETON LOADING (Загрузка каталога)

```
UI design, mobile app skeleton/placeholder loading state for catalog screen. Dark theme.

Same layout as catalog but all content replaced with shimmer placeholder shapes:
- Search bar: grey rounded rectangle shimmer
- Genre chips: 5 grey rounded pill shimmers
- Novel cards (2x2 grid): grey rounded rectangles with pulsing shimmer animation (gradient sweep left to right)
  - Cover area: large grey rectangle
  - Title area: thin grey line (60% width)
  - Author area: thinner grey line (40% width)

Shimmer gradient: dark grey (#16213E) sweeping to slightly lighter grey (#1E2A4A) and back.

Aspect ratio 9:16. Elegant loading state, no spinner. Premium feel.
```

---

## 📱 26. ПУСТОЕ СОСТОЯНИЕ — Избранное

```
UI design, mobile app empty state illustration for "Favorites" section. Dark theme #1A1A2E.

Centered composition:
- Large cute anime-style illustration: a girl sitting on a crescent moon, reading a book, stars and hearts floating around her. Soft pink and purple tones.
- Below: "Пока пусто" (18pt white, 60% opacity)
- Subtitle: "Нажмите ❤️ на понравившейся истории" (14pt, grey)
- Pink outline button: "Перейти в каталог →"

Soft, dreamy, inviting. Encourages action without being pushy.
Aspect ratio 9:16.
```

---

## 📱 27. ТАБЛЕТ LAYOUT (iPad Adaptive)

```
UI design, tablet/iPad app layout for visual novel app "Amoria". Dark theme. Landscape orientation.

SPLIT VIEW:
Left sidebar (280px width, #0F0F1E):
- Amoria logo at top
- Navigation: 🏠 Главная, 🔍 Каталог, 🛒 Магазин, 👤 Профиль, ⚙️ Настройки
- Active item highlighted with pink left border
- Currency badges at bottom of sidebar

Right content area (remaining width, #1A1A2E):
- Home screen content adapted for wide layout
- Featured banner wider
- Novel cards in 3-4 column grid instead of 2
- More breathing room, larger covers

Aspect ratio 4:3 (iPad). Premium, spacious, professional layout.
```

---

## 📐 Общие рекомендации для дизайнера

1. **Все экраны в 9:16** (вертикальный мобильный), кроме таблетного (4:3)
2. **Используй Figma/Sketch** для финальных макетов с компонентами
3. **Иконки:** Lucide Icons или Material Symbols Rounded
4. **Шрифт:** Nunito (основной) + Playfair Display (заголовки логотипа)
5. **Анимации:** описаны текстово, реализуются в Flutter (Lottie, AnimatedBuilder)
6. **Все промпты можно модифицировать** — меняй название новеллы, имена персонажей, цвета под свой стиль
