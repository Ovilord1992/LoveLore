import { useEffect, useMemo, useRef, useState } from 'react';
import { useEditorStore } from '../../store/editorStore';
import type { Scene } from '../../types/novel';
import { ChevronDown, Plus, X } from 'lucide-react';
import './common.css';

/** Первая реплика сцены — подпись в выпадающем списке (только для этого файла). */
function sceneSnippet(scene: Scene): string {
  for (const ev of scene.events) {
    if ((ev.type === 'dialogue' || ev.type === 'narration') && ev.text?.trim()) {
      const t = ev.text.trim().replace(/\s+/g, ' ');
      return t.length > 48 ? t.slice(0, 48) + '…' : t;
    }
    if (ev.type === 'choice' && ev.choices?.length) {
      return `выбор: ${ev.choices[0].text || '…'}`.slice(0, 48);
    }
  }
  return '';
}

interface SceneSelectProps {
  value: string; // '' = не задано
  onChange: (sceneId: string) => void;
  /** Показать пункт «— нет —» (сбрасывает в ''). */
  allowEmpty?: boolean;
  emptyLabel?: string;
  placeholder?: string;
  /** Кнопка «создать сцену и связать» внизу списка. */
  allowCreate?: boolean;
  className?: string;
}

/** Searchable-селект по сценам ТЕКУЩЕЙ главы (id + первая реплика) —
 *  заменяет свободный ввод ID сцены везде, где есть ссылки на сцены. */
export function SceneSelect({ value, onChange, allowEmpty, emptyLabel = '— нет —', placeholder = 'Сцена…', allowCreate = true, className }: SceneSelectProps) {
  const chapter = useEditorStore((s) => s.project.chapters[s.selectedChapterIndex]);
  const createScene = useEditorStore((s) => s.createScene);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const rootRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const scenes = useMemo(() => chapter?.scenes ?? [], [chapter]);
  const valueExists = !value || scenes.some((s) => s.id === value);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return scenes;
    return scenes.filter((s) =>
      s.id.toLowerCase().includes(q) || sceneSnippet(s).toLowerCase().includes(q)
    );
  }, [scenes, query]);

  useEffect(() => {
    if (!open) return;
    const onDocClick = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        setOpen(false);
        setQuery('');
      }
    };
    const onEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { setOpen(false); setQuery(''); }
    };
    document.addEventListener('mousedown', onDocClick);
    document.addEventListener('keydown', onEsc);
    return () => {
      document.removeEventListener('mousedown', onDocClick);
      document.removeEventListener('keydown', onEsc);
    };
  }, [open]);

  useEffect(() => {
    if (open) inputRef.current?.focus();
  }, [open]);

  const pick = (id: string) => {
    onChange(id);
    setOpen(false);
    setQuery('');
  };

  const handleCreate = () => {
    const id = createScene();
    if (id) pick(id);
  };

  return (
    <div className={`scene-select ${className || ''}`} ref={rootRef}>
      <button
        type="button"
        className={`scene-select-trigger ${!valueExists ? 'broken' : ''} ${!value ? 'placeholder' : ''}`}
        onClick={() => setOpen((o) => !o)}
        title={value ? (valueExists ? value : `Сцена "${value}" не найдена в главе`) : placeholder}
      >
        <span className="scene-select-value">{value || placeholder}</span>
        {value && allowEmpty && (
          <span
            className="scene-select-clear"
            role="button"
            aria-label="Очистить"
            onClick={(e) => { e.stopPropagation(); pick(''); }}
          >
            <X size={11} />
          </span>
        )}
        <ChevronDown size={12} />
      </button>
      {open && (
        <div className="scene-select-dropdown">
          <input
            ref={inputRef}
            className="scene-select-search"
            placeholder="Поиск по id или тексту…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && filtered.length > 0) pick(filtered[0].id);
            }}
          />
          <div className="scene-select-options">
            {allowEmpty && (
              <button type="button" className="scene-select-option empty" onClick={() => pick('')}>
                {emptyLabel}
              </button>
            )}
            {filtered.map((s) => {
              const snippet = sceneSnippet(s);
              return (
                <button
                  type="button"
                  key={s.id}
                  className={`scene-select-option ${s.id === value ? 'selected' : ''}`}
                  onClick={() => pick(s.id)}
                >
                  <span className="scene-select-id">{s.id}</span>
                  {snippet && <span className="scene-select-snippet">{snippet}</span>}
                </button>
              );
            })}
            {filtered.length === 0 && (
              <div className="scene-select-empty">Ничего не найдено</div>
            )}
          </div>
          {allowCreate && (
            <button type="button" className="scene-select-create" onClick={handleCreate}>
              <Plus size={12} /> Создать сцену и связать
            </button>
          )}
        </div>
      )}
    </div>
  );
}
