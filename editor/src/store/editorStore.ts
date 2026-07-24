import { create } from 'zustand';
import { temporal } from 'zundo';
import type { NovelProject, NovelTranslation, Character, Chapter, Scene, SceneEvent, SceneCharacter, NovelMeta } from '../types/novel';
import type { ValidationError } from '../utils/validator';
import { allSceneIds, uniqueSceneId, nextChapterNumber, uniqueCopySceneId } from '../utils/ids';
import {
  type ProjectInfo,
  type PersistedProjectState,
  newProjectId,
  loadProjectsList,
  saveProjectsList,
  loadCurrentProjectId,
  saveCurrentProjectId,
  saveProjectState,
  loadProjectState,
  saveAsset,
  deleteAsset,
  loadAssets,
  replaceAssets,
  clearAssets as clearAssetsIdb,
  deleteProjectData,
  readLegacyLocalStorage,
  removeLegacyLocalStorage,
} from './persistence';

const defaultMeta: NovelMeta = {
  id: 'new_novel',
  title: 'Новая новелла',
  description: '',
  author: '',
  tags: [],
  chaptersCount: 1,
};

function makeDefaultProject(): NovelProject {
  return {
    meta: { ...defaultMeta },
    characters: [],
    variables: {},
    chapters: [{
      id: 'chapter_1',
      title: 'Глава 1',
      number: 1,
      firstSceneId: 'scene_1',
      scenes: [{
        id: 'scene_1',
        charactersOnScreen: [],
        events: [{ type: 'narration', text: 'Начало истории...' }],
      }],
    }],
  };
}

export type SidebarTab = 'meta' | 'characters' | 'chapters' | 'variables' | 'audio' | 'translations' | 'search' | 'publish' | 'validate';

// assets: Map<путь_в_ZIP, File> — картинки И аудио (напр. "backgrounds/city.png",
// "music/theme.mp3", "voice/ch1/mia_001.mp3" → File). Персистятся в IndexedDB.
interface EditorState {
  project: NovelProject;
  assets: Map<string, File>;
  assetUrls: Map<string, string>;
  projects: ProjectInfo[];
  currentProjectId: string;
  selectedChapterIndex: number;
  selectedSceneId: string | null;
  selectedEventIndex: number | null;
  selectedTranslationLang: string | null;
  isDirty: boolean;
  // True после начальной загрузки из IndexedDB — компоненты могут различать
  // "первый запуск" vs "после refresh".
  hasHydrated: boolean;
  setHasHydrated: (v: boolean) => void;

  // UI
  sidebarTab: SidebarTab;
  setSidebarTab: (tab: SidebarTab) => void;
  validationErrors: ValidationError[];
  setValidationErrors: (errors: ValidationError[]) => void;
  focusSceneRequest: { sceneId: string; nonce: number } | null;
  focusScene: (sceneId: string) => void;
  eventClipboard: SceneEvent | null;

  // Проект (данные)
  setProject: (project: NovelProject) => void;
  updateMeta: (meta: Partial<NovelMeta>) => void;

  // Мультипроект
  setProjectsMeta: (projects: ProjectInfo[], currentProjectId: string) => void;
  createProject: (name?: string) => Promise<void>;
  switchProject: (id: string) => Promise<void>;
  deleteProject: (id: string) => Promise<void>;
  renameProject: (id: string, name: string) => void;

  // Ассеты (картинки и аудио)
  addAsset: (zipPath: string, file: File) => void;
  removeAsset: (zipPath: string) => void;
  getAssetUrl: (zipPath: string) => string | undefined;
  clearAssets: () => void;
  setAssets: (assets: Map<string, File>) => void;

  // Персонажи
  addCharacter: (character: Character) => void;
  updateCharacter: (id: string, updates: Partial<Character>) => void;
  removeCharacter: (id: string) => void;

  // Переменные
  setVariable: (key: string, value: string | number | boolean) => void;
  removeVariable: (key: string) => void;

  // Главы
  addChapter: () => void;
  updateChapter: (index: number, updates: Partial<Chapter>) => void;
  removeChapter: (index: number) => void;
  selectChapter: (index: number) => void;

