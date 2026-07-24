import { useEffect, useMemo, useState } from 'react';
import { useEditorStore } from '../../store/editorStore';
import { useAssetsLost } from '../../hooks/useAssetsLost';
import { type ValidationError } from '../../utils/validator';
import { exportAsZip, exportAsJson, importProject, importProjectFromZip, exportTranslationFile, importTranslationFile, buildZipBlob, blockingErrors } from '../../utils/exporter';
import { collectTranslatableStrings, findStaleTranslations } from '../../utils/translatable';
import { loadPublishSettings, savePublishSettings, login as apiLogin, uploadNovelZip, uploadChapter, novelExists, PublishError, DEFAULT_BASE_URL, type PublishSettings } from '../../utils/publish';
import { allSceneIds, uniqueSceneId, uniqueCharacterId, uniqueSpriteId, uniqueOutfitId } from '../../utils/ids';
import { SceneSelect } from '../common/SceneSelect';
import { Plus, Trash2, Download, Upload, AlertTriangle, CheckCircle, Users, BookOpen, Settings, Hash, Image, Globe, Music, Search, CloudUpload, Play, Pause, FileDown, FileUp, Shirt, LogIn, LogOut, Send } from 'lucide-react';
import type { Character, Scene, CharacterSprite, NovelTranslation, NovelMeta, Outfit, StatDisplay, EndingMetaEntry } from '../../types/novel';
import type { SidebarTab } from '../../store/editorStore';
import './Sidebar.css';

/** Навигация к месту ошибки/совпадения: глава → сцена (+центрирование графа) → событие. */
function navigateTo(chapterId?: string, sceneId?: string, eventIndex?: number) {
  const st = useEditorStore.getState();
  if (chapterId) {
    const idx = st.project.chapters.findIndex((c) => c.id === chapterId);
    if (idx >= 0 && idx !== st.selectedChapterIndex) st.selectChapter(idx);
  }
  if (sceneId) {
    useEditorStore.getState().selectScene(sceneId);
    useEditorStore.getState().focusScene(sceneId);
  }
  if (eventIndex !== undefined) useEditorStore.getState().selectEvent(eventIndex);
}

export function Sidebar() {
  const tab = useEditorStore((s) => s.sidebarTab);
  const setTab = useEditorStore((s) => s.setSidebarTab);
  const errorCount = useEditorStore((s) => s.validationErrors.filter((e) => e.type === 'error').length);
  const assetsLost = useAssetsLost();

  const tabBtn = (t: SidebarTab, title: string, icon: React.ReactNode, badge?: number) => (
    <button className={tab === t ? 'active' : ''} onClick={() => setTab(t)} title={title}>
      {icon}
      {badge !== undefined && badge > 0 && <span className="tab-badge">{badge > 99 ? '99+' : badge}</span>}
    </button>
  );

  return (
    <div className="sidebar">
      <div className="sidebar-tabs">
        {tabBtn('meta', 'Мета', <Settings size={16} />)}
        {tabBtn('characters', 'Персонажи', <Users size={16} />)}
        {tabBtn('chapters', 'Главы', <BookOpen size={16} />)}
        {tabBtn('variables', 'Переменные', <Hash size={16} />)}
        {tabBtn('audio', 'Аудио', <Music size={16} />)}
        {tabBtn('translations', 'Переводы', <Globe size={16} />)}
        {tabBtn('search', 'Поиск', <Search size={16} />)}
        {tabBtn('publish', 'Публикация', <CloudUpload size={16} />)}
        {tabBtn('validate', 'Валидация', <AlertTriangle size={16} />, errorCount)}
      </div>
      <div className="sidebar-content">
        {assetsLost && (
          <div className="assets-lost-banner" role="alert">
            <AlertTriangle size={14} />
            <span>
              Ассеты этого проекта не были сохранены (старый формат хранения). Перезагрузите ZIP проекта или загрузите файлы заново — теперь они сохраняются между сессиями.
            </span>
          </div>
        )}
        {tab === 'meta' && <MetaTab />}
        {tab === 'characters' && <CharactersTab />}
        {tab === 'chapters' && <ChaptersTab />}
        {tab === 'variables' && <VariablesTab />}
        {tab === 'audio' && <AudioTab />}
        {tab === 'translations' && <TranslationsTab />}
        {tab === 'search' && <SearchTab />}
        {tab === 'publish' && <PublishTab />}
        {tab === 'validate' && <ValidateTab />}
      </div>
    </div>
  );
}

function MetaTab() {
  const { project, assets, updateMeta, setProject, addAsset, clearAssets, setAssets } = useEditorStore();
  const { meta } = project;

  const coverPath = meta.coverImage || 'cg/cover.png';
  const coverUrl = useEditorStore((s) => s.assetUrls.get(coverPath));

  const handleImport = async () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,.zip';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      try {
        if (file.name.endsWith('.zip')) {
          const { project: imported, assets: importedAssets } = await importProjectFromZip(file);
          clearAssets();
          setProject(imported);
          setAssets(importedAssets);
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
        addAsset('cg/cover.png', file);
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

      <PlayerNamePromptEditor />
      <EndingsMetaEditor />
      <StatsDisplayEditor />

      <div className="actions-group">
        <button
          onClick={() => exportAsZip(project, assets)}
          className="primary"
        >
          <Download size={14} /> ZIP для Amoria
        </button>
        <button onClick={() => exportAsJson(project)}><Download size={14} /> JSON</button>
        <button onClick={handleImport}><Upload size={14} /> Импорт (JSON/ZIP)</button>
      </div>
    </div>
  );
}

