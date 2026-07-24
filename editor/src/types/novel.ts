// Типы данных — полностью совпадают с Dart-моделями Amoria + формат v2
// (guides/format-v2.md, Часть 1). Все новые поля v2 — опциональные.

export interface EndingMetaEntry {
  id: string;
  title: string;
  hidden?: boolean;
}

export type StatIcon = 'heart' | 'star' | 'flame' | 'diamond' | 'moon' | 'sun' | 'leaf';

export interface StatDisplay {
  variable: string;
  label: string;
  icon?: StatIcon;
  color?: string; // hex "#E91E63"
  max?: number;
}

export interface PlayerNamePrompt {
  enabled: boolean;
  prompt?: string;
  defaultName?: string;
}

export interface NovelMeta {
  id: string;
  title: string;
  description: string;
  author: string;
  coverImage?: string;
  tags: string[];
  chaptersCount: number;
  sourceLanguage?: string; // язык оригинала (ru, en, etc.)
  dialogueTheme?: 'ornate' | 'artDeco' | 'modern' | 'glassmorphism' | 'fantasy'
    | 'victorian' | 'gothic' | 'noir' | 'sakura' | 'celestial'
    | 'cyberpunk' | 'steampunk' | 'pirate' | 'medieval' | 'egyptian'
    | 'baroque' | 'romantic' | 'nordic' | 'tropical' | 'bloodMoon';
  dialogueStyle?: 'classic' | 'center'; // classic=bottom, center=Romance Club style
  dialogueFrameColor?: string; // hex e.g. "#B8860B"
  dialogueBgColor?: string;    // hex e.g. "#1A1410"
  // v2 (1.3): список всех концовок для галереи «N из M»
  endings?: EndingMetaEntry[];
  // v2 (1.9): панель отношений
  statsDisplay?: StatDisplay[];
  // v2 (1.4): запрос имени игрока при первом старте
  playerNamePrompt?: PlayerNamePrompt;
  // v2.1 (4.1): версия формата (пишется при экспорте) и минимальная версия приложения
  formatVersion?: number;
  minAppVersion?: string;
}

// Текущая версия формата, проставляется в meta.json при экспорте (спека 4.1)
export const CURRENT_FORMAT_VERSION = 2;

export interface Character {
  id: string;
  name: string;
  color: string;
  sprites: CharacterSprite[];
  outfits?: Outfit[];
}

export interface CharacterSprite {
  id: string;
  image: string;
  label: string;
}

// v2 (1.5): гардероб. Формат строго по спеке:
// sprites — маппинг спрайт-ключ → путь картинки ("sprites/mia/casual_happy.png").
export interface Outfit {
  id: string;
  name: string;
  default?: boolean;
  priceDiamonds?: number;
  thumbnail?: string;
  sprites: Record<string, string>;
}

export interface Chapter {
  id: string;
  title: string;
  number: number;
  firstSceneId: string;
  scenes: Scene[];
  // v2 (1.8): рекап «Ранее…» перед первой сценой главы
  recap?: string;
}

// v2 (1.2): ветвление по переменным в конце сцены
export interface SceneBranch {
  conditions: Condition[];
  conditionsLogic?: ConditionsLogic;
  nextSceneId: string;
}

// v2 (1.3): концовка на сцене
export interface SceneEnding {
  id: string;
  title: string;
  description?: string;
  image?: string; // напр. "cg/ending_good.png"
}

export interface Scene {
  id: string;
  background?: string;
  music?: string;
  transition?: SceneTransition;
  backgroundLayers?: BackgroundLayer[];
  charactersOnScreen: SceneCharacter[];
  events: SceneEvent[];
  nextSceneId?: string;
  // v2 (1.2): ветки проверяются по порядку в конце сцены
  branches?: SceneBranch[];
  // v2 (1.3): достижение конца сцены = концовка
  ending?: SceneEnding;
  /** Позиция ноды в редакторе графа сцен. Сохраняется между переключениями глав
   *  и сессиями. Не экспортируется в рантайм-бандл новеллы (игнорируется клиентом). */
  editorPosition?: { x: number; y: number };
}