  // Сцены
  addScene: (scene: Scene) => void;
  updateScene: (sceneId: string, updates: Partial<Scene>) => void;
  removeScene: (sceneId: string) => void;
  selectScene: (sceneId: string | null) => void;
  duplicateScene: (sceneId: string) => void;
  /** Создать пустую сцену в текущей главе, вернуть её id (для «создать и связать»). */
  createScene: () => string;

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
  copySelectedEvent: () => boolean;
  pasteEvent: () => boolean;

  // Переводы
  setTranslation: (lang: string, translation: NovelTranslation) => void;
  removeTranslation: (lang: string) => void;
  updateTranslationText: (lang: string, original: string, translated: string) => void;
  /** Перенести перевод с устаревшего ключа-оригинала на новый (детект устаревших). */
  remapTranslationKey: (lang: string, oldOriginal: string, newOriginal: string) => void;
  updateTranslationMeta: (lang: string, field: 'novelTitle' | 'novelDescription', value: string) => void;
  updateTranslationCharacter: (lang: string, characterId: string, name: string) => void;
  updateTranslationChapter: (lang: string, chapterId: string, title: string) => void;
  selectTranslationLang: (lang: string | null) => void;

  // Позиция ноды в SceneGraph — сохраняется между переключениями глав
  updateScenePosition: (chapterId: string, sceneId: string, position: { x: number; y: number }) => void;
}

