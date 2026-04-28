import { useState } from 'react';
import { useEditorStore } from '../../store/editorStore';
import { validateProject, type ValidationError } from '../../utils/validator';
import { exportAsZip, exportAsJson, importProject, importProjectFromZip } from '../../utils/exporter';
import { Plus, Trash2, Download, Upload, AlertTriangle, CheckCircle, Users, BookOpen, Settings, Hash, Image, Globe } from 'lucide-react';
import type { Scene, CharacterSprite, NovelTranslation, NovelMeta } from '../../types/novel';
import './Sidebar.css';

type Tab = 'meta' | 'characters' | 'chapters' | 'variables' | 'validate' | 'translations';

/**
 * Условие "ассеты потеряны после refresh": persist уже отработал, у проекта
 * есть главы, но Map изображений пустая. Возвращает true только в этом
 * сочетании — нужно для warning-баннера и блокировки экспорта.
 */
export function useAssetsLost(): boolean {
  const hasHydrated = useEditorStore((s) => s.hasHydrated);
  const chaptersLen = useEditorStore((s) => s.project.chapters.length);
  const imagesSize = useEditorStore((s) => s.images.size);
  return hasHydrated && chaptersLen > 0 && imagesSize === 0;
}

export function Sidebar() {
  const [tab, setTab] = useState<Tab>('meta');
  const assetsLost = useAssetsLost();

  return (
    <div className="sidebar">
      <div className="sidebar-tabs">
        <button className={tab === 'meta' ? 'active' : ''} onClick={() => setTab('meta')} title="Мета"><Settings size={16} /></button>
        <button className={tab === 'characters' ? 'active' : ''} onClick={() => setTab('characters')} title="Персонажи"><Users size={16} /></button>
        <button className={tab === 'chapters' ? 'active' : ''} onClick={() => setTab('chapters')} title="Главы"><BookOpen size={16} /></button>
        <button className={tab === 'variables' ? 'active' : ''} onClick={() => setTab('variables')} title="Переменные"><Hash size={16} /></button>
        <button className={tab === 'translations' ? 'active' : ''} onClick={() => setTab('translations')} title="Переводы"><Globe size={16} /></button>
        <button className={tab === 'validate' ? 'active' : ''} onClick={() => setTab('validate')} title="Валидация"><AlertTriangle size={16} /></button>
      </div>
      <div className="sidebar-content">
        {assetsLost && (
          <div className="assets-lost-banner" role="alert">
            <AlertTriangle size={14} />
            <span>
              Картинки не сохраняются между сессиями. Перезагрузите ZIP проекта или загрузите ассеты заново перед экспортом.
            </span>
          </div>
        )}
        {tab === 'meta' && <MetaTab />}
        {tab === 'characters' && <CharactersTab />}
        {tab === 'chapters' && <ChaptersTab />}
        {tab === 'variables' && <VariablesTab />}
        {tab === 'translations' && <TranslationsTab />}
        {tab === 'validate' && <ValidateTab />}
      </div>
    </div>
  );
}