export interface SceneTransition {
  type: 'fade' | 'slideLeft' | 'slideRight' | 'dissolve' | 'none';
  duration: number; // мс
}

export interface BackgroundLayer {
  image: string;
  depth: number; // 0.0 (задний план) — 1.0 (передний)
  offsetX: number;
  offsetY: number;
}

export interface SceneCharacter {
  characterId: string;
  spriteId: string;
  position: 'left' | 'center' | 'right';
  animation?: 'fade_in' | 'fade_out' | 'slide_in_left' | 'slide_in_right' | 'bounce' | 'shake';
}

export type EventType = 'dialogue' | 'narration' | 'choice' | 'setVariable' | 'playSound' | 'changeBackground' | 'changeSprite' | 'effect' | 'showCg' | 'cameraMove' | 'showEmotion';

export type EffectType = 'shake' | 'flash' | 'fadeToBlack' | 'rain' | 'snow' | 'particles';
export type CgTransition = 'fade' | 'zoomIn';
export type EmotionType = 'heart' | 'sweatDrop' | 'question' | 'exclamation' | 'anger' | 'sparkle' | 'musicNote' | 'zzz';

export interface SceneEvent {
  type: EventType;
  speaker?: string;
  text?: string;
  choices?: Choice[];
  // setVariable
  variable?: string;
  value?: string | number | boolean;
  // Путь к ассету: имя файла фона для changeBackground ("forest.png"),
  // путь к звуку для playSound ("sounds/door.mp3"). Клиент читает это поле.
  asset?: string;
  characterId?: string;
  spriteId?: string;
  // Поля для события effect
  effectType?: EffectType;
  effectDuration?: number; // мс
  effectIntensity?: number; // 0.0–1.0
  // CG-арт
  cgImage?: string;
  cgTransition?: CgTransition;
  cgDuration?: number; // мс
  // Камера
  zoom?: number; // 0.5–2.0
  panX?: number;
  panY?: number;
  cameraDuration?: number; // мс
  // Эмоции
  emotionType?: EmotionType;
  // v2 (1.7): эмоция картинкой вместо emoji ("emotions/love.png")
  image?: string;
  // Cross-fade спрайтов
  spriteDuration?: number; // мс
  // Таймер на выбор
  timeLimit?: number; // секунды
  defaultChoiceIndex?: number;
  // v2 (1.6): озвучка dialogue/narration ("voice/ch1/mia_001.mp3")
  voice?: string;
}

export type ConditionsLogic = 'and' | 'or';

export interface Choice {
  text: string;
  nextSceneId: string;
  effects?: Record<string, string | number | boolean>;
  condition?: Condition;
  // v2 (1.1): составные условия; при заданных conditions приоритет у них
  conditions?: Condition[];
  conditionsLogic?: ConditionsLogic;
  // v2 (1.5): сюжетная разблокировка аутфитов ["mia:gala"]
  unlockOutfits?: string[];
  premium?: boolean;
  cost?: number;
}

export interface Condition {
  variable: string;
  operator: '>=' | '<=' | '==' | '!=' | '>' | '<';
  // v2 (1.1): в условиях допускаются и bool-значения ({ "value": true })
  value: number | boolean;
}

/// Перевод книги на один язык
export interface NovelTranslation {
  meta: {
    language: string;
    sourceLanguage: string;
    novelId: string;
    version: number;
  };
  novel?: { title?: string; description?: string };
  characters?: Record<string, { name?: string }>;
  chapters?: Record<string, { title?: string }>;
  texts: Record<string, string>; // оригинал → перевод
}

// Полное состояние проекта новеллы в редакторе
export interface NovelProject {
  meta: NovelMeta;
  characters: Character[];
  variables: Record<string, string | number | boolean>;
  chapters: Chapter[];
  translations?: Record<string, NovelTranslation>; // lang code → translation
}
