import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { NovelProject, NovelTranslation, Character, Chapter, Scene, SceneEvent, SceneCharacter, NovelMeta } from '../types/novel';

const defaultMeta: NovelMeta = {
  id: 'new_novel',
  title: 'Новая новелла',
  description: '',
  author: '',
  tags: [],
  chaptersCount: 1,
};

const defaultScene: Scene = {
  id: 'scene_1',
  charactersOnScreen: [],
  events: [
    { type: 'narration', text: 'Начало истории...' },
  ],
};

const defaultChapter: Chapter = {
  id: 'chapter_1',
  title: 'Глава 1',
  number: 1,
  firstSceneId: 'scene_1',
  scenes: [defaultScene],
};

// images: Map<путь_в_ZIP, File>  (напр. "backgrounds/city.png" → File)
interface EditorState {
  project: NovelProject;
  images: Map<string, File>;
  imageUrls: Map<string, string>;
  selectedChapterIndex: number;
  selectedSceneId: string | null;
  selectedEventIndex: number | null;
  selectedTranslationLang: string | null;
  isDirty: boolean;

  // Проект
  setProject: (project: NovelProject) => void;
  updateMeta: (meta: Partial<NovelMeta>) => void;

  // Изображения
  addImage: (zipPath: string, file: File) => void;
  removeImage: (zipPath: string) => void;
  getImageUrl: (zipPath: string) => string | undefined;
  clearImages: () => void;
  setImages: (images: Map<string, File>) => void;

  // Персонажи
  addCharacter: (character: Character) => void;
  updateCharacter: (id: string, updates: Partial<Character>) => void;
  removeCharacter: (id: string) => void;

  // Переменные
  setVariable: (key: string, value: string | number | boolean) => void;
  removeVariable: (key: string) => void;

  // Главы
  addChapter: () => void;
  removeChapter: (index: number) => void;
  selectChapter: (index: number) => void;

  // Сцены
  addScene: (scene: Scene) => void;
  updateScene: (sceneId: string, updates: Partial<Scene>) => void;
  removeScene: (sceneId: string) => void;
  selectScene: (sceneId: string | null) => void;

  // Персонажи на сцене
  addCharacterToScene: (sceneId: string, sc: SceneCharacter) => void;
  updateCharacterOnScene: (sceneId: string, charId: string, updates: Partial<SceneCharacter>) => void;
  removeCharacterFromScene: (sceneId: string, charId: string) => void;

  // События
  addEvent: (sceneId: string, event: SceneEvent) => void;
  updateEvent: (sceneId: string, eventIndex: number, event: SceneEvent) => void;
  removeEvent: (sceneId: string, eventIndex: number) => void;
  moveEvent: (sceneId: string, from: number, to: number) => void;
  selectEvent: (index: number | null) => void;

  // Переводы
  setTranslation: (lang: string, translation: NovelTranslation) => void;
  removeTranslation: (lang: string) => void;
  updateTranslationText: (lang: string, original: string, translated: string) => void;
  updateTranslationMeta: (lang: string, field: 'novelTitle' | 'novelDescription', value: string) => void;
  updateTranslationCharacter: (lang: string, characterId: string, name: string) => void;
  updateTranslationChapter: (lang: string, chapterId: string, title: string) => void;
  selectTranslationLang: (lang: string | null) => void;

  // Позиция ноды в SceneGraph — сохраняется между переключениями глав
  updateScenePosition: (chapterId: string, sceneId: string, position: { x: number; y: number }) => void;
}

