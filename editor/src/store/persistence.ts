// Персист редактора в IndexedDB (idb-keyval):
//  - список проектов и текущий проект: ключи 'projects:list', 'projects:current'
//  - JSON-состояние проекта: 'project:<id>:state'
//  - ассеты (картинки И аудио) по одному ключу на файл: 'asset:<id>:<zipPath>'
// Blob/File переживают structured clone, поэтому ассеты восстанавливаются
// после refresh — в отличие от старого localStorage-персиста.
import { get, set, del, keys, delMany } from 'idb-keyval';
import type { NovelProject } from '../types/novel';

export interface ProjectInfo {
  id: string;
  name: string;
  updatedAt: number;
}

export interface PersistedProjectState {
  project: NovelProject;
  selectedChapterIndex: number;
  selectedSceneId: string | null;
  selectedEventIndex: number | null;
  selectedTranslationLang: string | null;
}

const LIST_KEY = 'projects:list';
const CURRENT_KEY = 'projects:current';
const LEGACY_LS_KEY = 'amoria-editor-store';

const stateKey = (id: string) => `project:${id}:state`;
const assetKeyPrefix = (id: string) => `asset:${id}:`;
const assetKey = (id: string, zipPath: string) => `${assetKeyPrefix(id)}${zipPath}`;

export function newProjectId(): string {
  return `p_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export async function loadProjectsList(): Promise<ProjectInfo[]> {
  return (await get<ProjectInfo[]>(LIST_KEY)) || [];
}

export async function saveProjectsList(list: ProjectInfo[]): Promise<void> {
  await set(LIST_KEY, list);
}

export async function loadCurrentProjectId(): Promise<string | null> {
  return (await get<string>(CURRENT_KEY)) || null;
}

export async function saveCurrentProjectId(id: string): Promise<void> {
  await set(CURRENT_KEY, id);
}

export async function saveProjectState(id: string, state: PersistedProjectState): Promise<void> {
  // Прогоняем через JSON, чтобы в IDB гарантированно попал plain-object
  // без прототипов/функций (и чтобы поведение совпадало с экспортом).
  await set(stateKey(id), JSON.parse(JSON.stringify(state)) as PersistedProjectState);
}

export async function loadProjectState(id: string): Promise<PersistedProjectState | null> {
  return (await get<PersistedProjectState>(stateKey(id))) || null;
}

export async function saveAsset(projectId: string, zipPath: string, file: Blob): Promise<void> {
  await set(assetKey(projectId, zipPath), file);
}

export async function deleteAsset(projectId: string, zipPath: string): Promise<void> {
  await del(assetKey(projectId, zipPath));
}

/** Загрузить все ассеты проекта: Map<zipPath, File>. */
export async function loadAssets(projectId: string): Promise<Map<string, File>> {
  const prefix = assetKeyPrefix(projectId);
  const allKeys = (await keys()) as IDBValidKey[];
  const result = new Map<string, File>();
  for (const k of allKeys) {
    if (typeof k !== 'string' || !k.startsWith(prefix)) continue;
    const zipPath = k.slice(prefix.length);
    const blob = await get<Blob>(k);
    if (!blob) continue;
    const name = zipPath.split('/').pop() || zipPath;
    const file = blob instanceof File ? blob : new File([blob], name, { type: blob.type });
    result.set(zipPath, file);
  }
  return result;
}

/** Полностью заменить ассеты проекта (например, при импорте ZIP). */
export async function replaceAssets(projectId: string, assets: Map<string, File>): Promise<void> {
  await clearAssets(projectId);
  for (const [zipPath, file] of assets) {
    await set(assetKey(projectId, zipPath), file);
  }
}

export async function clearAssets(projectId: string): Promise<void> {
  const prefix = assetKeyPrefix(projectId);
  const allKeys = (await keys()) as IDBValidKey[];
  const toDelete = allKeys.filter((k) => typeof k === 'string' && k.startsWith(prefix));
  if (toDelete.length) await delMany(toDelete);
}

/** Удалить проект целиком (state + ассеты). */
export async function deleteProjectData(projectId: string): Promise<void> {
  await del(stateKey(projectId));
  await clearAssets(projectId);
}

/** Одноразовая миграция старого однослотового localStorage-персиста
 *  в «Проект 1». Возвращает состояние, если миграция произошла. */
export function readLegacyLocalStorage(): PersistedProjectState | null {
  try {
    const raw = localStorage.getItem(LEGACY_LS_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { state?: Partial<PersistedProjectState> };
    const st = parsed?.state;
    if (!st || !st.project || !st.project.meta || !Array.isArray(st.project.chapters)) return null;
    return {
      project: st.project as NovelProject,
      selectedChapterIndex: st.selectedChapterIndex ?? 0,
      selectedSceneId: st.selectedSceneId ?? null,
      selectedEventIndex: st.selectedEventIndex ?? null,
      selectedTranslationLang: st.selectedTranslationLang ?? null,
    };
  } catch {
    return null;
  }
}

export function removeLegacyLocalStorage(): void {
  try {
    localStorage.removeItem(LEGACY_LS_KEY);
  } catch {
    // ignore
  }
}
