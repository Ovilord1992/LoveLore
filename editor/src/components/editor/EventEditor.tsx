import { useEditorStore } from '../../store/editorStore';
import type { Scene, SceneEvent as SceneEventType, Choice } from '../../types/novel';
import { Plus, Trash2, GripVertical, MessageSquare, BookOpen, GitBranch, ArrowDown, ArrowUp } from 'lucide-react';
import './EventEditor.css';

export function EventEditor() {
  const { project, selectedChapterIndex, selectedSceneId, addEvent, updateEvent, removeEvent, moveEvent, selectedEventIndex, selectEvent } = useEditorStore();

  const chapter = project.chapters[selectedChapterIndex];
  const scene = chapter?.scenes.find((s) => s.id === selectedSceneId);

  if (!scene) {
    return <div className="event-editor empty">Выберите сцену для редактирования</div>;
  }

  const handleAddEvent = (type: SceneEventType['type']) => {
    const event: SceneEventType = { type };
    if (type === 'dialogue') { event.speaker = ''; event.text = ''; }
    if (type === 'narration') { event.text = ''; }
    if (type === 'choice') { event.choices = [{ text: '', nextSceneId: '', effects: {} }]; }
    addEvent(scene.id, event);
  };

  return (
    <div className="event-editor">
      <div className="event-editor-header">
        <h3>Сцена: {scene.id}</h3>
        <SceneSettings scene={scene} />
      </div>

      <div className="events-list">
        {scene.events.map((event, index) => (
          <EventCard
            key={index}
            event={event}
            index={index}
            isSelected={selectedEventIndex === index}
            totalEvents={scene.events.length}
            onSelect={() => selectEvent(index)}
            onUpdate={(e) => updateEvent(scene.id, index, e)}
            onRemove={() => removeEvent(scene.id, index)}
            onMoveUp={() => index > 0 && moveEvent(scene.id, index, index - 1)}
            onMoveDown={() => index < scene.events.length - 1 && moveEvent(scene.id, index, index + 1)}
          />
        ))}
      </div>

      <div className="add-event-bar">
        <button onClick={() => handleAddEvent('dialogue')} title="Диалог">
          <MessageSquare size={16} /> Диалог
        </button>
        <button onClick={() => handleAddEvent('narration')} title="Нарратив">
          <BookOpen size={16} /> Нарратив
        </button>
        <button onClick={() => handleAddEvent('choice')} title="Выбор">
          <GitBranch size={16} /> Выбор
        </button>
      </div>
    </div>
  );
}

function SceneSettings({ scene }: { scene: Scene }) {
  const { updateScene } = useEditorStore();
  return (
    <div className="scene-settings">
      <input
        placeholder="Фон (background.png)"
        value={scene.background || ''}
        onChange={(e) => updateScene(scene.id, { background: e.target.value || undefined })}
      />
      <input
        placeholder="Музыка (track.mp3)"
        value={scene.music || ''}
        onChange={(e) => updateScene(scene.id, { music: e.target.value || undefined })}
      />
      <input
        placeholder="Следующая сцена (ID)"
        value={scene.nextSceneId || ''}
        onChange={(e) => updateScene(scene.id, { nextSceneId: e.target.value || undefined })}
      />
    </div>
  );
}

interface EventCardProps {
  event: SceneEventType;
  index: number;
  isSelected: boolean;
  totalEvents: number;
  onSelect: () => void;
  onUpdate: (event: SceneEventType) => void;
  onRemove: () => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
}

function EventCard({ event, index, isSelected, totalEvents, onSelect, onUpdate, onRemove, onMoveUp, onMoveDown }: EventCardProps) {
  const { project } = useEditorStore();
  const typeLabels: Record<string, string> = {
    dialogue: '💬 Диалог',
    narration: '📖 Нарратив',
    choice: '🔀 Выбор',
    set_variable: '⚙️ Переменная',
    play_sound: '🔊 Звук',
  };

  return (
    <div className={`event-card ${event.type} ${isSelected ? 'selected' : ''}`} onClick={onSelect}>
      <div className="event-card-header">
        <GripVertical size={14} className="drag-handle" />
        <span className="event-type">{typeLabels[event.type] || event.type}</span>
        <span className="event-index">#{index + 1}</span>
        <div className="event-actions">
          {index > 0 && <button onClick={(e) => { e.stopPropagation(); onMoveUp(); }} title="Вверх"><ArrowUp size={14} /></button>}
          {index < totalEvents - 1 && <button onClick={(e) => { e.stopPropagation(); onMoveDown(); }} title="Вниз"><ArrowDown size={14} /></button>}
          <button onClick={(e) => { e.stopPropagation(); onRemove(); }} className="delete" title="Удалить"><Trash2 size={14} /></button>
        </div>
      </div>

      {(event.type === 'dialogue') && (
        <div className="event-body">
          <select
            value={event.speaker || ''}
            onChange={(e) => onUpdate({ ...event, speaker: e.target.value || undefined })}
          >
            <option value="">— Говорящий —</option>
            {project.characters.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          <textarea
            placeholder="Текст диалога..."
            value={event.text || ''}
            onChange={(e) => onUpdate({ ...event, text: e.target.value })}
            rows={2}
          />
        </div>
      )}

      {event.type === 'narration' && (
        <div className="event-body">
          <textarea
            placeholder="Текст нарратива..."
            value={event.text || ''}
            onChange={(e) => onUpdate({ ...event, text: e.target.value })}
            rows={2}
          />
        </div>
      )}

      {event.type === 'choice' && (
        <ChoiceEditor event={event} onUpdate={onUpdate} />
      )}
    </div>
  );
}

function ChoiceEditor({ event, onUpdate }: { event: SceneEventType; onUpdate: (e: SceneEventType) => void }) {
  const choices = event.choices || [];

  const updateChoice = (index: number, updates: Partial<Choice>) => {
    const newChoices = choices.map((c, i) => i === index ? { ...c, ...updates } : c);
    onUpdate({ ...event, choices: newChoices });
  };

  const addChoice = () => {
    onUpdate({ ...event, choices: [...choices, { text: '', nextSceneId: '', effects: {} }] });
  };

  const removeChoice = (index: number) => {
    onUpdate({ ...event, choices: choices.filter((_, i) => i !== index) });
  };

  return (
    <div className="event-body choices">
      {choices.map((choice, i) => (
        <div key={i} className={`choice-item ${choice.premium ? 'premium' : ''}`}>
          <input
            placeholder="Текст варианта..."
            value={choice.text}
            onChange={(e) => updateChoice(i, { text: e.target.value })}
          />
          <input
            placeholder="→ ID сцены"
            value={choice.nextSceneId}
            onChange={(e) => updateChoice(i, { nextSceneId: e.target.value })}
            className="scene-ref"
          />
          <label className="premium-toggle">
            <input
              type="checkbox"
              checked={choice.premium || false}
              onChange={(e) => updateChoice(i, { premium: e.target.checked, cost: e.target.checked ? 10 : undefined })}
            />
            💎
          </label>
          {choice.premium && (
            <input
              type="number"
              className="cost-input"
              value={choice.cost || 10}
              onChange={(e) => updateChoice(i, { cost: parseInt(e.target.value) || 0 })}
              min={0}
            />
          )}
          <button onClick={() => removeChoice(i)} className="delete" title="Удалить вариант">
            <Trash2 size={12} />
          </button>
        </div>
      ))}
      <button className="add-choice" onClick={addChoice}>
        <Plus size={14} /> Вариант
      </button>
    </div>
  );
}
