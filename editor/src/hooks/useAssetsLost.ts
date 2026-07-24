import { useEditorStore } from '../store/editorStore';
import type { NovelProject } from '../types/novel';

/** Ссылается ли проект хотя бы на один ассет (обложка, спрайты, фоны,
 *  слои, changeBackground, CG, аудио, аутфиты). Нужно, чтобы отличить
 *  «ассетов нет вообще» (валидная текстовая новелла) от «ассеты были,
 *  но потерялись» (старый localStorage-проект без IndexedDB-персиста). */
export function projectReferencesAssets(project: NovelProject): boolean {
  if (project.meta.coverImage) return true;
  for (const ch of project.characters) {
    for (const sp of ch.sprites) if (sp.image) return true;
    for (const o of ch.outfits || []) {
      if (o.thumbnail) return true;
      if (Object.values(o.sprites || {}).some(Boolean)) return true;
    }
  }
  for (const chap of project.chapters) {
    for (const sc of chap.scenes) {
      if (sc.background) return true;
      if (sc.music) return true;
      if (sc.backgroundLayers?.some((l) => l.image)) return true;
      if (sc.ending?.image) return true;
      for (const ev of sc.events) {
        if (ev.type === 'changeBackground' && ev.asset) return true;
        if (ev.type === 'playSound' && ev.asset) return true;
        if (ev.type === 'showCg' && ev.cgImage) return true;
        if (ev.type === 'showEmotion' && ev.image) return true;
        if (ev.voice) return true;
      }
    }
  }
  return false;
}

/**
 * Условие «ассеты потеряны»: гидратация уже отработала, проект реально
 * ссылается на ассеты, но Map ассетов пустая. С IndexedDB-персистом это
 * почти не случается — фолбэк для проектов, мигрированных из старого
 * localStorage (там картинки не сохранялись). Экспорт из-за отсутствия
 * ассетов не блокируется (текстовые новеллы валидны).
 */
export function useAssetsLost(): boolean {
  const hasHydrated = useEditorStore((s) => s.hasHydrated);
  const assetsSize = useEditorStore((s) => s.assets.size);
  const project = useEditorStore((s) => s.project);
  return hasHydrated && assetsSize === 0 && projectReferencesAssets(project);
}