/** v2 1.4: запрос имени игрока. */
function PlayerNamePromptEditor() {
  const meta = useEditorStore((s) => s.project.meta);
  const updateMeta = useEditorStore((s) => s.updateMeta);
  const pnp = meta.playerNamePrompt;

  return (
    <div className="meta-subsection">
      <label className="meta-check-row">
        <input
          type="checkbox"
          checked={!!pnp?.enabled}
          onChange={(e) => updateMeta({
            playerNamePrompt: e.target.checked
              ? { enabled: true, prompt: pnp?.prompt || 'Как тебя зовут?', defaultName: pnp?.defaultName || '' }
              : (pnp ? { ...pnp, enabled: false } : undefined),
          })}
        />
        <span>Запрос имени игрока ({'{name}'})</span>
      </label>
      {pnp?.enabled && (
        <>
          <input
            value={pnp.prompt || ''}
            onChange={(e) => updateMeta({ playerNamePrompt: { ...pnp, prompt: e.target.value } })}
            placeholder="Как тебя зовут?"
          />
          <input
            value={pnp.defaultName || ''}
            onChange={(e) => updateMeta({ playerNamePrompt: { ...pnp, defaultName: e.target.value || undefined } })}
            placeholder="Имя по умолчанию (Алиса)"
          />
        </>
      )}
    </div>
  );
}

/** v2 1.3: список концовок для галереи «N из M». */
function EndingsMetaEditor() {
  const meta = useEditorStore((s) => s.project.meta);
  const updateMeta = useEditorStore((s) => s.updateMeta);
  const project = useEditorStore((s) => s.project);
  const endings = meta.endings || [];

  const write = (next: EndingMetaEntry[]) => {
    updateMeta({ endings: next.length > 0 ? next : undefined });
  };

  const update = (i: number, patch: Partial<EndingMetaEntry>) => {
    write(endings.map((e, ei) => ei === i ? { ...e, ...patch } : e));
  };

  // Подсказки: id концовок, назначенных сценам, которых нет в мете
  const sceneEndingIds = new Set<string>();
  for (const ch of project.chapters) {
    for (const sc of ch.scenes) {
      if (sc.ending?.id) sceneEndingIds.add(sc.ending.id);
    }
  }
  const missing = Array.from(sceneEndingIds).filter((id) => !endings.some((e) => e.id === id));

  return (
    <div className="meta-subsection">
      <div className="meta-subsection-header">
        <label>🏁 Концовки (галерея «N из M»)</label>
        <button
          className="add-btn small"
          onClick={() => write([...endings, { id: `ending_${endings.length + 1}`, title: '' }])}
          title="Добавить концовку"
        >
          <Plus size={12} />
        </button>
      </div>
      {endings.map((ending, i) => (
        <div key={i} className="meta-list-row">
          <input
            value={ending.id}
            onChange={(e) => update(i, { id: e.target.value })}
            placeholder="id"
            className="meta-id-input"
          />
          <input
            value={ending.title}
            onChange={(e) => update(i, { title: e.target.value })}
            placeholder="Заголовок"
          />
          <label className="hidden-toggle" title="Скрытая: до открытия показывается как «???»">
            <input
              type="checkbox"
              checked={!!ending.hidden}
              onChange={(e) => update(i, { hidden: e.target.checked || undefined })}
            />
            🙈
          </label>
          <button className="delete" onClick={() => write(endings.filter((_, ei) => ei !== i))}><Trash2 size={12} /></button>
        </div>
      ))}
      {missing.length > 0 && (
        <button
          className="meta-hint-btn"
          onClick={() => write([...endings, ...missing.map((id) => ({ id, title: '' }))])}
          title="В сценах назначены концовки, которых нет в списке меты"
        >
          + добавить из сцен: {missing.join(', ')}
        </button>
      )}
    </div>
  );
}

/** v2 1.9: панель отношений (statsDisplay). */
function StatsDisplayEditor() {
  const meta = useEditorStore((s) => s.project.meta);
  const variables = useEditorStore((s) => s.project.variables);
  const updateMeta = useEditorStore((s) => s.updateMeta);
  const stats = meta.statsDisplay || [];

  const write = (next: StatDisplay[]) => {
    updateMeta({ statsDisplay: next.length > 0 ? next : undefined });
  };

  const update = (i: number, patch: Partial<StatDisplay>) => {
    write(stats.map((s, si) => si === i ? { ...s, ...patch } : s));
  };

  return (
    <div className="meta-subsection">
      <div className="meta-subsection-header">
        <label>📊 Панель статов (statsDisplay)</label>
        <button
          className="add-btn small"
          onClick={() => write([...stats, { variable: Object.keys(variables)[0] || '', label: '', icon: 'heart', color: '#E91E63', max: 100 }])}
          title="Добавить стат"
        >
          <Plus size={12} />
        </button>
      </div>
      {stats.map((stat, i) => (
        <div key={i} className="stat-display-card">
          <div className="meta-list-row">
            <input
              value={stat.variable}
              onChange={(e) => update(i, { variable: e.target.value })}
              placeholder="переменная"
              list="sidebar-variable-names"
              className="meta-id-input"
            />
            <input
              value={stat.label}
              onChange={(e) => update(i, { label: e.target.value })}
              placeholder="Подпись (Мия)"
            />
            <button className="delete" onClick={() => write(stats.filter((_, si) => si !== i))}><Trash2 size={12} /></button>
          </div>
          <div className="meta-list-row">
            <select
              value={stat.icon || 'heart'}
              onChange={(e) => update(i, { icon: e.target.value as StatDisplay['icon'] })}
              className="stat-icon-select"
            >
              <option value="heart">♥ heart</option>
              <option value="star">★ star</option>
              <option value="flame">🔥 flame</option>
              <option value="diamond">💎 diamond</option>
              <option value="moon">🌙 moon</option>
              <option value="sun">☀️ sun</option>
              <option value="leaf">🍃 leaf</option>
            </select>
            <input
              type="color"
              value={stat.color || '#E91E63'}
              onChange={(e) => update(i, { color: e.target.value })}
              className="stat-color-input"
              title="Цвет"
            />
            <input
              type="number"
              value={stat.max ?? 100}
              onChange={(e) => update(i, { max: parseInt(e.target.value) || undefined })}
              placeholder="max"
              className="stat-max-input"
              title="Максимум шкалы"
              min={1}
            />
          </div>
        </div>
      ))}
      <datalist id="sidebar-variable-names">
        {Object.keys(variables).map((v) => <option key={v} value={v} />)}
      </datalist>
    </div>
  );
}

