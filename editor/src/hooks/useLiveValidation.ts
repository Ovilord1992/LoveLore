import { useEffect } from 'react';
import { useEditorStore } from '../store/editorStore';
import { validateProject } from '../utils/validator';

/** Live-валидация: перепроверка проекта через ~800 мс после последнего
 *  изменения (project или ассетов). Результат кладётся в стор —
 *  счётчик в тулбаре и кликабельный список во вкладке «Валидация». */
export function useLiveValidation() {
  const project = useEditorStore((s) => s.project);
  const assets = useEditorStore((s) => s.assets);
  const hasHydrated = useEditorStore((s) => s.hasHydrated);

  useEffect(() => {
    if (!hasHydrated) return;
    const timer = setTimeout(() => {
      const errors = validateProject(project, assets);
      useEditorStore.getState().setValidationErrors(errors);
    }, 800);
    return () => clearTimeout(timer);
  }, [project, assets, hasHydrated]);
}