function MetaTab() {
  const { project, images, updateMeta, setProject, addImage, clearImages, setImages } = useEditorStore();
  const { meta } = project;
  const assetsLost = useAssetsLost();

  const coverPath = meta.coverImage || 'cg/cover.png';
  const coverUrl = useEditorStore((s) => s.imageUrls.get(coverPath));

  const handleImport = async () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,.zip';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      try {
        if (file.name.endsWith('.zip')) {
          const { project: imported, images: importedImages } = await importProjectFromZip(file);
          clearImages();
          setProject(imported);
          setImages(importedImages);
        } else {
          const imported = await importProject(file);
          setProject(imported);
        }
      } catch (err) {
        alert('Ошибка импорта: ' + (err as Error).message);
      }
    };
    input.click();
  };

  const handleCoverUpload = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (file) {
        addImage('cg/cover.png', file);
        updateMeta({ coverImage: 'cg/cover.png' });
      }
    };
    input.click();
  };

  return (
    <div className="tab-content">
      <h3>Метаданные</h3>

      {/* Обложка */}
      <label>Обложка</label>
      <div className="cover-upload" onClick={handleCoverUpload}>
        {coverUrl ? (
          <img src={coverUrl} alt="cover" className="cover-preview" />
        ) : (
          <div className="cover-placeholder">
            <Image size={24} />
            <span>Загрузить обложку</span>
          </div>
        )}
      </div>

      <label>ID новеллы</label>
      <input value={meta.id} onChange={(e) => updateMeta({ id: e.target.value })} placeholder="my_novel" />
      <label>Название</label>
      <input value={meta.title} onChange={(e) => updateMeta({ title: e.target.value })} placeholder="Название новеллы" />
      <label>Автор</label>
      <input value={meta.author} onChange={(e) => updateMeta({ author: e.target.value })} placeholder="Имя автора" />
      <label>Описание</label>
      <textarea value={meta.description} onChange={(e) => updateMeta({ description: e.target.value })} rows={3} placeholder="Описание новеллы..." />
      <label>Теги (через запятую)</label>
      <input
        value={meta.tags.join(', ')}
        onChange={(e) => updateMeta({ tags: e.target.value.split(',').map((t) => t.trim()).filter(Boolean) })}
        placeholder="романтика, мистика"
      />

      <label>Язык оригинала</label>
      <select
        value={meta.sourceLanguage || 'ru'}
        onChange={(e) => updateMeta({ sourceLanguage: e.target.value })}
      >
        <option value="ru">🇷🇺 Русский</option>
        <option value="en">🇬🇧 English</option>
        <option value="es">🇪🇸 Español</option>
        <option value="fr">🇫🇷 Français</option>
        <option value="de">🇩🇪 Deutsch</option>
        <option value="it">🇮🇹 Italiano</option>
        <option value="pt">🇧🇷 Português</option>
        <option value="tr">🇹🇷 Türkçe</option>
        <option value="ja">🇯🇵 日本語</option>
        <option value="ko">🇰🇷 한국어</option>
        <option value="zh">🇨🇳 中文</option>
      </select>

      <label>Тема диалогов</label>
      <select
        value={meta.dialogueTheme || 'ornate'}
        onChange={(e) => updateMeta({ dialogueTheme: e.target.value as NovelMeta['dialogueTheme'] })}
      >
        <option value="ornate">🏛️ Золотая классика</option>
        <option value="artDeco">💎 Art Deco</option>
        <option value="modern">🎨 Современный</option>
        <option value="glassmorphism">🪟 Glassmorphism</option>
        <option value="fantasy">🔮 Фэнтези</option>
        <option value="victorian">🏰 Викторианский</option>
        <option value="gothic">🦇 Готика</option>
        <option value="noir">🕵️ Нуар</option>
        <option value="sakura">🌸 Сакура</option>
        <option value="celestial">🌙 Небесная</option>
        <option value="cyberpunk">⚡ Киберпанк</option>
        <option value="steampunk">⚙️ Стимпанк</option>
        <option value="pirate">🏴‍☠️ Пиратская</option>
        <option value="medieval">⚔️ Средневековье</option>
        <option value="egyptian">🏺 Египетская</option>
        <option value="baroque">👑 Барокко</option>
        <option value="romantic">💕 Романтика</option>
        <option value="nordic">❄️ Скандинавская</option>
        <option value="tropical">🌴 Тропики</option>
        <option value="bloodMoon">🩸 Кровавая луна</option>
      </select>

      <label>Позиция диалогов</label>
      <div className="dialogue-style-row">
        <button
          className={`dialogue-style-btn ${(meta.dialogueStyle || 'classic') === 'classic' ? 'active' : ''}`}
          onClick={() => updateMeta({ dialogueStyle: 'classic' })}
        >
          ⬇ Снизу
        </button>
        <button
          className={`dialogue-style-btn ${meta.dialogueStyle === 'center' ? 'active' : ''}`}
          onClick={() => updateMeta({ dialogueStyle: 'center' })}
        >
          ⊡ По центру
        </button>
      </div>

      <label>Цвет рамки диалога (опционально)</label>
      <div className="color-row">
        <input
          type="color"
          value={meta.dialogueFrameColor || '#B8860B'}
          onChange={(e) => updateMeta({ dialogueFrameColor: e.target.value })}
        />
        <input
          value={meta.dialogueFrameColor || ''}
          onChange={(e) => updateMeta({ dialogueFrameColor: e.target.value || undefined })}
          placeholder="Авто (по теме)"
          className="color-hex"
        />
        {meta.dialogueFrameColor && (
          <button className="color-clear" onClick={() => updateMeta({ dialogueFrameColor: undefined })}>✕</button>
        )}
      </div>

      <label>Цвет фона диалога (опционально)</label>
      <div className="color-row">
        <input
          type="color"
          value={meta.dialogueBgColor || '#1A1410'}
          onChange={(e) => updateMeta({ dialogueBgColor: e.target.value })}
        />
        <input
          value={meta.dialogueBgColor || ''}
          onChange={(e) => updateMeta({ dialogueBgColor: e.target.value || undefined })}
          placeholder="Авто (по теме)"
          className="color-hex"
        />
        {meta.dialogueBgColor && (
          <button className="color-clear" onClick={() => updateMeta({ dialogueBgColor: undefined })}>✕</button>
        )}
      </div>

      <div className="actions-group">
        <button
          onClick={() => exportAsZip(project, images)}
          className="primary"
          disabled={assetsLost}
          title={assetsLost ? 'Загрузите ассеты перед экспортом' : undefined}
        >
          <Download size={14} /> ZIP для Amoria
        </button>
        <button onClick={() => exportAsJson(project)}><Download size={14} /> JSON</button>
        <button onClick={handleImport}><Upload size={14} /> Импорт (JSON/ZIP)</button>
      </div>
    </div>
  );
}