function CharactersTab() {
  const { project, addCharacter } = useEditorStore();

  const handleAdd = () => {
    // Детерминированный уникальный id (без Date.now в теле рендера).
    const id = uniqueCharacterId(project.characters);
    addCharacter({
      id,
      name: 'Новый персонаж',
      color: '#E91E63',
      sprites: [{ id: 'neutral', image: `sprites/${id}/${id}_neutral.png`, label: 'Спокойный' }],
    });
  };

  return (
    <div className="tab-content">
      <div className="tab-header">
        <h3>Персонажи</h3>
        <button onClick={handleAdd} className="add-btn"><Plus size={14} /></button>
      </div>
      {project.characters.map((char) => (
        <CharacterCard key={char.id} char={char} />
      ))}
    </div>
  );
}

function CharacterCard({ char }: { char: Character }) {
  const { updateCharacter, removeCharacter, addAsset, removeAsset } = useEditorStore();
  const [expanded, setExpanded] = useState(false);
  const [outfitsExpanded, setOutfitsExpanded] = useState(false);
  const assetUrls = useEditorStore((s) => s.assetUrls);

  const onUpdate = (updates: Partial<Character>) => updateCharacter(char.id, updates);

  const handleAddSprite = () => {
    const spriteId = uniqueSpriteId(char.sprites);
    const sprites: CharacterSprite[] = [...char.sprites, { id: spriteId, image: `sprites/${char.id}/${char.id}_${spriteId}.png`, label: 'Новый' }];
    onUpdate({ sprites });
  };

  const handleUpdateSprite = (spriteIndex: number, updates: Partial<CharacterSprite>) => {
    const sprites = char.sprites.map((s, i) => i === spriteIndex ? { ...s, ...updates } : s);
    onUpdate({ sprites });
  };

  const handleRemoveSprite = (spriteIndex: number) => {
    if (char.sprites.length <= 1) return;
    const removed = char.sprites[spriteIndex];
    removeAsset(removed.image);
    const sprites = char.sprites.filter((_, i) => i !== spriteIndex);
    onUpdate({ sprites });
  };

  const handleSpriteUpload = (spriteIndex: number) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const sprite = char.sprites[spriteIndex];
      // Путь: sprites/{charId}/{charId}_{spriteId}.png
      const ext = file.name.split('.').pop() || 'png';
      const zipPath = `sprites/${char.id}/${char.id}_${sprite.id}.${ext}`;
      addAsset(zipPath, file);
      handleUpdateSprite(spriteIndex, { image: zipPath });
    };
    input.click();
  };

  return (
    <div className="character-card">
      <div className="char-header">
        <input className="char-color" type="color" value={char.color} onChange={(e) => onUpdate({ color: e.target.value })} />
        <input value={char.name} onChange={(e) => onUpdate({ name: e.target.value })} placeholder="Имя" />
        <button onClick={() => setExpanded(!expanded)} className="expand-btn" title="Спрайты">{expanded ? '▲' : '▼'}</button>
        <button onClick={() => removeCharacter(char.id)} className="delete"><Trash2 size={12} /></button>
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
            <button onClick={handleAddSprite} className="add-btn small"><Plus size={12} /></button>
          </div>
          {char.sprites.map((sprite, i) => {
            const spriteUrl = assetUrls.get(sprite.image);
            return (
              <div key={sprite.id} className="sprite-item">
                <div className="sprite-thumb" onClick={() => handleSpriteUpload(i)} title="Загрузить изображение">
                  {spriteUrl ? (
                    <img src={spriteUrl} alt={sprite.label} />
                  ) : (
                    <Image size={14} />
                  )}
                </div>
                <input value={sprite.id} onChange={(e) => handleUpdateSprite(i, { id: e.target.value })} placeholder="ID" className="sprite-id-input" />
                <input value={sprite.label} onChange={(e) => handleUpdateSprite(i, { label: e.target.value })} placeholder="Название" className="sprite-label-input" />
                {char.sprites.length > 1 && (
                  <button onClick={() => handleRemoveSprite(i)} className="delete"><Trash2 size={10} /></button>
                )}
              </div>
            );
          })}

          <div className="sprites-header outfits-header">
            <span className="sprites-label"><Shirt size={11} /> Аутфиты ({char.outfits?.length || 0})</span>
            <div className="outfits-header-actions">
              <button
                onClick={() => {
                  const outfits = char.outfits || [];
                  const id = uniqueOutfitId(outfits);
                  onUpdate({
                    outfits: [...outfits, {
                      id,
                      name: 'Новый аутфит',
                      ...(outfits.length === 0 ? { default: true } : {}),
                      sprites: {},
                    }],
                  });
                  setOutfitsExpanded(true);
                }}
                className="add-btn small"
                title="Добавить аутфит"
              >
                <Plus size={12} />
              </button>
              {(char.outfits?.length || 0) > 0 && (
                <button onClick={() => setOutfitsExpanded(!outfitsExpanded)} className="expand-btn" title="Показать/скрыть">{outfitsExpanded ? '▲' : '▼'}</button>
              )}
            </div>
          </div>
          {outfitsExpanded && (char.outfits || []).map((outfit, oi) => (
            <OutfitEditor key={outfit.id + oi} char={char} outfit={outfit} index={oi} />
          ))}
        </div>
      )}
    </div>
  );
}

