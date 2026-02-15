import { useEditorStore } from '../../store/editorStore';
import type { Scene, SceneEvent as SceneEventType, Choice } from '../../types/novel';
import { Plus, Trash2, GripVertical, MessageSquare, BookOpen, GitBranch, ArrowDown, ArrowUp, Image, Users, Palette } from 'lucide-react';
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
    if (type === 'changeBackground') { event.background = ''; }
    if (type === 'changeSprite') { event.characterId = ''; event.spriteId = ''; }
    addEvent(scene.id, event);
  };

  return (
    <div className="event-editor">
      <div className="event-editor-header">
        <h3>Сцена: {scene.id}</h3>
        <SceneSettings scene={scene} />
        <CharactersOnScene scene={scene} />
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
        <button onClick={() => handleAddEvent('changeBackground')} title="Сменить фон">
          <Image size={16} /> Фон
        </button>
        <button onClick={() => handleAddEvent('changeSprite')} title="Сменить спрайт">
          <Palette size={16} /> Спрайт
        </button>
      </div>
    </div>
  );
}

function SceneSettings({ scene }: { scene: Scene }) {
  const { updateScene, addImage } = useEditorStore();
  const bgUrl = useEditorStore((s) => scene.background ? s.imageUrls.get(`backgrounds/${scene.background}`) : undefined);

  const handleBgUpload = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const name = file.name.replace(/\s+/g, '_').toLowerCase();
      addImage(`backgrounds/${name}`, file);
      updateScene(scene.id, { background: name });
    };
    input.click();
  };

  return (
    <div className="scene-settings">
      <div className="scene-settings-row">
        <input
          placeholder="Фон (background.png)"
          value={scene.background || ''}
          onChange={(e) => updateScene(scene.id, { background: e.target.value || undefined })}
        />
        <button className="upload-btn" onClick={handleBgUpload} title="Загрузить фон"><Image size={14} /></button>
      </div>
      {bgUrl && <img src={bgUrl} alt="bg" className="scene-bg-preview" />}
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

function CharactersOnScene({ scene }: { scene: Scene }) {
  const { project, addCharacterToScene, updateCharacterOnScene, removeCharacterFromScene } = useEditorStore();

  const availableChars = project.characters.filter(
    (c) => !scene.charactersOnScreen.some((sc) => sc.characterId === c.id)
  );

  return (
    <div className="chars-on-scene">
      <div className="chars-on-scene-header">
        <span className="chars-label"><Users size={12} /> Персонажи на сцене ({scene.charactersOnScreen.length})</span>
      </div>
      {scene.charactersOnScreen.map((sc) => {
        const char = project.characters.find((c) => c.id === sc.characterId);
        return (
          <div key={sc.characterId} className="char-on-scene-item">
            <span className="char-on-scene-name" style={{ color: char?.color }}>{char?.name || sc.characterId}</span>
            <select value={sc.spriteId} onChange={(e) => updateCharacterOnScene(scene.id, sc.characterId, { spriteId: e.target.value })}>
              {char?.sprites.map((sp) => <option key={sp.id} value={sp.id}>{sp.label}</option>)}
            </select>
            <select value={sc.position} onChange={(e) => updateCharacterOnScene(scene.id, sc.characterId, { position: e.target.value as 'left' | 'center' | 'right' })}>
              <option value="left">Лево</option>
              <option value="center">Центр</option>
              <option value="right">Право</option>
            </select>
            <button onClick={() => removeCharacterFromScene(scene.id, sc.characterId)} className="delete"><Trash2 size={12} /></button>
          </div>
        );
      })}
      {availableChars.length > 0 && (
        <select
          className="add-char-select"
          value=""
          onChange={(e) => {
            if (!e.target.value) return;
            const char = project.characters.find((c) => c.id === e.target.value);
            addCharacterToScene(scene.id, {
              characterId: e.target.value,
              spriteId: char?.sprites[0]?.id || 'neutral',
              position: 'center',
            });
            e.target.value = '';
          }}
        >
          <option value="">+ Добавить персонажа...</option>
          {availableChars.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      )}
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
  const { project, addImage } = useEditorStore();
  const typeLabels: Record<string, string> = {
    dialogue: '💬 Диалог',
    narration: '📖 Нарратив',
    choice: '🔀 Выбор',
    set_variable: '⚙️ Переменная',
    play_sound: '🔊 Звук',
    changeBackground: '🖼 Смена фона',
    changeSprite: '🎭 Смена спрайта',
  };

  const handleBgEventUpload = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const name = file.name.replace(/\s+/g, '_').toLowerCase();
      addImage(`backgrounds/${name}`, file);
      onUpdate({ ...event, background: name });
    };
    input.click();
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

      {event.type === 'changeBackground' && (
        <div className="event-body">
          <div className="scene-settings-row">
            <input
              placeholder="Имя фона (city_night.png)"
              value={event.background || ''}
              onChange={(e) => onUpdate({ ...event, background: e.target.value })}
            />
            <button className="upload-btn" onClick={handleBgEventUpload} title="Загрузить"><Image size={14} /></button>
          </div>
        </div>
      )}

      {event.type === 'changeSprite' && (
        <div className="event-body">
          <select
            value={event.characterId || ''}
            onChange={(e) => onUpdate({ ...event, characterId: e.target.value || undefined })}
          >
            <option value="">— Персонаж —</option>
            {project.characters.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          {event.characterId && (
            <select
              value={event.spriteId || ''}
              onChange={(e) => onUpdate({ ...event, spriteId: e.target.value || undefined })}
            >
              <option value="">— Спрайт —</option>
              {project.characters.find((c) => c.id === event.characterId)?.sprites.map((sp) => (
                <option key={sp.id} value={sp.id}>{sp.label}</option>
              ))}
            </select>
          )}
        </div>
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
