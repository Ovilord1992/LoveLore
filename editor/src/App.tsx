import { useEditorStore } from './store/editorStore';
import { Sidebar } from './components/sidebar/Sidebar';
import { SceneGraph } from './components/editor/SceneGraph';
import { EventEditor } from './components/editor/EventEditor';
import { ScenePreview } from './components/preview/ScenePreview';
import './App.css';

export default function App() {
  const { project, isDirty, selectedSceneId, selectedChapterIndex } = useEditorStore();
  const chapter = project.chapters[selectedChapterIndex];
  const scene = chapter?.scenes.find((s) => s.id === selectedSceneId);

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
          <ScenePreview />
        </div>
      </div>
    </div>
  );
}