export const useEditorStore = create<EditorState>()(
  temporal(
    (set, get) => ({
  project: makeDefaultProject(),
  assets: new Map(),
  assetUrls: new Map(),
  projects: [],
  currentProjectId: '',
  selectedChapterIndex: 0,
  selectedSceneId: 'scene_1',
  selectedEventIndex: null,
  selectedTranslationLang: null,
  isDirty: false,
  hasHydrated: false,
  setHasHydrated: (v) => set({ hasHydrated: v }),

  // --- UI ---
  sidebarTab: 'meta',
  setSidebarTab: (tab) => set({ sidebarTab: tab }),
  validationErrors: [],
  setValidationErrors: (errors) => set({ validationErrors: errors }),
  focusSceneRequest: null,
  focusScene: (sceneId) => set({ focusSceneRequest: { sceneId, nonce: Date.now() } }),
  eventClipboard: null,

  setProject: (project) => set({ project, isDirty: false, selectedChapterIndex: 0, selectedSceneId: null, selectedEventIndex: null }),

  updateMeta: (meta) => set((state) => ({
    project: { ...state.project, meta: { ...state.project.meta, ...meta } },
    isDirty: true,
  })),

  // --- Мультипроект ---
  setProjectsMeta: (projects, currentProjectId) => set({ projects, currentProjectId }),

  createProject: async (name) => {
    const state = get();
    // Сохраняем текущий проект перед переключением
    await flushProjectSave();
    const id = newProjectId();
    const info: ProjectInfo = {
      id,
      name: name || `Проект ${state.projects.length + 1}`,
      updatedAt: Date.now(),
    };
    const projects = [...get().projects, info];
    const fresh = makeDefaultProject();
    await saveProjectState(id, {
      project: fresh,
      selectedChapterIndex: 0,
      selectedSceneId: 'scene_1',
      selectedEventIndex: null,
      selectedTranslationLang: null,
    });
    await saveProjectsList(projects);
    await saveCurrentProjectId(id);
    applyLoadedProject(set, {
      project: fresh,
      selectedChapterIndex: 0,
      selectedSceneId: 'scene_1',
      selectedEventIndex: null,
      selectedTranslationLang: null,
    }, new Map(), projects, id);
  },

  switchProject: async (id) => {
    const state = get();
    if (id === state.currentProjectId) return;
    if (!state.projects.some((p) => p.id === id)) return;
    await flushProjectSave();
    const persisted = await loadProjectState(id);
    const assets = await loadAssets(id);
    await saveCurrentProjectId(id);
    applyLoadedProject(set, persisted ?? {
      project: makeDefaultProject(),
      selectedChapterIndex: 0,
      selectedSceneId: null,
      selectedEventIndex: null,
      selectedTranslationLang: null,
    }, assets, get().projects, id);
  },

  deleteProject: async (id) => {
    const state = get();
    if (!state.projects.some((p) => p.id === id)) return;
    const remaining = state.projects.filter((p) => p.id !== id);
    await deleteProjectData(id);
    if (id !== state.currentProjectId) {
      await saveProjectsList(remaining);
      set({ projects: remaining });
      return;
    }
    // Удаляем текущий: переключаемся на первый оставшийся или создаём новый
    cancelPendingSave();
    if (remaining.length > 0) {
      const target = remaining[0];
      const persisted = await loadProjectState(target.id);
      const assets = await loadAssets(target.id);
      await saveProjectsList(remaining);
      await saveCurrentProjectId(target.id);
      applyLoadedProject(set, persisted ?? {
        project: makeDefaultProject(),
        selectedChapterIndex: 0,
        selectedSceneId: null,
        selectedEventIndex: null,
        selectedTranslationLang: null,
      }, assets, remaining, target.id);
    } else {
      const newId = newProjectId();
      const info: ProjectInfo = { id: newId, name: 'Проект 1', updatedAt: Date.now() };
      const fresh = makeDefaultProject();
      await saveProjectState(newId, {
        project: fresh,
        selectedChapterIndex: 0,
        selectedSceneId: 'scene_1',
        selectedEventIndex: null,
        selectedTranslationLang: null,
      });
      await saveProjectsList([info]);
      await saveCurrentProjectId(newId);
      applyLoadedProject(set, {
        project: fresh,
        selectedChapterIndex: 0,
        selectedSceneId: 'scene_1',
        selectedEventIndex: null,
        selectedTranslationLang: null,
      }, new Map(), [info], newId);
    }
  },

  renameProject: (id, name) => {
    const projects = get().projects.map((p) => p.id === id ? { ...p, name } : p);
    set({ projects });
    void saveProjectsList(projects);
  },

  // --- Ассеты ---
  addAsset: (zipPath, file) => set((state) => {
    const assets = new Map(state.assets);
    const assetUrls = new Map(state.assetUrls);
    // Освобождаем старый URL
    const oldUrl = assetUrls.get(zipPath);
    if (oldUrl) URL.revokeObjectURL(oldUrl);
    assets.set(zipPath, file);
    assetUrls.set(zipPath, URL.createObjectURL(file));
    if (state.currentProjectId) void saveAsset(state.currentProjectId, zipPath, file);
    return { assets, assetUrls, isDirty: true };
  }),

  removeAsset: (zipPath) => set((state) => {
    const assets = new Map(state.assets);
    const assetUrls = new Map(state.assetUrls);
    const url = assetUrls.get(zipPath);
    if (url) URL.revokeObjectURL(url);
    assets.delete(zipPath);
    assetUrls.delete(zipPath);
    if (state.currentProjectId) void deleteAsset(state.currentProjectId, zipPath);
    return { assets, assetUrls, isDirty: true };
  }),

  getAssetUrl: (zipPath) => get().assetUrls.get(zipPath),

  clearAssets: () => set((state) => {
    state.assetUrls.forEach((url) => URL.revokeObjectURL(url));
    if (state.currentProjectId) void clearAssetsIdb(state.currentProjectId);
    return { assets: new Map(), assetUrls: new Map() };
  }),

  setAssets: (assets) => set((state) => {
    state.assetUrls.forEach((url) => URL.revokeObjectURL(url));
    const assetUrls = new Map<string, string>();
    assets.forEach((file, path) => assetUrls.set(path, URL.createObjectURL(file)));
    if (state.currentProjectId) void replaceAssets(state.currentProjectId, assets);
    return { assets, assetUrls };
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
    // Номер = max(number)+1 — гарантирует уникальный id даже при разрывах.
    const num = nextChapterNumber(state.project.chapters);
    const chapterId = `chapter_${num}`;
    // Уникальный id сцены среди ВСЕХ глав (id сцен обязаны быть глобально
    // уникальны, т.к. updateScene ищет сцену по id во всех главах).
    const firstSceneId = uniqueSceneId(chapterId, allSceneIds(state.project.chapters));
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
    const chapters = [...state.project.chapters, chapter];
    return {
      project: {
        ...state.project,
        chapters,
        meta: { ...state.project.meta, chaptersCount: chapters.length },
      },
      isDirty: true,
    };
  }),

  updateChapter: (index, updates) => set((state) => {
    const chapters = state.project.chapters.map((ch, i) =>
      i === index ? { ...ch, ...updates } : ch
    );
    return { project: { ...state.project, chapters }, isDirty: true };
  }),

  removeChapter: (index) => set((state) => {
    if (state.project.chapters.length <= 1) return state;
    // Перенумеровываем оставшиеся главы в непрерывную последовательность 1..N
    // (клиент требует chapter_1..chapter_N, number:int с 1). Id сцен НЕ трогаем —
    // они остаются глобально уникальными, а firstSceneId по-прежнему ссылается
    // на существующую сцену внутри главы.
    const chapters = state.project.chapters
      .filter((_, i) => i !== index)
      .map((ch, i) => {
        const number = i + 1;
        return { ...ch, number, id: `chapter_${number}` };
      });
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
    const chapters = state.project.chapters.map((ch) => {
      if (!ch.scenes.some((s) => s.id === sceneId)) return ch;
      // Удаляем сцену и вычищаем висячие ссылки на неё у остальных сцен главы.
      const scenes = ch.scenes
        .filter((s) => s.id !== sceneId)
        .map((s) => ({
          ...s,
          nextSceneId: s.nextSceneId === sceneId ? undefined : s.nextSceneId,
          branches: s.branches?.map((b) => b.nextSceneId === sceneId ? { ...b, nextSceneId: '' } : b),
          events: s.events.map((ev) =>
            ev.type === 'choice' && ev.choices
              ? { ...ev, choices: ev.choices.map((c) => c.nextSceneId === sceneId ? { ...c, nextSceneId: '' } : c) }
              : ev
          ),
        }));
      // Если удалили начальную сцену — переустанавливаем firstSceneId на первую
      // из оставшихся (или пусто, если сцен не осталось — валидатор поймает).
      const firstSceneId = ch.firstSceneId === sceneId ? (scenes[0]?.id ?? '') : ch.firstSceneId;
      return { ...ch, scenes, firstSceneId };
    });
    return {
      project: { ...state.project, chapters },
      selectedSceneId: state.selectedSceneId === sceneId ? null : state.selectedSceneId,
      isDirty: true,
    };
  }),

  selectScene: (sceneId) => set({ selectedSceneId: sceneId, selectedEventIndex: null }),

  duplicateScene: (sceneId) => set((state) => {
    const chIdx = state.project.chapters.findIndex((ch) => ch.scenes.some((s) => s.id === sceneId));
    if (chIdx === -1) return state;
    const source = state.project.chapters[chIdx].scenes.find((s) => s.id === sceneId)!;
    const newId = uniqueCopySceneId(sceneId, allSceneIds(state.project.chapters));
    const copy: Scene = JSON.parse(JSON.stringify(source));
    copy.id = newId;
    copy.editorPosition = source.editorPosition
      ? { x: source.editorPosition.x + 48, y: source.editorPosition.y + 48 }
      : undefined;
    const chapters = state.project.chapters.map((ch, i) =>
      i === chIdx ? { ...ch, scenes: [...ch.scenes, copy] } : ch
    );
    return {
      project: { ...state.project, chapters },
      selectedSceneId: newId,
      selectedEventIndex: null,
      isDirty: true,
    };
  }),

  createScene: () => {
    const state = get();
    const chapter = state.project.chapters[state.selectedChapterIndex];
    if (!chapter) return '';
    const sceneId = uniqueSceneId(chapter.id, allSceneIds(state.project.chapters));
    const scene: Scene = {
      id: sceneId,
      charactersOnScreen: [],
      events: [{ type: 'narration', text: '' }],
    };
    set((s) => {
      const chapters = s.project.chapters.map((ch, i) =>
        i === s.selectedChapterIndex ? { ...ch, scenes: [...ch.scenes, scene] } : ch
      );
      return { project: { ...s.project, chapters }, isDirty: true };
    });
    return sceneId;
  },

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

  copySelectedEvent: () => {
    const state = get();
    if (state.selectedEventIndex === null || !state.selectedSceneId) return false;
    const chapter = state.project.chapters[state.selectedChapterIndex];
    const scene = chapter?.scenes.find((s) => s.id === state.selectedSceneId);
    const event = scene?.events[state.selectedEventIndex];
    if (!event) return false;
    set({ eventClipboard: JSON.parse(JSON.stringify(event)) as SceneEvent });
    return true;
  },

  pasteEvent: () => {
    const state = get();
    const clip = state.eventClipboard;
    if (!clip || !state.selectedSceneId) return false;
    const sceneId = state.selectedSceneId;
    const insertAt = state.selectedEventIndex !== null ? state.selectedEventIndex + 1 : undefined;
    set((s) => {
      const chapters = s.project.chapters.map((ch) => ({
        ...ch,
        scenes: ch.scenes.map((sc) => {
          if (sc.id !== sceneId) return sc;
          const events = [...sc.events];
          const idx = insertAt !== undefined && insertAt <= events.length ? insertAt : events.length;
          events.splice(idx, 0, JSON.parse(JSON.stringify(clip)) as SceneEvent);
          return { ...sc, events };
        }),
      }));
      const scene = chapters[s.selectedChapterIndex]?.scenes.find((sc) => sc.id === sceneId);
      const idx = insertAt !== undefined && scene && insertAt < scene.events.length ? insertAt : (scene ? scene.events.length - 1 : null);
      return { project: { ...s.project, chapters }, selectedEventIndex: idx, isDirty: true };
    });
    return true;
  },

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
    // Пустой перевод НЕ храним: иначе на клиенте `texts[original] ?? original`
    // подменит оригинал пустышкой. Отсутствие ключа = fallback на оригинал.
    const texts = { ...existing.texts };
    if (translated && translated.trim()) {
      texts[original] = translated;
    } else {
      delete texts[original];
    }
    translations[lang] = { ...existing, texts };
    return { project: { ...state.project, translations }, isDirty: true };
  }),

  remapTranslationKey: (lang, oldOriginal, newOriginal) => set((state) => {
    const translations = { ...(state.project.translations || {}) };
    const existing = translations[lang];
    if (!existing) return state;
    const texts = { ...existing.texts };
    const value = texts[oldOriginal];
    if (value === undefined || !newOriginal.trim()) return state;
    delete texts[oldOriginal];
    texts[newOriginal] = value;
    translations[lang] = { ...existing, texts };
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
      // История undo/redo — ТОЛЬКО JSON-состояние проекта. Map ассетов и
      // выборки/UI не входят (Map<File> не откатываем — blob'ы живут отдельно).
      partialize: (state) => ({ project: state.project }),
      limit: 100,
      // Не создаём запись истории, если project не менялся (клики выбора и т.п.)
      equality: (past, current) => past.project === current.project,
      // Группируем быстрые правки (набор текста): не чаще 1 записи в 600 мс.
      handleSet: (handleSet) => {
        let lastSavedAt = 0;
        return (...args: Parameters<typeof handleSet>) => {
          const now = Date.now();
          if (now - lastSavedAt < 600) return;
          lastSavedAt = now;
          handleSet(...args);
        };
      },
    }
  )
);

// ───────────────────────── Персист (IndexedDB) ─────────────────────────

let saveTimer: ReturnType<typeof setTimeout> | null = null;
let pendingSave: { projectId: string } | null = null;

function collectPersistedState(): PersistedProjectState {
  const s = useEditorStore.getState();
  return {
    project: s.project,
    selectedChapterIndex: s.selectedChapterIndex,
    selectedSceneId: s.selectedSceneId,
    selectedEventIndex: s.selectedEventIndex,
    selectedTranslationLang: s.selectedTranslationLang,
  };
}

function cancelPendingSave() {
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = null;
  pendingSave = null;
}

async function doSave(projectId: string) {
  const state = collectPersistedState();
  await saveProjectState(projectId, state);
  const s = useEditorStore.getState();
  const projects = s.projects.map((p) => p.id === projectId ? { ...p, updatedAt: Date.now() } : p);
  useEditorStore.setState({ projects });
  await saveProjectsList(projects);
}

/** Немедленно сохранить отложенные изменения текущего проекта. */
export async function flushProjectSave(): Promise<void> {
  const target = pendingSave?.projectId || useEditorStore.getState().currentProjectId;
  cancelPendingSave();
  if (!target) return;
  await doSave(target);
}

function scheduleSave() {
  const projectId = useEditorStore.getState().currentProjectId;
  if (!projectId) return;
  pendingSave = { projectId };
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    const id = pendingSave?.projectId;
    cancelPendingSave();
    if (id) void doSave(id);
  }, 400);
}

