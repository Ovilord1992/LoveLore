import { useEditorStore } from '../store/editorStore';
import type { NovelProject } from '../types/novel';

/** Ссылается ли проект хотя бы на одно изображение (обложка, спрайты, фоны,
 *  слои, changeBackground, CG). Нужно, чтобы отличить «картинок нет вообще»
 *  (валидная текстовая новелла) от «картинки были, но потерялись при refresh». */
export function projectReferencesImages(project: NovelProject): boolean {
  if (project.meta.coverImage) return true;
  for (const ch of project.characters) {
    for (const sp of ch.sprites) if (sp.image) return true;
  }
  for (const chap of project.chapters) {
    for (const sc of chap.scenes) {
      if (sc.background) return true;
      if (sc.backgroundLayers?.some((l) => l.image)) return true;
      for (const ev of sc.events) {
        if (ev.type === 'changeBackground' && ev.asset) return true;
        if (ev.type === 'showCg' && ev.cgImage) return true;
      }
    }
  }
  return false;
}

/**
 * Условие «ассеты потеряны после refresh»: persist уже отработал, проект
 * реально ссылается на изображения, но Map изображений пустая. Возвращает true
 * ТОЛЬКО в этом сочетании — для warning-баннера. Экспорт из-за отсутствия
 * картинок не блокируется (текстовые новеллы валидны).
 */
export function useAssetsLost(): boolean {
  const hasHydrated = useEditorStore((s) => s.hasHydrated);
  const imagesSize = useEditorStore((s) => s.images.size);
  const project = useEditorStore((s) => s.project);
  return hasHydrated && imagesSize === 0 && projectReferencesImages(project);
}
