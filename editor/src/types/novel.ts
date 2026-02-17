// Типы данных — полностью совпадают с Dart-моделями Amoria

export interface NovelMeta {
  id: string;
  title: string;
  description: string;
  author: string;
  coverImage?: string;
  tags: string[];
  totalChapters: number;
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
  charactersOnScreen: SceneCharacter[];
  events: SceneEvent[];
  nextSceneId?: string;
}

export interface SceneTransition {
  type: 'fade' | 'slideLeft' | 'slideRight' | 'dissolve' | 'none';
  duration: number; // мс
}

export interface SceneCharacter {
  characterId: string;
  spriteId: string;
  position: 'left' | 'center' | 'right';
  animation?: 'fade_in' | 'fade_out' | 'slide_in_left' | 'slide_in_right' | 'bounce' | 'shake';
}

export type EventType = 'dialogue' | 'narration' | 'choice' | 'set_variable' | 'play_sound' | 'changeBackground' | 'changeSprite' | 'effect';

export type EffectType = 'shake' | 'flash' | 'fadeToBlack' | 'rain' | 'snow' | 'particles';

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

// Полное состояние проекта новеллы в редакторе
export interface NovelProject {
  meta: NovelMeta;
  characters: Character[];
  variables: Record<string, string | number | boolean>;
  chapters: Chapter[];
}
