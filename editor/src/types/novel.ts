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
  charactersOnScreen: SceneCharacter[];
  events: SceneEvent[];
  nextSceneId?: string;
}

export interface SceneCharacter {
  characterId: string;
  spriteId: string;
  position: 'left' | 'center' | 'right';
  animation?: string;
}

export type EventType = 'dialogue' | 'narration' | 'choice' | 'set_variable' | 'play_sound' | 'changeBackground' | 'changeSprite';

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