/** Применить загруженный проект в стор: пауза истории + сброс undo-стека. */
function applyLoadedProject(
  set: (partial: Partial<EditorState>) => void,
  persisted: PersistedProjectState,
  assets: Map<string, File>,
  projects: ProjectInfo[],
  currentProjectId: string,
) {
  const temporalApi = useEditorStore.temporal.getState();
  temporalApi.pause();
  const old = useEditorStore.getState();
  old.assetUrls.forEach((url) => URL.revokeObjectURL(url));
  const assetUrls = new Map<string, string>();
  assets.forEach((file, path) => assetUrls.set(path, URL.createObjectURL(file)));
  set({
    project: persisted.project,
    selectedChapterIndex: Math.min(persisted.selectedChapterIndex, persisted.project.chapters.length - 1),
    selectedSceneId: persisted.selectedSceneId,
    selectedEventIndex: persisted.selectedEventIndex,
    selectedTranslationLang: persisted.selectedTranslationLang,
    assets,
    assetUrls,
    projects,
    currentProjectId,
    isDirty: false,
    eventClipboard: null,
    validationErrors: [],
    focusSceneRequest: null,
  });
  temporalApi.clear();
  temporalApi.resume();
}

let persistenceInitialized = false;

/** Инициализация персиста: миграция старого localStorage → «Проект 1»,
 *  загрузка текущего проекта и ассетов из IndexedDB, подписка на автосохранение.
 *  Вызывается один раз из main.tsx. */