/** v2 1.5: редактор аутфита — id, name, default, priceDiamonds, thumbnail,
 *  sprites (маппинг спрайт-ключ → путь картинки с загрузкой). */
function OutfitEditor({ char, outfit, index }: { char: Character; outfit: Outfit; index: number }) {
  const { updateCharacter, addAsset } = useEditorStore();
  const assetUrls = useEditorStore((s) => s.assetUrls);
  const [newKey, setNewKey] = useState('');

  const writeOutfits = (outfits: Outfit[]) => {
    updateCharacter(char.id, { outfits: outfits.length > 0 ? outfits : undefined });
  };

  const update = (patch: Partial<Outfit>) => {
    writeOutfits((char.outfits || []).map((o, i) => i === index ? { ...o, ...patch } : o));
  };

  const remove = () => {
    writeOutfits((char.outfits || []).filter((_, i) => i !== index));
  };

  const setDefault = (checked: boolean) => {
    // default может быть только один: включение снимает флаг с остальных
    writeOutfits((char.outfits || []).map((o, i) => ({
      ...o,
      default: i === index ? (checked || undefined) : (checked ? undefined : o.default),
    })));
  };

  const uploadThumbnail = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const ext = file.name.split('.').pop() || 'png';
      const zipPath = `sprites/${char.id}/${outfit.id}_thumb.${ext}`;
      addAsset(zipPath, file);
      update({ thumbnail: zipPath });
    };
    input.click();
  };

  const uploadOutfitSprite = (key: string) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const ext = file.name.split('.').pop() || 'png';
      const zipPath = `sprites/${char.id}/${outfit.id}_${key}.${ext}`;
      addAsset(zipPath, file);
      update({ sprites: { ...outfit.sprites, [key]: zipPath } });
    };
    input.click();
  };

  const removeSpriteKey = (key: string) => {
    const next = { ...outfit.sprites };
    delete next[key];
    update({ sprites: next });
  };

  const addSpriteKey = (key: string) => {
    const k = key.trim();
    if (!k || outfit.sprites[k] !== undefined) return;
    update({ sprites: { ...outfit.sprites, [k]: '' } });
    setNewKey('');
  };

  const thumbUrl = outfit.thumbnail ? assetUrls.get(outfit.thumbnail) : undefined;
  // Ключи спрайтов персонажа как подсказки (default обязателен по спеке-фолбэку)
  const suggestedKeys = ['default', ...char.sprites.map((s) => s.id)].filter((k, i, arr) => arr.indexOf(k) === i && outfit.sprites[k] === undefined);

  return (
    <div className={`outfit-card ${outfit.default ? 'default' : ''}`}>
      <div className="outfit-row">
        <div className="sprite-thumb" onClick={uploadThumbnail} title="Загрузить thumbnail">
          {thumbUrl ? <img src={thumbUrl} alt={outfit.name} /> : <Image size={14} />}
        </div>
        <input value={outfit.id} onChange={(e) => update({ id: e.target.value })} placeholder="id" className="sprite-id-input" />
        <input value={outfit.name} onChange={(e) => update({ name: e.target.value })} placeholder="Название" className="sprite-label-input" />
        <button onClick={remove} className="delete"><Trash2 size={10} /></button>
      </div>
      <div className="outfit-row outfit-props">
        <label className="hidden-toggle" title="Дефолтный: экипирован и доступен сразу">
          <input type="checkbox" checked={!!outfit.default} onChange={(e) => setDefault(e.target.checked)} />
          default
        </label>
        <label className="outfit-price-label" title="Цена в алмазах (пусто = бесплатный)">
          💎
          <input
            type="number"
            value={outfit.priceDiamonds ?? ''}
            onChange={(e) => {
              const v = e.target.value;
              update({ priceDiamonds: v === '' ? undefined : Math.max(0, parseInt(v) || 0) });
            }}
            placeholder="—"
            min={0}
            className="outfit-price-input"
          />
        </label>
      </div>
      <div className="outfit-sprites">
        <span className="outfit-sprites-label">Спрайты аутфита (ключ → картинка)</span>
        {Object.entries(outfit.sprites).map(([key, path]) => {
          const url = path ? assetUrls.get(path) : undefined;
          return (
            <div key={key} className="outfit-sprite-row">
              <div className="sprite-thumb" onClick={() => uploadOutfitSprite(key)} title={path ? `${path} — кликните, чтобы заменить` : 'Загрузить картинку'}>
                {url ? <img src={url} alt={key} /> : <Image size={12} />}
              </div>
              <span className="outfit-sprite-key" title={path || 'файл не задан'}>{key}</span>
              {!path && <span className="outfit-sprite-missing">нет файла</span>}
              <button onClick={() => removeSpriteKey(key)} className="delete"><Trash2 size={10} /></button>
            </div>
          );
        })}
        <div className="outfit-sprite-add">
          <input
            value={newKey}
            onChange={(e) => setNewKey(e.target.value)}
            placeholder="ключ (default, happy…)"
            list={`outfit-keys-${char.id}-${outfit.id}`}
            onKeyDown={(e) => e.key === 'Enter' && addSpriteKey(newKey)}
          />
          <datalist id={`outfit-keys-${char.id}-${outfit.id}`}>
            {suggestedKeys.map((k) => <option key={k} value={k} />)}
          </datalist>
          <button className="add-btn small" onClick={() => addSpriteKey(newKey)} title="Добавить ключ"><Plus size={12} /></button>
        </div>
      </div>
    </div>
  );
}

