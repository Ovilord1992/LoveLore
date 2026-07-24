import { useEffect } from 'react';
import { useEditorStore } from '../store/editorStore';

function isTextInput(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tag = target.tagName;
  return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || target.isContentEditable;
}

/** Глобальные хоткеи редактора:
 *  Ctrl/Cmd+Z — undo, Shift+Ctrl/Cmd+Z / Ctrl/Cmd+Y — redo,
 *  Ctrl/Cmd+C / Ctrl/Cmd+V — копирование/вставка выделенного события.
 *  Внутри текстовых полей не перехватываем — там работает нативный
 *  undo/копипаст браузера. */
export function useHotkeys() {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const mod = e.metaKey || e.ctrlKey;
      if (!mod) return;
      if (isTextInput(e.target)) return;

      const key = e.key.toLowerCase();
      const temporal = useEditorStore.temporal.getState();

      if (key === 'z' && !e.shiftKey) {
        e.preventDefault();
        temporal.undo();
        return;
      }
      if ((key === 'z' && e.shiftKey) || key === 'y') {
        e.preventDefault();
        temporal.redo();
        return;
      }
      if (key === 'c') {
        // Не мешаем копированию выделенного текста на странице
        if (window.getSelection()?.toString()) return;
        const copied = useEditorStore.getState().copySelectedEvent();
        if (copied) e.preventDefault();
        return;
      }
      if (key === 'v') {
        const pasted = useEditorStore.getState().pasteEvent();
        if (pasted) e.preventDefault();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, []);
}
