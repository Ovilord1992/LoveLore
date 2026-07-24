import { useState, useEffect, useRef } from 'react';
import { useStore } from 'zustand';
import { useEditorStore } from './store/editorStore';
import { useHotkeys } from './hooks/useHotkeys';
import { useLiveValidation } from './hooks/useLiveValidation';
import { Sidebar } from './components/sidebar/Sidebar';
import { SceneGraph } from './components/editor/SceneGraph';
import { EventEditor } from './components/editor/EventEditor';
import { ScenePreview } from './components/preview/ScenePreview';
import { GamePreview } from './components/preview/GamePreview';
import { Undo2, Redo2, ChevronDown, Plus, Pencil, Trash2, AlertTriangle, CheckCircle } from 'lucide-react';
import './App.css';

export default function App() {
  const [previewMode, setPreviewMode] = useState<'static' | 'play'>('static');
  const { project, isDirty, selectedSceneId, selectedChapterIndex, hasHydrated } = useEditorStore();
  const chapter = project.chapters[selectedChapterIndex];
  const scene = chapter?.scenes.find((s) => s.id === selectedSceneId);

  useHotkeys();
  useLiveValidation();

  // Предупреждаем о несохранённых изменениях при закрытии/перезагрузке вкладки.
  useEffect(() => {
    if (!isDirty) return;
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = '';
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, [isDirty]);

  if (!hasHydrated) {
    return (
      <div className="app">
        <div className="app-loading">
          <span className="logo-icon">✦</span> Загрузка проекта…
        </div>
      </div>
    );
  }

  return (
    <div className="app">
      {/* Header */}
      <header className="app-header">
        <div className="header-logo">
          <span className="logo-icon">✦</span>
          <span className="logo-text">Amoria Editor</span>
        </div>
        <div className="header-center">
          <ProjectSwitcher />
          <UndoRedoButtons />
          <ValidationBadge />
        </div>
        <div className="header-info">
          <span className="project-name">{project.meta.title || 'Без названия'}</span>
          {isDirty && <span className="unsaved-badge" title="Есть не выгруженные в ZIP изменения (в браузере всё сохраняется автоматически)">●</span>}
        </div>
      </header>

      {/* Main Layout */}
      <div className="app-body">
        {/* Левая панель — Sidebar */}
        <Sidebar />

        {/* Центр — Граф + Редактор */}
        <div className="center-panel">
          <div className="graph-panel">
            <SceneGraph />
          </div>
          {scene && (
            <div className="editor-panel">
              <EventEditor />
            </div>
          )}
        </div>

        {/* Правая панель — Превью */}
        <div className="preview-panel">
          <div className="preview-tabs">
            <button
              className={`preview-tab ${previewMode === 'static' ? 'active' : ''}`}
              onClick={() => setPreviewMode('static')}
            >
              📋 Превью
            </button>
            <button
              className={`preview-tab ${previewMode === 'play' ? 'active' : ''}`}
              onClick={() => setPreviewMode('play')}
            >
              ▶ Играть
            </button>
          </div>
          {previewMode === 'static' ? <ScenePreview /> : <GamePreview />}
        </div>
      </div>
    </div>
  );
}

/** Кнопки undo/redo в тулбаре (история zundo, хоткеи Ctrl/Cmd+Z, Shift+Ctrl/Cmd+Z). */
function UndoRedoButtons() {
  const { undo, redo, pastStates, futureStates } = useStore(useEditorStore.temporal);
  return (
    <div className="toolbar-group">
      <button
        className="toolbar-btn"
        onClick={() => undo()}
        disabled={pastStates.length === 0}
        title="Отменить (Ctrl/Cmd+Z)"
      >
        <Undo2 size={15} />
      </button>
      <button
        className="toolbar-btn"
        onClick={() => redo()}
        disabled={futureStates.length === 0}
        title="Повторить (Shift+Ctrl/Cmd+Z)"
      >
        <Redo2 size={15} />
      </button>
    </div>
  );
}

/** Счётчик ошибок live-валидации; клик открывает вкладку «Валидация». */
function ValidationBadge() {
  const errors = useEditorStore((s) => s.validationErrors);
  const setSidebarTab = useEditorStore((s) => s.setSidebarTab);
  const errorCount = errors.filter((e) => e.type === 'error').length;
  const warnCount = errors.filter((e) => e.type === 'warning').length;

  return (
    <button
      className={`toolbar-validation ${errorCount > 0 ? 'has-errors' : warnCount > 0 ? 'has-warnings' : 'ok'}`}
      onClick={() => setSidebarTab('validate')}
      title="Открыть вкладку «Валидация»"
    >
      {errorCount > 0 ? (
        <><AlertTriangle size={13} /> {errorCount}{warnCount > 0 ? ` / ⚠ ${warnCount}` : ''}</>
      ) : warnCount > 0 ? (
        <><AlertTriangle size={13} /> ⚠ {warnCount}</>
      ) : (
        <><CheckCircle size={13} /> OK</>
      )}
    </button>
  );
}

/** Переключатель проектов: список, создание, переименование, удаление. */
function ProjectSwitcher() {
  const projects = useEditorStore((s) => s.projects);
  const currentProjectId = useEditorStore((s) => s.currentProjectId);
  const createProject = useEditorStore((s) => s.createProject);
  const switchProject = useEditorStore((s) => s.switchProject);
  const deleteProject = useEditorStore((s) => s.deleteProject);
  const renameProject = useEditorStore((s) => s.renameProject);
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  const current = projects.find((p) => p.id === currentProjectId);

  useEffect(() => {
    if (!open) return;
    const onDocClick = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDocClick);
    return () => document.removeEventListener('mousedown', onDocClick);
  }, [open]);

  return (
    <div className="project-switcher" ref={rootRef}>
      <button className="toolbar-btn project-switcher-trigger" onClick={() => setOpen((o) => !o)} title="Проекты">
        <span className="project-switcher-name">{current?.name || 'Проект'}</span>
        <ChevronDown size={12} />
      </button>
      {open && (
        <div className="project-switcher-dropdown">
          {projects.map((p) => (
            <div key={p.id} className={`project-switcher-item ${p.id === currentProjectId ? 'active' : ''}`}>
              <button
                className="project-switcher-select"
                onClick={() => { void switchProject(p.id); setOpen(false); }}
                title={new Date(p.updatedAt).toLocaleString()}
              >
                {p.name}
              </button>
              <button
                className="project-switcher-action"
                onClick={() => {
                  const name = prompt('Название проекта:', p.name);
                  if (name && name.trim()) renameProject(p.id, name.trim());
                }}
                title="Переименовать"
              >
                <Pencil size={11} />
              </button>
              <button
                className="project-switcher-action danger"
                onClick={() => {
                  if (confirm(`Удалить проект «${p.name}»? Это действие необратимо (включая ассеты).`)) {
                    void deleteProject(p.id);
                    setOpen(false);
                  }
                }}
                title="Удалить"
              >
                <Trash2 size={11} />
              </button>
            </div>
          ))}
          <button
            className="project-switcher-create"
            onClick={() => {
              const name = prompt('Название нового проекта:', `Проект ${projects.length + 1}`);
              if (name !== null) {
                void createProject(name.trim() || undefined);
                setOpen(false);
              }
            }}
          >
            <Plus size={12} /> Новый проект
          </button>
        </div>
      )}
    </div>
  );
}