function ChaptersTab() {
  const { project, selectedChapterIndex, selectChapter, addChapter, updateChapter, removeChapter, addScene, selectScene, selectedSceneId, duplicateScene } = useEditorStore();

  const handleAddScene = () => {
    const chapter = project.chapters[selectedChapterIndex];
    // Уникальный id среди ВСЕХ глав (после удаления средней сцены length+1
    // коллизировал; updateScene правит сцены по id глобально).
    const sceneId = uniqueSceneId(chapter.id, allSceneIds(project.chapters));
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
            <input
              className="chapter-title-input"
              value={ch.title}
              onClick={(e) => e.stopPropagation()}
              onFocus={() => selectChapter(i)}
              onChange={(e) => updateChapter(i, { title: e.target.value })}
              placeholder="Название главы"
            />
            <span className="scene-count">{ch.scenes.length} сцен</span>
            {project.chapters.length > 1 && (
              <button onClick={(e) => { e.stopPropagation(); removeChapter(i); }} className="delete"><Trash2 size={12} /></button>
            )}
          </div>
          {i === selectedChapterIndex && (
            <div className="scenes-list">
              <label className="chapter-field-label">Рекап «Ранее…» (v2, показывается перед главой)</label>
              <textarea
                className="chapter-recap-input"
                value={ch.recap || ''}
                onChange={(e) => updateChapter(i, { recap: e.target.value || undefined })}
                placeholder="Ранее: вы познакомились с Мией на вечеринке…"
                rows={2}
              />
              <label className="chapter-field-label">Начальная сцена</label>
              <SceneSelect
                value={ch.firstSceneId}
                onChange={(v) => updateChapter(i, { firstSceneId: v })}
                placeholder="Начальная сцена…"
                allowCreate={false}
              />
              {ch.scenes.map((s) => (
                <div
                  key={s.id}
                  className={`scene-item ${s.id === selectedSceneId ? 'selected' : ''}`}
                  onClick={() => selectScene(s.id)}
                >
                  <span>{s.id}{s.ending ? ' 🏁' : ''}</span>
                  <span className="event-count">{s.events.length} соб.</span>
                  <button
                    className="scene-item-action"
                    title="Дублировать сцену"
                    onClick={(e) => { e.stopPropagation(); duplicateScene(s.id); }}
                  >
                    ⧉
                  </button>
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

const AUDIO_SECTIONS: { dir: string; title: string; hint: string }[] = [
  { dir: 'music/', title: 'Музыка', hint: 'Фоновые треки сцен (scene.music)' },
  { dir: 'sounds/', title: 'Звуки', hint: 'SFX для события playSound' },
  { dir: 'voice/', title: 'Озвучка', hint: 'Реплики dialogue/narration (voice)' },
];

/** Аудио-менеджер: загрузка mp3/ogg/wav в music/, sounds/, voice/;
 *  превью-прослушивание; файлы уходят в ZIP и сохраняются в IndexedDB. */
function AudioTab() {
  const assets = useEditorStore((s) => s.assets);
  const assetUrls = useEditorStore((s) => s.assetUrls);
  const addAsset = useEditorStore((s) => s.addAsset);
  const removeAsset = useEditorStore((s) => s.removeAsset);
  const [playingPath, setPlayingPath] = useState<string | null>(null);
  const [audioEl, setAudioEl] = useState<HTMLAudioElement | null>(null);

  // Пауза при смене трека/уходе со вкладки — превью не должно играть фоном
  useEffect(() => () => { audioEl?.pause(); }, [audioEl]);

  const stop = () => {
    audioEl?.pause();
    setAudioEl(null);
    setPlayingPath(null);
  };

  const togglePlay = (path: string) => {
    if (playingPath === path) {
      stop();
      return;
    }
    const url = assetUrls.get(path);
    if (!url) return;
    audioEl?.pause();
    const audio = new Audio(url);
    audio.onended = () => { setPlayingPath(null); setAudioEl(null); };
    void audio.play();
    setAudioEl(audio);
    setPlayingPath(path);
  };

  const handleUpload = (dir: string) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'audio/*,.mp3,.ogg,.wav,.m4a';
    input.multiple = true;
    input.onchange = (e) => {
      const files = (e.target as HTMLInputElement).files;
      if (!files) return;
      for (const file of Array.from(files)) {
        const name = file.name.replace(/\s+/g, '_').toLowerCase();
        addAsset(`${dir}${name}`, file);
      }
    };
    input.click();
  };

  return (
    <div className="tab-content">
      <h3>Аудио</h3>
      {AUDIO_SECTIONS.map(({ dir, title, hint }) => {
        const files: string[] = [];
        assets.forEach((_, path) => { if (path.startsWith(dir)) files.push(path); });
        files.sort();
        return (
          <div key={dir} className="audio-section">
            <div className="audio-section-header" title={hint}>
              <span className="audio-section-title">{title} <span className="audio-dir">({dir})</span></span>
              <button className="add-btn small" onClick={() => handleUpload(dir)} title={`Загрузить в ${dir}`}>
                <Upload size={12} />
              </button>
            </div>
            {files.length === 0 && <div className="audio-empty">Нет файлов</div>}
            {files.map((path) => (
              <div key={path} className="audio-item">
                <button className="audio-play-btn" onClick={() => togglePlay(path)} title="Прослушать">
                  {playingPath === path ? <Pause size={12} /> : <Play size={12} />}
                </button>
                <span className="audio-name" title={path}>{path.slice(dir.length)}</span>
                <span className="audio-size">{formatSize(assets.get(path)?.size || 0)}</span>
                <button
                  className="delete"
                  onClick={() => { if (playingPath === path) stop(); removeAsset(path); }}
                  title="Удалить"
                >
                  <Trash2 size={12} />
                </button>
              </div>
            ))}
          </div>
        );
      })}
    </div>
  );
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} Б`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} КБ`;
  return `${(bytes / 1024 / 1024).toFixed(1)} МБ`;
}

/** Поиск по текстам: диалоги/нарратив/варианты — переход к сцене и событию. */
function SearchTab() {
  const project = useEditorStore((s) => s.project);
  const [query, setQuery] = useState('');

  interface Match {
    chapterId: string;
    chapterTitle: string;
    sceneId: string;
    eventIndex: number;
    kind: string;
    text: string;
  }

  const matches: Match[] = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    const out: Match[] = [];
    for (const ch of project.chapters) {
      for (const sc of ch.scenes) {
        sc.events.forEach((ev, ei) => {
          if ((ev.type === 'dialogue' || ev.type === 'narration') && ev.text?.toLowerCase().includes(q)) {
            out.push({ chapterId: ch.id, chapterTitle: ch.title, sceneId: sc.id, eventIndex: ei, kind: ev.type === 'dialogue' ? '💬' : '📖', text: ev.text });
          }
          for (const c of ev.choices || []) {
            if (c.text.toLowerCase().includes(q)) {
              out.push({ chapterId: ch.id, chapterTitle: ch.title, sceneId: sc.id, eventIndex: ei, kind: '🔀', text: c.text });
            }
          }
        });
        if (sc.ending && (sc.ending.title.toLowerCase().includes(q) || sc.ending.description?.toLowerCase().includes(q))) {
          out.push({ chapterId: ch.id, chapterTitle: ch.title, sceneId: sc.id, eventIndex: -1, kind: '🏁', text: sc.ending.title || sc.ending.description || '' });
        }
        if (out.length >= 200) return out;
      }
    }
    return out;
  }, [project, query]);

  const highlight = (text: string) => {
    const q = query.trim();
    const idx = text.toLowerCase().indexOf(q.toLowerCase());
    if (idx === -1) return text.length > 70 ? text.slice(0, 70) + '…' : text;
    const start = Math.max(0, idx - 20);
    const snippet = (start > 0 ? '…' : '') + text.slice(start, idx) ;
    const after = text.slice(idx + q.length, idx + q.length + 40) + (idx + q.length + 40 < text.length ? '…' : '');
    return (
      <>
        {snippet}
        <mark>{text.slice(idx, idx + q.length)}</mark>
        {after}
      </>
    );
  };

  return (
    <div className="tab-content">
      <h3>Поиск</h3>
      <input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Поиск по текстам (мин. 2 символа)…"
        autoFocus
      />
      {query.trim().length >= 2 && (
        <div className="search-summary">{matches.length} совпадений{matches.length >= 200 ? ' (показаны первые 200)' : ''}</div>
      )}
      <div className="search-results">
        {matches.map((m, i) => (
          <button
            key={i}
            className="search-result"
            onClick={() => navigateTo(m.chapterId, m.sceneId, m.eventIndex >= 0 ? m.eventIndex : undefined)}
            title={`${m.chapterTitle} · ${m.sceneId} · событие #${m.eventIndex + 1}`}
          >
            <span className="search-result-loc">{m.kind} {m.sceneId} #{m.eventIndex >= 0 ? m.eventIndex + 1 : '—'}</span>
            <span className="search-result-text">{highlight(m.text)}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function ValidateTab() {
  const errors = useEditorStore((s) => s.validationErrors);
  const hasHydrated = useEditorStore((s) => s.hasHydrated);

  const errorCount = errors.filter((e) => e.type === 'error').length;
  const warnCount = errors.filter((e) => e.type === 'warning').length;

  const handleClick = (err: ValidationError) => {
    if (!err.sceneId && !err.chapterId) return;
    navigateTo(err.chapterId, err.sceneId, err.eventIndex);
  };

  return (
    <div className="tab-content">
      <h3>Валидация</h3>
      <div className="hint validation-live-hint">
        Проверка выполняется автоматически при изменениях (включая ассеты и аудио).
      </div>

      {hasHydrated && errors.length === 0 && (
        <div className="validation-ok">
          <CheckCircle size={20} />
          <span>Всё в порядке!</span>
        </div>
      )}

      {errors.length > 0 && (
        <>
          <div className="validation-summary">
            {errorCount > 0 && <span className="error-count">❌ {errorCount} ошибок</span>}
            {warnCount > 0 && <span className="warn-count">⚠️ {warnCount} предупреждений</span>}
          </div>
          <div className="validation-list">
            {errors.map((err, i) => (
              <div
                key={i}
                className={`validation-item ${err.type} ${(err.sceneId || err.chapterId) ? 'clickable' : ''}`}
                onClick={() => handleClick(err)}
                title={err.sceneId ? 'Перейти к сцене' : err.chapterId ? 'Перейти к главе' : undefined}
                role={err.sceneId || err.chapterId ? 'button' : undefined}
              >
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
    remapTranslationKey,
    updateTranslationMeta,
    updateTranslationCharacter,
    updateTranslationChapter,
    selectTranslationLang,
  } = useEditorStore();

  const translations = project.translations || {};
  const sourceLang = project.meta.sourceLanguage || 'ru';
  const selectedLang = selectedTranslationLang;
  const [staleTargets, setStaleTargets] = useState<Record<string, string>>({});

  // Собрать все переводимые строки (v2: + recap, концовки, промпт имени,
  // названия аутфитов, statsDisplay.label)
  const allTexts = useMemo(() => collectTranslatableStrings(project), [project]);

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
  const translatedCount = currentTranslation
    ? allTexts.filter((t) => currentTranslation.texts[t] && currentTranslation.texts[t].trim()).length
    : 0;

  const stale = currentTranslation ? findStaleTranslations(project, currentTranslation.texts) : [];
  const untranslated = currentTranslation
    ? allTexts.filter((t) => !currentTranslation.texts[t] || !currentTranslation.texts[t].trim())
    : [];

  const handleExportLang = () => {
    if (!selectedLang || !currentTranslation) return;
    exportTranslationFile(selectedLang, {
      ...currentTranslation,
      meta: {
        language: selectedLang,
        sourceLanguage: sourceLang,
        novelId: project.meta.id,
        version: currentTranslation.meta?.version || 1,
      },
    });
  };

  const handleImportLang = () => {
    if (!selectedLang) return;
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      try {
        const imported = await importTranslationFile(file);
        setTranslation(selectedLang, {
          novel: imported.novel || {},
          characters: imported.characters || {},
          chapters: imported.chapters || {},
          texts: imported.texts || {},
          meta: {
            language: selectedLang,
            sourceLanguage: sourceLang,
            novelId: project.meta.id,
            version: (imported.meta?.version || 0) + 1,
          },
        });
      } catch (err) {
        alert('Ошибка импорта перевода: ' + (err as Error).message);
      }
    };
    input.click();
  };

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

          <div className="translation-file-actions">
            <button onClick={handleExportLang} title={`Скачать translations/${selectedLang}.json`}>
              <FileDown size={12} /> Скачать {selectedLang}.json
            </button>
            <button onClick={handleImportLang} title="Загрузить файл перевода (заменит текущий язык)">
              <FileUp size={12} /> Загрузить
            </button>
          </div>

          {/* Устаревшие переводы (оригинал изменился) */}
          {stale.length > 0 && (
            <div className="stale-translations">
              <div className="stale-header" title="Оригинальный текст был изменён или удалён — перевод потерял ключ (ключ = исходная строка)">
                ⚠️ Устаревшие переводы ({stale.length})
              </div>
              {stale.map((entry) => (
                <div key={entry.original} className="stale-item">
                  <div className="stale-original" title="Бывший оригинал">{entry.original}</div>
                  <div className="stale-translated" title="Сохранённый перевод">→ {entry.translated}</div>
                  <div className="stale-actions">
                    <select
                      value={staleTargets[entry.original] || ''}
                      onChange={(e) => setStaleTargets((prev) => ({ ...prev, [entry.original]: e.target.value }))}
                    >
                      <option value="">— выбрать новый текст —</option>
                      {untranslated.map((t) => (
                        <option key={t} value={t}>{t.length > 60 ? t.slice(0, 60) + '…' : t}</option>
                      ))}
                    </select>
                    <button
                      className="stale-remap-btn"
                      disabled={!staleTargets[entry.original]}
                      onClick={() => {
                        const target = staleTargets[entry.original];
                        if (!target) return;
                        remapTranslationKey(selectedLang, entry.original, target);
                        setStaleTargets((prev) => {
                          const next = { ...prev };
                          delete next[entry.original];
                          return next;
                        });
                      }}
                      title="Перенести перевод на выбранную строку"
                    >
                      Перенести
                    </button>
                    <button
                      className="delete"
                      onClick={() => updateTranslationText(selectedLang, entry.original, '')}
                      title="Удалить устаревший перевод"
                    >
                      <Trash2 size={12} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

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

/** Публикация на сервер: логин админа + загрузка ZIP (создание/перезаливка)
 *  + отправка отдельной главы (формат v2 2.4, 2.7). */
function PublishTab() {
  const project = useEditorStore((s) => s.project);
  const assets = useEditorStore((s) => s.assets);
  const [settings, setSettings] = useState<PublishSettings>(() => loadPublishSettings());
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState<string | null>(null);
  const [result, setResult] = useState<{ ok: boolean; message: string } | null>(null);
  const [chapterNumber, setChapterNumber] = useState<number>(project.chapters[0]?.number ?? 1);

  const loggedIn = !!settings.token;

  const persist = (next: PublishSettings) => {
    setSettings(next);
    savePublishSettings(next);
  };

  const handleLogin = async () => {
    setResult(null);
    setBusy('login');
    try {
      const res = await apiLogin(settings.baseUrl, settings.email, password);
      persist({ ...settings, token: res.token, refreshToken: res.refreshToken });
      setPassword('');
      setResult({ ok: true, message: 'Вход выполнен' });
    } catch (err) {
      setResult({ ok: false, message: err instanceof PublishError ? err.message : String(err) });
    } finally {
      setBusy(null);
    }
  };

  const handleLogout = () => {
    persist({ ...settings, token: null, refreshToken: null });
    setResult(null);
  };

  /** Общий сценарий заливки ZIP; expectExisting: true = «обновить», false = «новая». */
  const handleUploadZip = async (expectExisting: boolean) => {
    setResult(null);
    const blocking = blockingErrors(project);
    if (blocking.length > 0) {
      setResult({ ok: false, message: `Публикация заблокирована — ${blocking.length} ошибок валидации. Откройте вкладку «Валидация».` });
      return;
    }
    setBusy(expectExisting ? 'update' : 'create');
    try {
      const exists = await novelExists(settings.baseUrl, project.meta.id);
      if (!expectExisting && exists) {
        if (!confirm(`Новелла "${project.meta.id}" уже есть на сервере. Перезалить (обновить)?`)) {
          setBusy(null);
          return;
        }
      }
      if (expectExisting && !exists) {
        if (!confirm(`Новеллы "${project.meta.id}" на сервере нет. Опубликовать как новую?`)) {
          setBusy(null);
          return;
        }
      }
      const zip = await buildZipBlob(project, assets);
      const res = await uploadNovelZip(settings, zip, project.meta.id);
      setSettings(res.settings);
      setResult({ ok: true, message: `${res.message} (${project.meta.id}, ${formatSize(zip.size)})` });
    } catch (err) {
      const msg = err instanceof PublishError ? err.message : String(err);
      setResult({ ok: false, message: msg });
      if (err instanceof PublishError && err.status === 401) {
        persist({ ...settings, token: null, refreshToken: null });
      }
    } finally {
      setBusy(null);
    }
  };

  const handleUploadChapter = async () => {
    setResult(null);
    const chapter = project.chapters.find((c) => c.number === chapterNumber);
    if (!chapter) {
      setResult({ ok: false, message: `Глава №${chapterNumber} не найдена в проекте` });
      return;
    }
    const blocking = blockingErrors(project);
    if (blocking.length > 0) {
      setResult({ ok: false, message: `Отправка заблокирована — ${blocking.length} ошибок валидации. Откройте вкладку «Валидация».` });
      return;
    }
    setBusy('chapter');
    try {
      const res = await uploadChapter(settings, project.meta.id, chapter);
      setSettings(res.settings);
      setResult({ ok: true, message: res.message });
    } catch (err) {
      const msg = err instanceof PublishError ? err.message : String(err);
      setResult({ ok: false, message: msg });
      if (err instanceof PublishError && err.status === 401) {
        persist({ ...settings, token: null, refreshToken: null });
      }
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="tab-content">
      <h3>Публикация</h3>

      <label>Base URL сервера</label>
      <input
        value={settings.baseUrl}
        onChange={(e) => persist({ ...settings, baseUrl: e.target.value })}
        placeholder={DEFAULT_BASE_URL}
      />

      {!loggedIn ? (
        <>
          <label>Email администратора</label>
          <input
            value={settings.email}
            onChange={(e) => persist({ ...settings, email: e.target.value })}
            placeholder="admin@example.com"
            autoComplete="username"
          />
          <label>Пароль</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
            autoComplete="current-password"
            onKeyDown={(e) => e.key === 'Enter' && !busy && settings.email && password && handleLogin()}
          />
          <button
            className="primary publish-btn"
            onClick={handleLogin}
            disabled={busy !== null || !settings.email.trim() || !password}
          >
            <LogIn size={14} /> {busy === 'login' ? 'Входим…' : 'Войти'}
          </button>
        </>
      ) : (
        <div className="publish-session">
          <span className="publish-session-user" title="Активная сессия администратора">✔ {settings.email}</span>
          <button onClick={handleLogout} className="publish-logout" title="Выйти"><LogOut size={12} /></button>
        </div>
      )}

      {loggedIn && (
        <>
          <div className="publish-novel-info">
            Новелла: <b>{project.meta.id}</b> · глав: {project.chapters.length} · ассетов: {assets.size}
          </div>

          <div className="publish-actions">
            <button
              className="primary publish-btn"
              onClick={() => handleUploadZip(false)}
              disabled={busy !== null}
              title="Собрать ZIP и загрузить на сервер как новую новеллу (POST /novels/upload)"
            >
              <CloudUpload size={14} /> {busy === 'create' ? 'Загружаем…' : 'Опубликовать новую'}
            </button>
            <button
              className="publish-btn"
              onClick={() => handleUploadZip(true)}
              disabled={busy !== null}
              title="Перезалить ZIP существующей новеллы (isReleased глав сохраняется на сервере)"
            >
              <Upload size={14} /> {busy === 'update' ? 'Загружаем…' : 'Обновить существующую'}
            </button>
            <div className="publish-chapter-row">
              <select
                value={chapterNumber}
                onChange={(e) => setChapterNumber(parseInt(e.target.value))}
              >
                {project.chapters.map((ch) => (
                  <option key={ch.id} value={ch.number}>Глава {ch.number}: {ch.title}</option>
                ))}
              </select>
              <button
                className="publish-btn"
                onClick={handleUploadChapter}
                disabled={busy !== null}
                title="Отправить JSON одной главы (POST /admin/novels/:id/chapters) — без перезаливки всего архива"
              >
                <Send size={14} /> {busy === 'chapter' ? '…' : 'Отправить'}
              </button>
            </div>
          </div>
        </>
      )}

      {result && (
        <div className={`publish-result ${result.ok ? 'ok' : 'error'}`}>
          {result.message}
        </div>
      )}

      <div className="hint publish-hint">
        Загрузка ZIP создаёт новеллу или обновляет существующую по id из меты.
        Отправка главы обновляет только chapters/chapter_N.json (статус релиза
        главы сохраняется). Новые главы появляются со статусом «не выпущена» —
        релиз управляется из админки.
      </div>
    </div>
  );
}