export const useEditorStore = create<EditorState>()(
  persist(
    (set, get) => ({
  project: {
    meta: defaultMeta,
    characters: [],
    variables: {},
    chapters: [defaultChapter],
  },
  images: new Map(),
  imageUrls: new Map(),
  selectedChapterIndex: 0,
  selectedSceneId: 'scene_1',
  selectedEventIndex: null,
  selectedTranslationLang: null,
  isDirty: false,

  setProject: (project) => set({ project, isDirty: false, selectedChapterIndex: 0, selectedSceneId: null, selectedEventIndex: null }),

  updateMeta: (meta) => set((state) => ({
    project: { ...state.project, meta: { ...state.project.meta, ...meta } },
    isDirty: true,
  })),

  // --- Изображения ---
  addImage: (zipPath, file) => set((state) => {
    const images = new Map(state.images);
    const imageUrls = new Map(state.imageUrls);
    // Освобождаем старый URL
    const oldUrl = imageUrls.get(zipPath);
    if (oldUrl) URL.revokeObjectURL(oldUrl);
    images.set(zipPath, file);
    imageUrls.set(zipPath, URL.createObjectURL(file));
    return { images, imageUrls, isDirty: true };
  }),

  removeImage: (zipPath) => set((state) => {
    const images = new Map(state.images);
    const imageUrls = new Map(state.imageUrls);
    const url = imageUrls.get(zipPath);
    if (url) URL.revokeObjectURL(url);
    images.delete(zipPath);
    imageUrls.delete(zipPath);
    return { images, imageUrls, isDirty: true };
  }),

  getImageUrl: (zipPath) => get().imageUrls.get(zipPath),

  clearImages: () => set((state) => {
    state.imageUrls.forEach((url) => URL.revokeObjectURL(url));
    return { images: new Map(), imageUrls: new Map() };
  }),

  setImages: (images) => set((state) => {
    state.imageUrls.forEach((url) => URL.revokeObjectURL(url));
    const imageUrls = new Map<string, string>();
    images.forEach((file, path) => imageUrls.set(path, URL.createObjectURL(file)));
    return { images, imageUrls };
  }),

  addCharacter: (character) => set((state) => ({
    project: { ...state.project, characters: [...state.project.characters, character] },
    isDirty: true,
  })),

  updateCharacter: (id, updates) => set((state) => ({
    project: {
      ...state.project,
      characters: state.project.characters.map((c) =>
        c.id === id ? { ...c, ...updates } : c
      ),
    },
    isDirty: true,
  })),

  removeCharacter: (id) => set((state) => ({
    project: {
      ...state.project,
      characters: state.project.characters.filter((c) => c.id !== id),
    },
    isDirty: true,
  })),

  setVariable: (key, value) => set((state) => ({
    project: {
      ...state.project,
      variables: { ...state.project.variables, [key]: value },
    },
    isDirty: true,
  })),

  removeVariable: (key) => set((state) => {
    const vars = { ...state.project.variables };
    delete vars[key];
    return { project: { ...state.project, variables: vars }, isDirty: true };
  }),

  addChapter: () => set((state) => {
    const num = state.project.chapters.length + 1;
    const chapterId = `chapter_${num}`;
    const firstSceneId = `${chapterId}_scene_1`;
    const chapter: Chapter = {
      id: chapterId,
      title: `Глава ${num}`,
      number: num,
      firstSceneId,
      scenes: [{
        id: firstSceneId,
        charactersOnScreen: [],
        events: [{ type: 'narration', text: '' }],
      }],
    };
    return {
      project: {
        ...state.project,
        chapters: [...state.project.chapters, chapter],
        meta: { ...state.project.meta, chaptersCount: num },
      },
      isDirty: true,
    };
  }),

  removeChapter: (index) => set((state) => {
    if (state.project.chapters.length <= 1) return state;
    const chapters = state.project.chapters.filter((_, i) => i !== index);
    return {
      project: { ...state.project, chapters, meta: { ...state.project.meta, chaptersCount: chapters.length } },
      selectedChapterIndex: Math.min(state.selectedChapterIndex, chapters.length - 1),
      isDirty: true,
    };
  }),

  selectChapter: (index) => set({ selectedChapterIndex: index, selectedSceneId: null, selectedEventIndex: null }),

  addScene: (scene) => set((state) => {
    const chapters = state.project.chapters.map((ch, i) =>
      i === state.selectedChapterIndex ? { ...ch, scenes: [...ch.scenes, scene] } : ch
    );
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  updateScene: (sceneId, updates) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) => s.id === sceneId ? { ...s, ...updates } : s),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  removeScene: (sceneId) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.filter((s) => s.id !== sceneId),
    }));
    return {
      project: { ...state.project, chapters },
      selectedSceneId: state.selectedSceneId === sceneId ? null : state.selectedSceneId,
      isDirty: true,
    };
  }),

  selectScene: (sceneId) => set({ selectedSceneId: sceneId, selectedEventIndex: null }),

  // --- Персонажи на сцене ---
  addCharacterToScene: (sceneId, sc) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) => {
        if (s.id !== sceneId) return s;
        if (s.charactersOnScreen.some((c) => c.characterId === sc.characterId)) return s;
        return { ...s, charactersOnScreen: [...s.charactersOnScreen, sc] };
      }),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  updateCharacterOnScene: (sceneId, charId, updates) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) => {
        if (s.id !== sceneId) return s;
        return {
          ...s,
          charactersOnScreen: s.charactersOnScreen.map((c) =>
            c.characterId === charId ? { ...c, ...updates } : c
          ),
        };
      }),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  removeCharacterFromScene: (sceneId, charId) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) => {
        if (s.id !== sceneId) return s;
        return { ...s, charactersOnScreen: s.charactersOnScreen.filter((c) => c.characterId !== charId) };
      }),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  addEvent: (sceneId, event) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) =>
        s.id === sceneId ? { ...s, events: [...s.events, event] } : s
      ),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  updateEvent: (sceneId, eventIndex, event) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) => {
        if (s.id !== sceneId) return s;
        const events = [...s.events];
        events[eventIndex] = event;
        return { ...s, events };
      }),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  removeEvent: (sceneId, eventIndex) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) => {
        if (s.id !== sceneId) return s;
        return { ...s, events: s.events.filter((_, i) => i !== eventIndex) };
      }),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  moveEvent: (sceneId, from, to) => set((state) => {
    const chapters = state.project.chapters.map((ch) => ({
      ...ch,
      scenes: ch.scenes.map((s) => {
        if (s.id !== sceneId) return s;
        const events = [...s.events];
        const [moved] = events.splice(from, 1);
        events.splice(to, 0, moved);
        return { ...s, events };
      }),
    }));
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  selectEvent: (index) => set({ selectedEventIndex: index }),

  // --- Переводы ---
  setTranslation: (lang, translation) => set((state) => ({
    project: {
      ...state.project,
      translations: { ...(state.project.translations || {}), [lang]: translation },
    },
    isDirty: true,
  })),

  removeTranslation: (lang) => set((state) => {
    const translations = { ...(state.project.translations || {}) };
    delete translations[lang];
    return { project: { ...state.project, translations }, isDirty: true };
  }),

  updateTranslationText: (lang, original, translated) => set((state) => {
    const translations = { ...(state.project.translations || {}) };
    const existing = translations[lang];
    if (!existing) return state;
    translations[lang] = { ...existing, texts: { ...existing.texts, [original]: translated } };
    return { project: { ...state.project, translations }, isDirty: true };
  }),

  updateTranslationMeta: (lang, field, value) => set((state) => {
    const translations = { ...(state.project.translations || {}) };
    const existing = translations[lang];
    if (!existing) return state;
    const novel = { ...(existing.novel || {}) };
    if (field === 'novelTitle') novel.title = value;
    if (field === 'novelDescription') novel.description = value;
    translations[lang] = { ...existing, novel };
    return { project: { ...state.project, translations }, isDirty: true };
  }),

  updateTranslationCharacter: (lang, characterId, name) => set((state) => {
    const translations = { ...(state.project.translations || {}) };
    const existing = translations[lang];
    if (!existing) return state;
    const characters = { ...(existing.characters || {}) };
    characters[characterId] = { name };
    translations[lang] = { ...existing, characters };
    return { project: { ...state.project, translations }, isDirty: true };
  }),

  updateTranslationChapter: (lang, chapterId, title) => set((state) => {
    const translations = { ...(state.project.translations || {}) };
    const existing = translations[lang];
    if (!existing) return state;
    const chapters = { ...(existing.chapters || {}) };
    chapters[chapterId] = { title };
    translations[lang] = { ...existing, chapters };
    return { project: { ...state.project, translations }, isDirty: true };
  }),

  selectTranslationLang: (lang) => set({ selectedTranslationLang: lang }),

  // --- Позиция ноды в графе сцен ---
  // Не выставляем isDirty, чтобы перетаскивание ноды не помечало проект как
  // несохранённый — это чисто UI-состояние редактора.
  updateScenePosition: (chapterId, sceneId, position) => set((state) => {
    const chapters = state.project.chapters.map((ch) => {
      if (ch.id !== chapterId) return ch;
      return {
        ...ch,
        scenes: ch.scenes.map((s) =>
          s.id === sceneId ? { ...s, editorPosition: position } : s
        ),
      };
    });
    return { project: { ...state.project, chapters } };
  }),
    }),
    {
      name: 'amoria-editor-store',
      storage: createJSONStorage(() => localStorage),
      // Персистим только структуру новеллы и индексы выбора.
      // НЕ персистим:
      //   - images   (Map<string, File>)   — File не сериализуется в JSON
      //   - imageUrls (Map<string, string>) — blob: URL живёт только в текущей сессии
      // После refresh пользователь увидит структуру новеллы, но картинки
      // придётся перезагрузить — известное ограничение.
      partialize: (state) => ({
        project: state.project,
        selectedChapterIndex: state.selectedChapterIndex,
        selectedSceneId: state.selectedSceneId,
        selectedEventIndex: state.selectedEventIndex,
        selectedTranslationLang: state.selectedTranslationLang,
      }),
      version: 1,
    }
  )
);
