import { create } from 'zustand';
import type { NovelProject, Character, Chapter, Scene, SceneEvent, NovelMeta } from '../types/novel';

const defaultMeta: NovelMeta = {
  id: 'new_novel',
  title: 'Новая новелла',
  description: '',
  author: '',
  tags: [],
  totalChapters: 1,
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

interface EditorState {
  project: NovelProject;
  selectedChapterIndex: number;
  selectedSceneId: string | null;
  selectedEventIndex: number | null;
  isDirty: boolean;

  // Проект
  setProject: (project: NovelProject) => void;
  updateMeta: (meta: Partial<NovelMeta>) => void;

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

  // События
  addEvent: (sceneId: string, event: SceneEvent) => void;
  updateEvent: (sceneId: string, eventIndex: number, event: SceneEvent) => void;
  removeEvent: (sceneId: string, eventIndex: number) => void;
  moveEvent: (sceneId: string, from: number, to: number) => void;
  selectEvent: (index: number | null) => void;
}

export const useEditorStore = create<EditorState>((set) => ({
  project: {
    meta: defaultMeta,
    characters: [],
    variables: {},
    chapters: [defaultChapter],
  },
  selectedChapterIndex: 0,
  selectedSceneId: 'scene_1',
  selectedEventIndex: null,
  isDirty: false,

  setProject: (project) => set({ project, isDirty: false, selectedChapterIndex: 0, selectedSceneId: null, selectedEventIndex: null }),

  updateMeta: (meta) => set((state) => ({
    project: { ...state.project, meta: { ...state.project.meta, ...meta } },
    isDirty: true,
  })),

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
        meta: { ...state.project.meta, totalChapters: num },
      },
      isDirty: true,
    };
  }),

  removeChapter: (index) => set((state) => {
    if (state.project.chapters.length <= 1) return state;
    const chapters = state.project.chapters.filter((_, i) => i !== index);
    return {
      project: { ...state.project, chapters, meta: { ...state.project.meta, totalChapters: chapters.length } },
      selectedChapterIndex: Math.min(state.selectedChapterIndex, chapters.length - 1),
      isDirty: true,
    };
  }),

  selectChapter: (index) => set({ selectedChapterIndex: index, selectedSceneId: null, selectedEventIndex: null }),

  addScene: (scene) => set((state) => {
    const chapters = [...state.project.chapters];
    const chapter = { ...chapters[state.selectedChapterIndex] };
    chapter.scenes = [...chapter.scenes, scene];
    chapters[state.selectedChapterIndex] = chapter;
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
}));
