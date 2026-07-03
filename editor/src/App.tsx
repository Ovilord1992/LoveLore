import { useState, useEffect } from 'react';
import { useEditorStore } from './store/editorStore';
import { Sidebar } from './components/sidebar/Sidebar';
import { SceneGraph } from './components/editor/SceneGraph';
import { EventEditor } from './components/editor/EventEditor';
import { ScenePreview } from './components/preview/ScenePreview';
import { GamePreview } from './components/preview/GamePreview';
import './App.css';

export default function App() {
  const [previewMode, setPreviewMode] = useState<'static' | 'play'>('static');
  const { project, isDirty, selectedSceneId, selectedChapterIndex } = useEditorStore();
  const chapter = project.chapters[selectedChapterIndex];
  const scene = chapter?.scenes.find((s) => s.id === selectedSceneId);

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

  return (
    <div className="app">
      {/* Header */}
      <header className="app-header">
        <div className="header-logo">
          <span className="logo-icon">✦</span>
          <span className="logo-text">Amoria Editor</span>
        </div>
        <div className="header-info">
          <span className="project-name">{project.meta.title || 'Без названия'}</span>
          {isDirty && <span className="unsaved-badge">●</span>}
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