export async function initEditorPersistence(): Promise<void> {
  if (persistenceInitialized) return;
  persistenceInitialized = true;

  try {
    let projects = await loadProjectsList();
    let currentId = await loadCurrentProjectId();

    if (projects.length === 0) {
      // Первый запуск ИЛИ миграция со старого однослотового localStorage.
      const legacy = readLegacyLocalStorage();
      const id = newProjectId();
      const info: ProjectInfo = {
        id,
        name: legacy?.project.meta.title?.trim() ? legacy.project.meta.title : 'Проект 1',
        updatedAt: Date.now(),
      };
      const state: PersistedProjectState = legacy ?? {
        project: makeDefaultProject(),
        selectedChapterIndex: 0,
        selectedSceneId: 'scene_1',
        selectedEventIndex: null,
        selectedTranslationLang: null,
      };
      await saveProjectState(id, state);
      await saveProjectsList([info]);
      await saveCurrentProjectId(id);
      if (legacy) removeLegacyLocalStorage();
      projects = [info];
      currentId = id;
    }

    if (!currentId || !projects.some((p) => p.id === currentId)) {
      currentId = projects[0].id;
      await saveCurrentProjectId(currentId);
    }

    const persisted = await loadProjectState(currentId);
    const assets = await loadAssets(currentId);
    applyLoadedProject(
      (partial) => useEditorStore.setState(partial),
      persisted ?? {
        project: makeDefaultProject(),
        selectedChapterIndex: 0,
        selectedSceneId: 'scene_1',
        selectedEventIndex: null,
        selectedTranslationLang: null,
      },
      assets,
      projects,
      currentId,
    );
  } catch (err) {
    console.error('[editor] Ошибка инициализации IndexedDB-персиста:', err);
  } finally {
    useEditorStore.setState({ hasHydrated: true });
  }

  // Автосохранение JSON-состояния (ассеты пишутся сразу в своих экшенах).
  let prev = collectPersistedState();
  useEditorStore.subscribe((state) => {
    if (!state.hasHydrated || !state.currentProjectId) return;
    const next: PersistedProjectState = {
      project: state.project,
      selectedChapterIndex: state.selectedChapterIndex,
      selectedSceneId: state.selectedSceneId,
      selectedEventIndex: state.selectedEventIndex,
      selectedTranslationLang: state.selectedTranslationLang,
    };
    const changed =
      next.project !== prev.project ||
      next.selectedChapterIndex !== prev.selectedChapterIndex ||
      next.selectedSceneId !== prev.selectedSceneId ||
      next.selectedEventIndex !== prev.selectedEventIndex ||
      next.selectedTranslationLang !== prev.selectedTranslationLang;
    prev = next;
    if (changed) scheduleSave();
  });

  // Лучший из возможных flush при закрытии вкладки: IDB-транзакция, начатая
  // до unload, обычно успевает завершиться.
  window.addEventListener('beforeunload', () => {
    if (pendingSave) void flushProjectSave();
  });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden' && pendingSave) void flushProjectSave();
  });
}
