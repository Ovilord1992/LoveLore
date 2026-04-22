// Типы данных — полностью совпадают с Dart-моделями Amoria

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
}

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

export interface Outfit {
  id: string;
  name: string;
  spriteOverride: string;
  description?: string;
  isDefault?: boolean;
}

export interface Chapter {
  id: string;
  title: string;
  number: number;
  firstSceneId: string;
  scenes: Scene[];
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

export type EventType = 'dialogue' | 'narration' | 'choice' | 'set_variable' | 'play_sound' | 'changeBackground' | 'changeSprite' | 'effect' | 'showCg' | 'cameraMove' | 'showEmotion';

export type EffectType = 'shake' | 'flash' | 'fadeToBlack' | 'rain' | 'snow' | 'particles';
export type CgTransition = 'fade' | 'zoomIn';
export type EmotionType = 'heart' | 'sweatDrop' | 'question' | 'exclamation' | 'anger' | 'sparkle' | 'musicNote' | 'zzz';

export interface SceneEvent {
  type: EventType;
  speaker?: string;
  text?: string;
  choices?: Choice[];
  variable?: string;
  value?: string | number | boolean;
  background?: string;
  characterId?: string;
  spriteId?: string;
  sound?: string;
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
  // Cross-fade спрайтов
  spriteDuration?: number; // мс
  // Таймер на выбор
  timeLimit?: number; // секунды
  defaultChoiceIndex?: number;
}

export interface Choice {
  text: string;
  nextSceneId: string;
  effects?: Record<string, string | number | boolean>;
  condition?: Condition;
  premium?: boolean;
  cost?: number;
}

export interface Condition {
  variable: string;
  operator: '>=' | '<=' | '==' | '!=' | '>' | '<';
  value: number;
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
