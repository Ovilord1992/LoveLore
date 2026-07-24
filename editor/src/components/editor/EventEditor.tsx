import { useState } from 'react';
import { useEditorStore } from '../../store/editorStore';
import type { Scene, SceneEvent as SceneEventType, SceneCharacter, Choice, Condition, ConditionsLogic, SceneBranch, EffectType, CgTransition, EmotionType, BackgroundLayer } from '../../types/novel';
import { SceneSelect } from '../common/SceneSelect';
import { AssetPicker } from '../common/AssetPicker';
import { conditionSummary } from '../../utils/conditions';
import { Plus, Trash2, GripVertical, MessageSquare, BookOpen, GitBranch, ArrowDown, ArrowUp, Image, Users, Palette, Sparkles, Camera, Heart, Layers, ImagePlus, Settings, Volume2, X, Copy, ClipboardPaste, CopyPlus, Flag, Split } from 'lucide-react';
import './EventEditor.css';

export function EventEditor() {
  const { project, selectedChapterIndex, selectedSceneId, addEvent, updateEvent, removeEvent, moveEvent, selectedEventIndex, selectEvent, eventClipboard, pasteEvent, duplicateScene } = useEditorStore();
  const copySelectedEvent = useEditorStore((s) => s.copySelectedEvent);
  // Индекс карточки, которой разрешён drag (зажат grip-handle) + подсветка цели
  const [draggableIndex, setDraggableIndex] = useState<number | null>(null);
  const [dropTarget, setDropTarget] = useState<number | null>(null);

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
    if (type === 'changeBackground') { event.asset = ''; }
    if (type === 'changeSprite') { event.characterId = ''; event.spriteId = ''; }
    if (type === 'effect') { event.effectType = 'shake'; event.effectDuration = 500; event.effectIntensity = 0.7; }
    if (type === 'showCg') { event.cgImage = ''; event.cgTransition = 'fade'; event.cgDuration = 800; }
    if (type === 'cameraMove') { event.zoom = 1.0; event.panX = 0; event.panY = 0; event.cameraDuration = 1000; }
    if (type === 'showEmotion') { event.characterId = ''; event.emotionType = 'heart'; }
    if (type === 'setVariable') { event.variable = ''; event.value = ''; }
    if (type === 'playSound') { event.asset = ''; }
    addEvent(scene.id, event);
  };

  const handleCopy = (index: number) => {
    selectEvent(index);
    copySelectedEvent();
  };

  const handleDrop = (from: number, to: number) => {
    if (from !== to) moveEvent(scene.id, from, to);
    setDraggableIndex(null);
    setDropTarget(null);
  };

  return (
    <div className="event-editor">
      <div className="event-editor-header">
        <div className="scene-title-row">
          <h3>Сцена: {scene.id}</h3>
          <button
            className="scene-duplicate-btn"
            onClick={() => duplicateScene(scene.id)}
            title="Дублировать сцену (копия событий с новым id)"
          >
            <CopyPlus size={13} /> Дублировать
          </button>
        </div>
        <SceneSettings scene={scene} />
        <CharactersOnScene scene={scene} />
        <BranchesEditor scene={scene} />
        <EndingEditor scene={scene} />
      </div>

      <div className="events-list">
        {scene.events.map((event, index) => (
          <div
            key={index}
            draggable={draggableIndex === index}
            onDragStart={(e) => {
              e.dataTransfer.setData('text/plain', String(index));
              e.dataTransfer.effectAllowed = 'move';
            }}
            onDragEnd={() => { setDraggableIndex(null); setDropTarget(null); }}
            onDragOver={(e) => {
              e.preventDefault();
              e.dataTransfer.dropEffect = 'move';
              if (dropTarget !== index) setDropTarget(index);
            }}
            onDragLeave={() => { if (dropTarget === index) setDropTarget(null); }}
            onDrop={(e) => {
              e.preventDefault();
              const from = parseInt(e.dataTransfer.getData('text/plain'), 10);
              if (!isNaN(from)) handleDrop(from, index);
            }}
            className={`event-drag-wrap ${dropTarget === index ? 'drop-target' : ''}`}
          >
            <EventCard
              event={event}
              index={index}
              isSelected={selectedEventIndex === index}
              totalEvents={scene.events.length}
              onSelect={() => selectEvent(index)}
              onUpdate={(e) => updateEvent(scene.id, index, e)}
              onRemove={() => removeEvent(scene.id, index)}
              onMoveUp={() => index > 0 && moveEvent(scene.id, index, index - 1)}
              onMoveDown={() => index < scene.events.length - 1 && moveEvent(scene.id, index, index + 1)}
              onCopy={() => handleCopy(index)}
              onGripDown={() => setDraggableIndex(index)}
            />
          </div>
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
        <button onClick={() => handleAddEvent('effect')} title="Эффект">
          <Sparkles size={16} /> Эффект
        </button>
        <button onClick={() => handleAddEvent('showCg')} title="CG-арт">
          <ImagePlus size={16} /> CG
        </button>
        <button onClick={() => handleAddEvent('cameraMove')} title="Камера">
          <Camera size={16} /> Камера
        </button>
        <button onClick={() => handleAddEvent('showEmotion')} title="Эмоция">
          <Heart size={16} /> Эмоция
        </button>
        <button onClick={() => handleAddEvent('setVariable')} title="Установить переменную">
          <Settings size={16} /> Переменная
        </button>
        <button onClick={() => handleAddEvent('playSound')} title="Проиграть звук">
          <Volume2 size={16} /> Звук
        </button>
        {eventClipboard && (
          <button onClick={() => pasteEvent()} className="paste-btn" title="Вставить скопированное событие (Ctrl/Cmd+V)">
            <ClipboardPaste size={16} /> Вставить
          </button>
        )}
      </div>
    </div>
  );
}

function SceneSettings({ scene }: { scene: Scene }) {
  const { project, updateScene, addAsset } = useEditorStore();
  const bgUrl = useEditorStore((s) => scene.background ? s.assetUrls.get(`backgrounds/${scene.background}`) : undefined);
  const assets = useEditorStore((s) => s.assets);

  // Собираем список доступных фонов: из загруженных файлов (Map) + уже использованные в сценах
  const availableBackgrounds = (() => {
    const set = new Set<string>();
    assets.forEach((_, path) => {
      if (path.startsWith('backgrounds/')) set.add(path.replace(/^backgrounds\//, ''));
    });
    for (const ch of project.chapters) {
      for (const sc of ch.scenes) {
        if (sc.background) set.add(sc.background);
        sc.backgroundLayers?.forEach((l) => { if (l.image) set.add(l.image); });
        for (const ev of sc.events) {
          if (ev.type === 'changeBackground' && ev.asset) set.add(ev.asset);
        }
      }
    }
    return Array.from(set).sort();
  })();

  const layers = scene.backgroundLayers || [];
  const hasLayers = layers.length > 0;

  const handleBgUpload = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const name = file.name.replace(/\s+/g, '_').toLowerCase();
      addAsset(`backgrounds/${name}`, file);
      updateScene(scene.id, { background: name });
    };
    input.click();
  };

  const addLayer = () => {
    const newLayer: BackgroundLayer = {
      image: availableBackgrounds[0] || '',
      depth: layers.length === 0 ? 0 : Math.min(1, layers.length / 3),
      offsetX: 0,
      offsetY: 0,
    };
    updateScene(scene.id, { backgroundLayers: [...layers, newLayer] });
  };

  const updateLayer = (index: number, patch: Partial<BackgroundLayer>) => {
    const next = layers.map((l, i) => i === index ? { ...l, ...patch } : l);
    updateScene(scene.id, { backgroundLayers: next });
  };

  const removeLayer = (index: number) => {
    const next = layers.filter((_, i) => i !== index);
    updateScene(scene.id, { backgroundLayers: next.length ? next : undefined });
  };

  const uploadLayerImage = (index: number) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const name = file.name.replace(/\s+/g, '_').toLowerCase();
      addAsset(`backgrounds/${name}`, file);
      updateLayer(index, { image: name });
    };
    input.click();
  };

  return (
    <div className="scene-settings">
      <div className="scene-settings-row">
        <input
          placeholder={hasLayers ? 'Фон (опционально, fallback к слоям)' : 'Фон (background.png)'}
          value={scene.background || ''}
          onChange={(e) => updateScene(scene.id, { background: e.target.value || undefined })}
          disabled={hasLayers && !scene.background}
          title={hasLayers ? 'Используются слои параллакса. Это поле — необязательный fallback.' : undefined}
        />
        <button className="upload-btn" onClick={handleBgUpload} title="Загрузить фон"><Image size={14} /></button>
      </div>
      {bgUrl && !hasLayers && <img src={bgUrl} alt="bg" className="scene-bg-preview" />}
      <label className="field-label"><Volume2 size={11} /> Музыка сцены</label>
      <AssetPicker
        value={scene.music || ''}
        onChange={(v) => updateScene(scene.id, { music: v || undefined })}
        dirs={['music/']}
        kind="audio"
        placeholder="Музыка (music/track.mp3)"
      />
      <label className="field-label">Следующая сцена (после последнего события)</label>
      <SceneSelect
        value={scene.nextSceneId || ''}
        onChange={(v) => updateScene(scene.id, { nextSceneId: v || undefined })}
        allowEmpty
        emptyLabel="— конец главы —"
        placeholder="— конец главы —"
      />
      <div className="scene-transition-settings">
        <label>Переход</label>
        <div className="scene-settings-row">
          <select
            value={scene.transition?.type || 'fade'}
            onChange={(e) => updateScene(scene.id, { transition: { type: e.target.value as 'fade', duration: scene.transition?.duration || 800 } })}
          >
            <option value="fade">Fade (плавное)</option>
            <option value="slideLeft">Slide Left</option>
            <option value="slideRight">Slide Right</option>
            <option value="dissolve">Dissolve</option>
            <option value="none">Без перехода</option>
          </select>
          <input
            type="number"
            className="transition-duration"
            placeholder="мс"
            value={scene.transition?.duration || 800}
            onChange={(e) => updateScene(scene.id, { transition: { type: scene.transition?.type || 'fade', duration: parseInt(e.target.value) || 800 } })}
            min={0}
            max={3000}
            step={100}
          />
        </div>
      </div>

      <div className="bg-layers-settings">
        <div className="bg-layers-header">
          <label
            className="bg-layers-label"
            title="depth: 0 = неподвижный задний план, 1 = ближний быстрый план"
          >
            <Layers size={12} /> Многослойные фоны (параллакс) ({layers.length})
          </label>
          <button
            type="button"
            className="add-layer-btn"
            onClick={addLayer}
            title="Добавить слой"
          >
            <Plus size={12} /> слой
          </button>
        </div>
        {hasLayers && (
          <div className="bg-layers-hint" title="depth: 0 = неподвижный задний план, 1 = ближний быстрый план">
            depth: 0 — задний план (неподвижный), 1 — передний (быстрый)
          </div>
        )}
        {layers.map((layer, i) => (
          <div key={i} className="bg-layer-row">
            <select
              className="bg-layer-image"
              value={layer.image}
              onChange={(e) => updateLayer(i, { image: e.target.value })}
              title="Изображение слоя"
            >
              <option value="">— фон —</option>
              {availableBackgrounds.map((b) => (
                <option key={b} value={b}>{b}</option>
              ))}
              {layer.image && !availableBackgrounds.includes(layer.image) && (
                <option value={layer.image}>{layer.image}</option>
              )}
            </select>
            <button
              type="button"
              className="upload-btn"
              onClick={() => uploadLayerImage(i)}
              title="Загрузить изображение слоя"
            >
              <Image size={12} />
            </button>
            <input
              type="number"
              className="bg-layer-depth"
              value={layer.depth}
              onChange={(e) => updateLayer(i, { depth: Math.max(0, Math.min(1, parseFloat(e.target.value) || 0)) })}
              min={0}
              max={1}
              step={0.1}
              title="depth: 0 = неподвижный задний план, 1 = ближний быстрый план"
              placeholder="depth"
            />
            <input
              type="number"
              className="bg-layer-offset"
              value={layer.offsetX ?? 0}
              onChange={(e) => updateLayer(i, { offsetX: parseFloat(e.target.value) || 0 })}
              step={1}
              title="Смещение по X (px)"
              placeholder="X"
            />
            <input
              type="number"
              className="bg-layer-offset"
              value={layer.offsetY ?? 0}
              onChange={(e) => updateLayer(i, { offsetY: parseFloat(e.target.value) || 0 })}
              step={1}
              title="Смещение по Y (px)"
              placeholder="Y"
            />
            <button
              type="button"
              className="delete bg-layer-remove"
              onClick={() => removeLayer(i)}
              title="Удалить слой"
            >
              <X size={12} />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

/** Билдер списка условий с логикой and/or (формат v2 1.1) —
 *  общий для вариантов выбора и веток сцены. */
function ConditionsBuilder({ conditions, logic, onChange, compact }: {
  conditions: Condition[];
  logic: ConditionsLogic;
  onChange: (conditions: Condition[], logic: ConditionsLogic) => void;
  compact?: boolean;
}) {
  const variables = useEditorStore((s) => s.project.variables);
  const varNames = Object.keys(variables);

  const updateCondition = (i: number, patch: Partial<Condition>) => {
    onChange(conditions.map((c, ci) => ci === i ? { ...c, ...patch } : c), logic);
  };

  const parseValue = (raw: string): number | boolean => {
    if (raw === 'true') return true;
    if (raw === 'false') return false;
    const n = parseFloat(raw);
    return isNaN(n) ? 0 : n;
  };

  return (
    <div className={`conditions-builder ${compact ? 'compact' : ''}`}>
      {conditions.length > 1 && (
        <div className="conditions-logic-row">
          <span className="conditions-logic-label">Логика:</span>
          <button
            type="button"
            className={`logic-btn ${logic === 'and' ? 'active' : ''}`}
            onClick={() => onChange(conditions, 'and')}
            title="Все условия должны выполниться"
          >И (and)</button>
          <button
            type="button"
            className={`logic-btn ${logic === 'or' ? 'active' : ''}`}
            onClick={() => onChange(conditions, 'or')}
            title="Достаточно одного условия"
          >ИЛИ (or)</button>
        </div>
      )}
      {conditions.map((cond, i) => (
        <div key={i} className="condition-row">
          <input
            placeholder="переменная"
            value={cond.variable}
            onChange={(e) => updateCondition(i, { variable: e.target.value })}
            className="cond-var"
            list="editor-variable-names"
          />
          <select
            value={cond.operator}
            onChange={(e) => updateCondition(i, { operator: e.target.value as Condition['operator'] })}
            className="cond-op"
          >
            <option value=">=">{'>='}</option>
            <option value="<=">{'<='}</option>
            <option value="==">{'=='}</option>
            <option value="!=">{'!='}</option>
            <option value=">">{'>'}</option>
            <option value="<">{'<'}</option>
          </select>
          <input
            placeholder="значение"
            value={String(cond.value)}
            onChange={(e) => updateCondition(i, { value: parseValue(e.target.value) })}
            className="cond-val"
            title="Число или true/false"
          />
          <button
            type="button"
            className="delete"
            onClick={() => onChange(conditions.filter((_, ci) => ci !== i), logic)}
            title="Удалить условие"
          >
            <X size={12} />
          </button>
        </div>
      ))}
      <button
        type="button"
        className="add-condition-btn"
        onClick={() => onChange([...conditions, { variable: varNames[0] || '', operator: '>=', value: 0 }], logic)}
      >
        <Plus size={11} /> условие
      </button>
      <datalist id="editor-variable-names">
        {varNames.map((v) => <option key={v} value={v} />)}
      </datalist>
    </div>
  );
}

/** Панель веток сцены (формат v2 1.2): условия → целевая сцена,
 *  порядок важен — проверяются сверху вниз, первое совпадение побеждает. */
function BranchesEditor({ scene }: { scene: Scene }) {
  const updateScene = useEditorStore((s) => s.updateScene);
  const branches = scene.branches || [];

  const setBranches = (next: SceneBranch[]) => {
    updateScene(scene.id, { branches: next.length ? next : undefined });
  };

  const updateBranch = (i: number, patch: Partial<SceneBranch>) => {
    setBranches(branches.map((b, bi) => bi === i ? { ...b, ...patch } : b));
  };

  const moveBranch = (from: number, to: number) => {
    if (to < 0 || to >= branches.length) return;
    const next = [...branches];
    const [moved] = next.splice(from, 1);
    next.splice(to, 0, moved);
    setBranches(next);
  };

  return (
    <div className="branches-editor">
      <div className="subpanel-header">
        <span className="subpanel-label" title="Проверяются в конце сцены по порядку; первое сработавшее условие определяет переход. Если ни одно — используется «Следующая сцена».">
          <Split size={12} /> Ветвление по переменным ({branches.length})
        </span>
        <button
          type="button"
          className="add-btn small"
          onClick={() => setBranches([...branches, { conditions: [{ variable: '', operator: '>=', value: 0 }], nextSceneId: '' }])}
          title="Добавить ветку"
        >
          <Plus size={12} />
        </button>
      </div>
      {branches.length > 0 && (
        <div className="branches-hint">Порядок важен: первая сработавшая ветка побеждает</div>
      )}
      {branches.map((branch, i) => (
        <div key={i} className="branch-card">
          <div className="branch-card-header">
            <span className="branch-index">#{i + 1}</span>
            <span className="branch-summary">{conditionSummary(branch.conditions, branch.conditionsLogic)}</span>
            <div className="branch-actions">
              {i > 0 && <button type="button" onClick={() => moveBranch(i, i - 1)} title="Выше (проверяется раньше)"><ArrowUp size={12} /></button>}
              {i < branches.length - 1 && <button type="button" onClick={() => moveBranch(i, i + 1)} title="Ниже (проверяется позже)"><ArrowDown size={12} /></button>}
              <button type="button" className="delete" onClick={() => setBranches(branches.filter((_, bi) => bi !== i))} title="Удалить ветку"><Trash2 size={12} /></button>
            </div>
          </div>
          <ConditionsBuilder
            conditions={branch.conditions}
            logic={branch.conditionsLogic || 'and'}
            onChange={(conditions, logic) => updateBranch(i, {
              conditions,
              conditionsLogic: logic === 'and' ? undefined : logic,
            })}
            compact
          />
          <div className="branch-target-row">
            <span className="branch-target-label">→</span>
            <SceneSelect
              value={branch.nextSceneId}
              onChange={(v) => updateBranch(i, { nextSceneId: v })}
              placeholder="Целевая сцена…"
            />
          </div>
        </div>
      ))}
    </div>
  );
}

/** Панель концовки сцены (формат v2 1.3). */
function EndingEditor({ scene }: { scene: Scene }) {
  const updateScene = useEditorStore((s) => s.updateScene);
  const metaEndings = useEditorStore((s) => s.project.meta.endings);
  const ending = scene.ending;

  return (
    <div className="ending-editor">
      <label className="premium-toggle subpanel-header">
        <input
          type="checkbox"
          checked={!!ending}
          onChange={(e) => updateScene(scene.id, {
            ending: e.target.checked
              ? { id: metaEndings?.[0]?.id || 'ending_1', title: metaEndings?.[0]?.title || '' }
              : undefined,
          })}
        />
        <span className="subpanel-label"><Flag size={12} /> Концовка (конец сцены = финал истории)</span>
      </label>
      {ending && (
        <div className="ending-fields">
          <div className="ending-row">
            <input
              placeholder="id (good_end)"
              value={ending.id}
              onChange={(e) => updateScene(scene.id, { ending: { ...ending, id: e.target.value } })}
              className="ending-id"
              list="editor-meta-ending-ids"
            />
            <datalist id="editor-meta-ending-ids">
              {(metaEndings || []).map((e) => <option key={e.id} value={e.id}>{e.title}</option>)}
            </datalist>
            <input
              placeholder="Заголовок («Счастливый финал»)"
              value={ending.title}
              onChange={(e) => updateScene(scene.id, { ending: { ...ending, title: e.target.value } })}
            />
          </div>
          <textarea
            placeholder="Описание концовки…"
            value={ending.description || ''}
            onChange={(e) => updateScene(scene.id, { ending: { ...ending, description: e.target.value || undefined } })}
            rows={2}
          />
          <label className="field-label">Изображение (из CG)</label>
          <AssetPicker
            value={ending.image || ''}
            onChange={(v) => updateScene(scene.id, { ending: { ...ending, image: v || undefined } })}
            dirs={['cg/']}
            kind="image"
            placeholder="cg/ending.png"
          />
        </div>
      )}
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
            <select value={sc.animation || ''} onChange={(e) => updateCharacterOnScene(scene.id, sc.characterId, { animation: (e.target.value || undefined) as SceneCharacter['animation'] })}>
              <option value="">Без анимации</option>
              <option value="fade_in">Fade In</option>
              <option value="fade_out">Fade Out</option>
              <option value="slide_in_left">Slide Left</option>
              <option value="slide_in_right">Slide Right</option>
              <option value="bounce">Bounce</option>
              <option value="shake">Shake</option>
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
  onCopy: () => void;
  onGripDown: () => void;
}

function EventCard({ event, index, isSelected, totalEvents, onSelect, onUpdate, onRemove, onMoveUp, onMoveDown, onCopy, onGripDown }: EventCardProps) {
  const { project, addAsset } = useEditorStore();
  const typeLabels: Record<string, string> = {
    dialogue: '💬 Диалог',
    narration: '📖 Нарратив',
    choice: '🔀 Выбор',
    setVariable: '⚙️ Переменная',
    playSound: '🔊 Звук',
    changeBackground: '🖼 Смена фона',
    changeSprite: '🎭 Смена спрайта',
    effect: '✨ Эффект',
    showCg: '🖼️ CG-арт',
    cameraMove: '📷 Камера',
    showEmotion: '💭 Эмоция',
  };

  const handleBgEventUpload = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const name = file.name.replace(/\s+/g, '_').toLowerCase();
      addAsset(`backgrounds/${name}`, file);
      onUpdate({ ...event, asset: name });
    };
    input.click();
  };

  return (
    <div className={`event-card ${event.type} ${isSelected ? 'selected' : ''}`} onClick={onSelect}>
      <div className="event-card-header">
        <span onMouseDown={onGripDown} className="drag-handle-wrap" title="Перетащить для изменения порядка">
          <GripVertical size={14} className="drag-handle" />
        </span>
        <span className="event-type">{typeLabels[event.type] || event.type}</span>
        <span className="event-index">#{index + 1}</span>
        <div className="event-actions">
          <button onClick={(e) => { e.stopPropagation(); onCopy(); }} title="Копировать событие (Ctrl/Cmd+C)"><Copy size={14} /></button>
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
            placeholder="Текст диалога... ({name}, {var:key} — интерполяция)"
            value={event.text || ''}
            onChange={(e) => onUpdate({ ...event, text: e.target.value })}
            rows={2}
          />
          <VoicePicker event={event} onUpdate={onUpdate} />
        </div>
      )}

      {event.type === 'narration' && (
        <div className="event-body">
          <textarea
            placeholder="Текст нарратива... ({name}, {var:key} — интерполяция)"
            value={event.text || ''}
            onChange={(e) => onUpdate({ ...event, text: e.target.value })}
            rows={2}
          />
          <VoicePicker event={event} onUpdate={onUpdate} />
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
              value={event.asset || ''}
              onChange={(e) => onUpdate({ ...event, asset: e.target.value })}
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
          <div className="effect-params">
            <label>Длительность cross-fade: {event.spriteDuration || 300} мс</label>
            <input
              type="range" min={0} max={1000} step={50}
              value={event.spriteDuration || 300}
              onChange={(e) => onUpdate({ ...event, spriteDuration: parseInt(e.target.value) })}
            />
          </div>
        </div>
      )}

      {event.type === 'effect' && (
        <div className="event-body">
          <select
            value={event.effectType || 'shake'}
            onChange={(e) => onUpdate({ ...event, effectType: e.target.value as EffectType })}
          >
            <option value="shake">🫨 Тряска</option>
            <option value="flash">⚡ Вспышка</option>
            <option value="fadeToBlack">🌑 Затемнение</option>
            <option value="rain">🌧 Дождь</option>
            <option value="snow">❄️ Снег</option>
            <option value="particles">✨ Частицы</option>
          </select>
          <div className="effect-params">
            <label>Длительность: {event.effectDuration || 500} мс</label>
            <input
              type="range"
              min={100}
              max={3000}
              step={100}
              value={event.effectDuration || 500}
              onChange={(e) => onUpdate({ ...event, effectDuration: parseInt(e.target.value) })}
            />
            <label>Интенсивность: {((event.effectIntensity ?? 0.7) * 100).toFixed(0)}%</label>
            <input
              type="range"
              min={0}
              max={100}
              step={5}
              value={(event.effectIntensity ?? 0.7) * 100}
              onChange={(e) => onUpdate({ ...event, effectIntensity: parseInt(e.target.value) / 100 })}
            />
          </div>
        </div>
      )}

      {event.type === 'showCg' && (
        <div className="event-body">
          <div className="scene-settings-row">
            <input
              placeholder="Путь к CG (cg/first_kiss.png)"
              value={event.cgImage || ''}
              onChange={(e) => onUpdate({ ...event, cgImage: e.target.value })}
            />
            <button className="upload-btn" onClick={() => {
              const input = document.createElement('input');
              input.type = 'file';
              input.accept = 'image/*';
              input.onchange = (ev) => {
                const file = (ev.target as HTMLInputElement).files?.[0];
                if (!file) return;
                const name = file.name.replace(/\s+/g, '_').toLowerCase();
                addAsset(`cg/${name}`, file);
                onUpdate({ ...event, cgImage: `cg/${name}` });
              };
              input.click();
            }} title="Загрузить CG"><Image size={14} /></button>
          </div>
          <select
            value={event.cgTransition || 'fade'}
            onChange={(e) => onUpdate({ ...event, cgTransition: e.target.value as CgTransition })}
          >
            <option value="fade">Fade</option>
            <option value="zoomIn">Zoom In</option>
          </select>
          <div className="effect-params">
            <label>Длительность: {event.cgDuration || 800} мс</label>
            <input
              type="range" min={200} max={2000} step={100}
              value={event.cgDuration || 800}
              onChange={(e) => onUpdate({ ...event, cgDuration: parseInt(e.target.value) })}
            />
          </div>
        </div>
      )}

      {event.type === 'cameraMove' && (
        <div className="event-body">
          <div className="effect-params">
            <label>Zoom: {event.zoom?.toFixed(1) || '1.0'}x</label>
            <input
              type="range" min={50} max={200} step={10}
              value={(event.zoom ?? 1.0) * 100}
              onChange={(e) => onUpdate({ ...event, zoom: parseInt(e.target.value) / 100 })}
            />
            <label>Pan X: {event.panX || 0}</label>
            <input
              type="range" min={-200} max={200} step={10}
              value={event.panX || 0}
              onChange={(e) => onUpdate({ ...event, panX: parseInt(e.target.value) })}
            />
            <label>Pan Y: {event.panY || 0}</label>
            <input
              type="range" min={-200} max={200} step={10}
              value={event.panY || 0}
              onChange={(e) => onUpdate({ ...event, panY: parseInt(e.target.value) })}
            />
            <label>Длительность: {event.cameraDuration || 1000} мс</label>
            <input
              type="range" min={200} max={5000} step={100}
              value={event.cameraDuration || 1000}
              onChange={(e) => onUpdate({ ...event, cameraDuration: parseInt(e.target.value) })}
            />
          </div>
        </div>
      )}

      {event.type === 'showEmotion' && (
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
          <select
            value={event.emotionType || 'heart'}
            onChange={(e) => onUpdate({ ...event, emotionType: e.target.value as EmotionType })}
          >
            <option value="heart">❤️ Сердечко</option>
            <option value="sweatDrop">💧 Капля пота</option>
            <option value="question">❓ Вопрос</option>
            <option value="exclamation">❗ Восклицание</option>
            <option value="anger">💢 Злость</option>
            <option value="sparkle">✨ Блеск</option>
            <option value="musicNote">🎵 Нота</option>
            <option value="zzz">💤 Сон</option>
          </select>
          <label className="field-label">Картинка вместо emoji (опционально)</label>
          <AssetPicker
            value={event.image || ''}
            onChange={(v) => onUpdate({ ...event, image: v || undefined })}
            dirs={['emotions/']}
            kind="image"
            placeholder="emotions/love.png"
          />
        </div>
      )}

      {event.type === 'setVariable' && (
        <div className="event-body">
          <div className="scene-settings-row">
            <input
              placeholder="Имя переменной (напр. romance_anna)"
              value={event.variable || ''}
              onChange={(e) => onUpdate({ ...event, variable: e.target.value })}
              list="editor-variable-names"
            />
            <input
              placeholder="Значение (число / строка / +1 / -2 / toggle)"
              value={event.value === undefined ? '' : String(event.value)}
              onChange={(e) => {
                const raw = e.target.value;
                // Сохраняем как число, если это просто число (без +/-/=)
                const asNum = Number(raw);
                if (raw !== '' && !isNaN(asNum) && !/^[+-]/.test(raw)) {
                  onUpdate({ ...event, value: asNum });
                } else if (raw === 'true' || raw === 'false') {
                  onUpdate({ ...event, value: raw === 'true' });
                } else {
                  onUpdate({ ...event, value: raw });
                }
              }}
            />
          </div>
        </div>
      )}

      {event.type === 'playSound' && (
        <div className="event-body">
          <AssetPicker
            value={event.asset || ''}
            onChange={(v) => onUpdate({ ...event, asset: v })}
            dirs={['sounds/']}
            kind="audio"
            placeholder="Файл звука (sounds/door_open.mp3)"
          />
        </div>
      )}
    </div>
  );
}

/** Пикер озвучки (формат v2 1.6) для dialogue/narration. */
function VoicePicker({ event, onUpdate }: { event: SceneEventType; onUpdate: (e: SceneEventType) => void }) {
  return (
    <div className="voice-picker-row">
      <span className="field-label" title="Озвучка реплики — файл из voice/ (обрывается при переходе к следующему событию)">🎙 Озвучка</span>
      <AssetPicker
        value={event.voice || ''}
        onChange={(v) => onUpdate({ ...event, voice: v || undefined })}
        dirs={['voice/']}
        kind="audio"
        placeholder="voice/reply.mp3"
      />
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
      {/* Таймер на выбор */}
      <div className="timer-settings">
        <label className="premium-toggle">
          <input
            type="checkbox"
            checked={!!event.timeLimit}
            onChange={(e) => onUpdate({ ...event, timeLimit: e.target.checked ? 10 : undefined, defaultChoiceIndex: e.target.checked ? 0 : undefined })}
          />
          ⏱ Таймер
        </label>
        {event.timeLimit && (
          <>
            <input
              type="number"
              className="cost-input"
              value={event.timeLimit}
              onChange={(e) => onUpdate({ ...event, timeLimit: parseInt(e.target.value) || 10 })}
              min={3}
              max={60}
            />
            <span className="timer-label">сек</span>
            <select
              value={event.defaultChoiceIndex ?? 0}
              onChange={(e) => onUpdate({ ...event, defaultChoiceIndex: parseInt(e.target.value) })}
              className="default-choice-select"
            >
              {choices.map((c, i) => (
                <option key={i} value={i}>По умолч: {c.text.slice(0, 15) || `#${i + 1}`}</option>
              ))}
            </select>
          </>
        )}
      </div>
      {choices.map((choice, i) => (
        <div key={i} className={`choice-block ${choice.premium ? 'premium' : ''}`}>
          <div className="choice-item">
            <input
              placeholder="Текст варианта..."
              value={choice.text}
              onChange={(e) => updateChoice(i, { text: e.target.value })}
            />
            <SceneSelect
              value={choice.nextSceneId}
              onChange={(v) => updateChoice(i, { nextSceneId: v })}
              placeholder="→ Сцена…"
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

          <ChoiceConditionEditor
            choice={choice}
            onChange={(updates) => updateChoice(i, updates)}
          />

          <ChoiceEffectsEditor
            choice={choice}
            onChange={(updates) => updateChoice(i, updates)}
          />

          <ChoiceUnlockOutfitsEditor
            choice={choice}
            onChange={(updates) => updateChoice(i, updates)}
          />
        </div>
      ))}
      <button className="add-choice" onClick={addChoice}>
        <Plus size={14} /> Вариант
      </button>
    </div>
  );
}

/** Условия показа варианта: билдер множественных условий с and/or (v2 1.1).
 *  Легаси-`condition` конвертируется в массив при первом изменении. */
function ChoiceConditionEditor({ choice, onChange }: { choice: Choice; onChange: (updates: Partial<Choice>) => void }) {
  const conditions = choice.conditions ?? (choice.condition ? [choice.condition] : []);
  const enabled = conditions.length > 0;

  const write = (next: Condition[], logic: ConditionsLogic) => {
    // Записываем в новый формат `conditions`; легаси-поле убираем, чтобы не
    // было расхождения (клиент отдаёт приоритет `conditions`).
    onChange({
      conditions: next.length > 0 ? next : undefined,
      conditionsLogic: next.length > 1 && logic === 'or' ? 'or' : undefined,
      condition: undefined,
    });
  };

  return (
    <div className="choice-subblock">
      <label className="premium-toggle">
        <input
          type="checkbox"
          checked={enabled}
          onChange={(e) => {
            if (e.target.checked) {
              write([{ variable: '', operator: '>=', value: 0 }], 'and');
            } else {
              write([], 'and');
            }
          }}
        />
        <span className="subblock-label">Условия показа {conditions.length > 1 ? `(${conditions.length})` : ''}</span>
      </label>
      {enabled && (
        <ConditionsBuilder
          conditions={conditions}
          logic={choice.conditionsLogic || 'and'}
          onChange={write}
        />
      )}
    </div>
  );
}

function ChoiceEffectsEditor({ choice, onChange }: { choice: Choice; onChange: (updates: Partial<Choice>) => void }) {
  const effects = choice.effects || {};
  const entries = Object.entries(effects);

  const updateEntry = (oldKey: string, newKey: string, newValue: string | number | boolean) => {
    // Сохраняем порядок ключей
    const next: Record<string, string | number | boolean> = {};
    for (const [k, v] of Object.entries(effects)) {
      if (k === oldKey) {
        if (newKey) next[newKey] = newValue;
      } else {
        next[k] = v;
      }
    }
    onChange({ effects: next });
  };

  const removeEntry = (key: string) => {
    const next = { ...effects };
    delete next[key];
    onChange({ effects: next });
  };

  const addEntry = () => {
    let i = 1;
    while (Object.prototype.hasOwnProperty.call(effects, `var${i}`)) i++;
    onChange({ effects: { ...effects, [`var${i}`]: '+1' } });
  };

  const parseValue = (raw: string): string | number | boolean => {
    if (raw === 'true') return true;
    if (raw === 'false') return false;
    // Оставляем строкой для синтаксиса +N/-N/toggle (см. variable_engine.dart)
    if (/^[+-]/.test(raw) || raw === 'toggle') return raw;
    const n = Number(raw);
    if (raw !== '' && !isNaN(n)) return n;
    return raw;
  };

  return (
    <div className="choice-subblock">
      <div className="subblock-header">
        <span className="subblock-label">Эффекты выбора</span>
        <button className="add-effect" onClick={addEntry} title="Добавить эффект">
          <Plus size={12} />
        </button>
      </div>
      {entries.length > 0 && (
        <div className="effects-list">
          {entries.map(([key, value]) => (
            <div key={key} className="effect-row">
              <input
                placeholder="переменная"
                defaultValue={key}
                onBlur={(e) => {
                  const newKey = e.target.value;
                  if (newKey !== key) updateEntry(key, newKey, value);
                }}
                className="effect-key"
              />
              <input
                placeholder="+1 / -2 / 10 / toggle"
                value={String(value)}
                onChange={(e) => updateEntry(key, key, parseValue(e.target.value))}
                className="effect-val"
              />
              <button onClick={() => removeEntry(key)} className="delete" title="Удалить">
                <X size={12} />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/** unlockOutfits (v2 1.5): мультиселект «персонаж:аутфит». */
function ChoiceUnlockOutfitsEditor({ choice, onChange }: { choice: Choice; onChange: (updates: Partial<Choice>) => void }) {
  const characters = useEditorStore((s) => s.project.characters);
  const selected = choice.unlockOutfits || [];

  const allOptions: { key: string; label: string }[] = [];
  for (const ch of characters) {
    for (const outfit of ch.outfits || []) {
      allOptions.push({ key: `${ch.id}:${outfit.id}`, label: `${ch.name}: ${outfit.name || outfit.id}` });
    }
  }

  if (allOptions.length === 0 && selected.length === 0) return null;

  const available = allOptions.filter((o) => !selected.includes(o.key));

  const write = (next: string[]) => {
    onChange({ unlockOutfits: next.length > 0 ? next : undefined });
  };

  return (
    <div className="choice-subblock">
      <div className="subblock-header">
        <span className="subblock-label">👗 Разблокировать аутфиты</span>
      </div>
      {selected.length > 0 && (
        <div className="unlock-outfits-chips">
          {selected.map((key) => {
            const opt = allOptions.find((o) => o.key === key);
            return (
              <span key={key} className={`outfit-chip ${opt ? '' : 'broken'}`} title={opt ? key : `Аутфит "${key}" не найден`}>
                {opt?.label || key}
                <button type="button" onClick={() => write(selected.filter((k) => k !== key))} title="Убрать">
                  <X size={10} />
                </button>
              </span>
            );
          })}
        </div>
      )}
      {available.length > 0 && (
        <select
          value=""
          onChange={(e) => {
            if (!e.target.value) return;
            write([...selected, e.target.value]);
            e.target.value = '';
          }}
          className="outfit-add-select"
        >
          <option value="">+ Добавить аутфит…</option>
          {available.map((o) => (
            <option key={o.key} value={o.key}>{o.label}</option>
          ))}
        </select>
      )}
    </div>
  );
}