function CharactersTab() {
  const { project, addCharacter, updateCharacter, removeCharacter, addImage, removeImage } = useEditorStore();

  const handleAdd = () => {
    const id = `char_${Date.now()}`;
    addCharacter({
      id,
      name: 'Новый персонаж',
      color: '#E91E63',
      sprites: [{ id: 'neutral', image: `sprites/${id}/${id}_neutral.png`, label: 'Спокойный' }],
    });
  };

  const handleAddSprite = (charId: string) => {
    const char = project.characters.find((c) => c.id === charId);
    if (!char) return;
    const spriteId = `sprite_${Date.now()}`;
    const sprites: CharacterSprite[] = [...char.sprites, { id: spriteId, image: `sprites/${charId}/${charId}_${spriteId}.png`, label: 'Новый' }];
    updateCharacter(charId, { sprites });
  };

  const handleUpdateSprite = (charId: string, spriteIndex: number, updates: Partial<CharacterSprite>) => {
    const char = project.characters.find((c) => c.id === charId);
    if (!char) return;
    const sprites = char.sprites.map((s, i) => i === spriteIndex ? { ...s, ...updates } : s);
    updateCharacter(charId, { sprites });
  };

  const handleRemoveSprite = (charId: string, spriteIndex: number) => {
    const char = project.characters.find((c) => c.id === charId);
    if (!char || char.sprites.length <= 1) return;
    const removed = char.sprites[spriteIndex];
    removeImage(removed.image);
    const sprites = char.sprites.filter((_, i) => i !== spriteIndex);
    updateCharacter(charId, { sprites });
  };

  const handleSpriteUpload = (charId: string, spriteIndex: number) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const char = project.characters.find((c) => c.id === charId);
      if (!char) return;
      const sprite = char.sprites[spriteIndex];
      // Путь: sprites/{charId}/{charId}_{spriteId}.png
      const ext = file.name.split('.').pop() || 'png';
      const zipPath = `sprites/${charId}/${charId}_${sprite.id}.${ext}`;
      addImage(zipPath, file);
      handleUpdateSprite(charId, spriteIndex, { image: zipPath });
    };
    input.click();
  };

  return (
    <div className="tab-content">
      <div className="tab-header">
        <h3>Персонажи</h3>
        <button onClick={handleAdd} className="add-btn"><Plus size={14} /></button>
      </div>
      {project.characters.map((char) => (
        <CharacterCard
          key={char.id}
          char={char}
          onUpdate={(updates) => updateCharacter(char.id, updates)}
          onRemove={() => removeCharacter(char.id)}
          onAddSprite={() => handleAddSprite(char.id)}
          onUpdateSprite={(i, u) => handleUpdateSprite(char.id, i, u)}
          onRemoveSprite={(i) => handleRemoveSprite(char.id, i)}
          onUploadSprite={(i) => handleSpriteUpload(char.id, i)}
        />
      ))}
    </div>
  );
}

function CharacterCard({ char, onUpdate, onRemove, onAddSprite, onUpdateSprite, onRemoveSprite, onUploadSprite }: {
  char: { id: string; name: string; color: string; sprites: CharacterSprite[] };
  onUpdate: (updates: Record<string, unknown>) => void;
  onRemove: () => void;
  onAddSprite: () => void;
  onUpdateSprite: (index: number, updates: Partial<CharacterSprite>) => void;
  onRemoveSprite: (index: number) => void;
  onUploadSprite: (index: number) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const imageUrls = useEditorStore((s) => s.imageUrls);

  return (
    <div className="character-card">
      <div className="char-header">
        <input className="char-color" type="color" value={char.color} onChange={(e) => onUpdate({ color: e.target.value })} />
        <input value={char.name} onChange={(e) => onUpdate({ name: e.target.value })} placeholder="Имя" />
        <button onClick={() => setExpanded(!expanded)} className="expand-btn" title="Спрайты">{expanded ? '▲' : '▼'}</button>
        <button onClick={onRemove} className="delete"><Trash2 size={12} /></button>
      </div>
      <input
        value={char.id}
        onChange={(e) => onUpdate({ id: e.target.value })}
        className="char-id"
        placeholder="ID"
      />

      {expanded && (
        <div className="sprites-section">
          <div className="sprites-header">
            <span className="sprites-label">Спрайты ({char.sprites.length})</span>
            <button onClick={onAddSprite} className="add-btn small"><Plus size={12} /></button>
          </div>
          {char.sprites.map((sprite, i) => {
            const spriteUrl = imageUrls.get(sprite.image);
            return (
              <div key={sprite.id} className="sprite-item">
                <div className="sprite-thumb" onClick={() => onUploadSprite(i)} title="Загрузить изображение">
                  {spriteUrl ? (
                    <img src={spriteUrl} alt={sprite.label} />
                  ) : (
                    <Image size={14} />
                  )}
                </div>
                <input value={sprite.id} onChange={(e) => onUpdateSprite(i, { id: e.target.value })} placeholder="ID" className="sprite-id-input" />
                <input value={sprite.label} onChange={(e) => onUpdateSprite(i, { label: e.target.value })} placeholder="Название" className="sprite-label-input" />
                {char.sprites.length > 1 && (
                  <button onClick={() => onRemoveSprite(i)} className="delete"><Trash2 size={10} /></button>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function ChaptersTab() {
  const { project, selectedChapterIndex, selectChapter, addChapter, removeChapter, addScene, selectScene, selectedSceneId } = useEditorStore();

  const handleAddScene = () => {
    const chapter = project.chapters[selectedChapterIndex];
    const sceneId = `${chapter.id}_scene_${chapter.scenes.length + 1}`;
    const scene: Scene = {
      id: sceneId,
      charactersOnScreen: [],
      events: [{ type: 'narration', text: '' }],
    };
    addScene(scene);
  };

  return (
    <div className="tab-content">
      <div className="tab-header">
        <h3>Главы</h3>
        <button onClick={addChapter} className="add-btn"><Plus size={14} /></button>
      </div>
      {project.chapters.map((ch, i) => (
        <div key={ch.id} className={`chapter-card ${i === selectedChapterIndex ? 'selected' : ''}`}>
          <div className="chapter-header" onClick={() => selectChapter(i)}>
            <span>{ch.title}</span>
            <span className="scene-count">{ch.scenes.length} сцен</span>
            {project.chapters.length > 1 && (
              <button onClick={(e) => { e.stopPropagation(); removeChapter(i); }} className="delete"><Trash2 size={12} /></button>
            )}
          </div>
          {i === selectedChapterIndex && (
            <div className="scenes-list">
              {ch.scenes.map((s) => (
                <div
                  key={s.id}
                  className={`scene-item ${s.id === selectedSceneId ? 'selected' : ''}`}
                  onClick={() => selectScene(s.id)}
                >
                  <span>{s.id}</span>
                  <span className="event-count">{s.events.length} соб.</span>
                </div>
              ))}
              <button className="add-scene" onClick={handleAddScene}>
                <Plus size={12} /> Сцена
              </button>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

function VariablesTab() {
  const { project, setVariable, removeVariable } = useEditorStore();
  const [newKey, setNewKey] = useState('');

  const handleAdd = () => {
    if (newKey.trim()) {
      setVariable(newKey.trim(), 0);
      setNewKey('');
    }
  };

  return (
    <div className="tab-content">
      <h3>Переменные</h3>
      <div className="var-add">
        <input value={newKey} onChange={(e) => setNewKey(e.target.value)} placeholder="Имя переменной" onKeyDown={(e) => e.key === 'Enter' && handleAdd()} />
        <button onClick={handleAdd} className="add-btn"><Plus size={14} /></button>
      </div>
      {Object.entries(project.variables).map(([key, value]) => (
        <div key={key} className="var-item">
          <span className="var-key">{key}</span>
          <input
            value={String(value)}
            onChange={(e) => {
              const v = e.target.value;
              const num = Number(v);
              setVariable(key, isNaN(num) ? (v === 'true' ? true : v === 'false' ? false : v) : num);
            }}
            className="var-value"
          />
          <button onClick={() => removeVariable(key)} className="delete"><Trash2 size={12} /></button>
        </div>
      ))}
    </div>
  );
}

function ValidateTab() {
  const { project, images } = useEditorStore();
  const [errors, setErrors] = useState<ValidationError[]>([]);
  const [validated, setValidated] = useState(false);

  const handleValidate = () => {
    setErrors(validateProject(project, images));
    setValidated(true);
  };

  const errorCount = errors.filter((e) => e.type === 'error').length;
  const warnCount = errors.filter((e) => e.type === 'warning').length;

  return (
    <div className="tab-content">
      <h3>Валидация</h3>
      <button onClick={handleValidate} className="primary validate-btn">
        <AlertTriangle size={14} /> Проверить сценарий
      </button>

      {validated && errors.length === 0 && (
        <div className="validation-ok">
          <CheckCircle size={20} />
          <span>Всё в порядке!</span>
        </div>
      )}

      {validated && errors.length > 0 && (
        <>
          <div className="validation-summary">
            {errorCount > 0 && <span className="error-count">❌ {errorCount} ошибок</span>}
            {warnCount > 0 && <span className="warn-count">⚠️ {warnCount} предупреждений</span>}
          </div>
          <div className="validation-list">
            {errors.map((err, i) => (
              <div key={i} className={`validation-item ${err.type}`}>
                <span>{err.type === 'error' ? '❌' : '⚠️'}</span>
                <span>{err.message}</span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

const AVAILABLE_LANGUAGES = [
  { code: 'en', flag: '🇬🇧', name: 'English' },
  { code: 'ru', flag: '🇷🇺', name: 'Русский' },
  { code: 'es', flag: '🇪🇸', name: 'Español' },
  { code: 'fr', flag: '🇫🇷', name: 'Français' },
  { code: 'de', flag: '🇩🇪', name: 'Deutsch' },
  { code: 'it', flag: '🇮🇹', name: 'Italiano' },
  { code: 'pt', flag: '🇧🇷', name: 'Português' },
  { code: 'tr', flag: '🇹🇷', name: 'Türkçe' },
  { code: 'ko', flag: '🇰🇷', name: '한국어' },
  { code: 'ja', flag: '🇯🇵', name: '日本語' },
  { code: 'zh', flag: '🇨🇳', name: '中文' },
];

function TranslationsTab() {
  const {
    project,
    selectedTranslationLang,
    setTranslation,
    removeTranslation,
    updateTranslationText,
    updateTranslationMeta,
    updateTranslationCharacter,
    updateTranslationChapter,
    selectTranslationLang,
  } = useEditorStore();

  const translations = project.translations || {};
  const sourceLang = project.meta.sourceLanguage || 'ru';
  const selectedLang = selectedTranslationLang;

  // Собрать все уникальные тексты из всех глав
  const allTexts: string[] = [];
  for (const chapter of project.chapters) {
    for (const scene of chapter.scenes) {
      for (const event of scene.events) {
        if (event.text && (event.type === 'dialogue' || event.type === 'narration')) {
          if (!allTexts.includes(event.text)) allTexts.push(event.text);
        }
        if (event.choices) {
          for (const choice of event.choices) {
            if (choice.text && !allTexts.includes(choice.text)) allTexts.push(choice.text);
          }
        }
      }
    }
  }

  const addLanguage = (langCode: string) => {
    const lang = AVAILABLE_LANGUAGES.find((l) => l.code === langCode);
    if (!lang || translations[langCode]) return;
    const newTranslation: NovelTranslation = {
      meta: { language: langCode, sourceLanguage: sourceLang, novelId: project.meta.id, version: 1 },
      novel: { title: '', description: '' },
      characters: {},
      chapters: {},
      texts: {},
    };
    setTranslation(langCode, newTranslation);
    selectTranslationLang(langCode);
  };

  const currentTranslation = selectedLang ? translations[selectedLang] : null;
  const langMeta = selectedLang ? AVAILABLE_LANGUAGES.find((l) => l.code === selectedLang) : null;
  const addedLangs = Object.keys(translations);
  const availableLangs = AVAILABLE_LANGUAGES.filter((l) => l.code !== sourceLang && !addedLangs.includes(l.code));
  const translatedCount = currentTranslation ? Object.values(currentTranslation.texts).filter((v) => v && v.trim()).length : 0;

  return (
    <div className="tab-content">
      <h3>Переводы</h3>

      <div className="hint" style={{ marginBottom: 12, opacity: 0.7, fontSize: 12 }}>
        Язык оригинала: <b>{AVAILABLE_LANGUAGES.find((l) => l.code === sourceLang)?.name || sourceLang}</b>{' '}
        (изменить можно во вкладке «Мета»)
      </div>

      {/* Список добавленных языков */}
      <label>Языки перевода</label>
      <div className="translation-langs">
        {addedLangs.map((code) => {
          const lang = AVAILABLE_LANGUAGES.find((l) => l.code === code);
          return (
            <div key={code} className={`translation-lang-item ${selectedLang === code ? 'active' : ''}`}>
              <button className="lang-select-btn" onClick={() => selectTranslationLang(code)}>
                {lang?.flag} {lang?.name || code}
              </button>
              <button className="lang-remove-btn" onClick={() => { removeTranslation(code); if (selectedLang === code) selectTranslationLang(null); }}>
                <Trash2 size={12} />
              </button>
            </div>
          );
        })}
      </div>

      {/* Добавить язык */}
      {availableLangs.length > 0 && (
        <select onChange={(e) => { if (e.target.value) addLanguage(e.target.value); e.target.value = ''; }} defaultValue="">
          <option value="" disabled>+ Добавить язык...</option>
          {availableLangs.map((l) => (
            <option key={l.code} value={l.code}>{l.flag} {l.name}</option>
          ))}
        </select>
      )}

      {/* Редактор перевода */}
      {currentTranslation && selectedLang && langMeta && (
        <div className="translation-editor">
          <h4>{langMeta.flag} {langMeta.name}</h4>
          <div className="translation-progress">
            {translatedCount}/{allTexts.length} текстов переведено
          </div>

          {/* Мета */}
          <label>Название</label>
          <input
            value={currentTranslation.novel?.title || ''}
            onChange={(e) => updateTranslationMeta(selectedLang, 'novelTitle', e.target.value)}
            placeholder={project.meta.title}
          />
          <label>Описание</label>
          <textarea
            value={currentTranslation.novel?.description || ''}
            onChange={(e) => updateTranslationMeta(selectedLang, 'novelDescription', e.target.value)}
            placeholder={project.meta.description}
            rows={2}
          />

          {/* Персонажи */}
          {project.characters.length > 0 && (
            <>
              <label>Персонажи</label>
              {project.characters.map((ch) => (
                <div key={ch.id} className="translation-row">
                  <span className="translation-original">{ch.name}</span>
                  <input
                    value={currentTranslation.characters?.[ch.id]?.name || ''}
                    onChange={(e) => updateTranslationCharacter(selectedLang, ch.id, e.target.value)}
                    placeholder={ch.name}
                  />
                </div>
              ))}
            </>
          )}

          {/* Главы */}
          <label>Главы</label>
          {project.chapters.map((ch) => (
            <div key={ch.id} className="translation-row">
              <span className="translation-original">{ch.title}</span>
              <input
                value={currentTranslation.chapters?.[ch.id]?.title || ''}
                onChange={(e) => updateTranslationChapter(selectedLang, ch.id, e.target.value)}
                placeholder={ch.title}
              />
            </div>
          ))}

          {/* Тексты */}
          <label>Тексты ({allTexts.length})</label>
          <div className="translation-texts">
            {allTexts.map((text, i) => (
              <div key={i} className="translation-text-item">
                <div className="translation-original">{text}</div>
                <textarea
                  value={currentTranslation.texts[text] || ''}
                  onChange={(e) => updateTranslationText(selectedLang, text, e.target.value)}
                  placeholder="Перевод..."
                  rows={1}
                />
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
