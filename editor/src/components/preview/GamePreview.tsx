import { useState, useEffect, useCallback, useRef } from 'react';
import { useEditorStore } from '../../store/editorStore';
import type { Character, Choice, SceneEnding } from '../../types/novel';
import { applyEffects, interpolate, isChoiceVisible, pickBranch, type Vars } from '../../utils/conditions';
import './GamePreview.css';

type Phase = 'start' | 'recap' | 'playing' | 'ending' | 'chapterEnd';

interface GameState {
  phase: Phase;
  sceneId: string;
  eventIndex: number;
  variables: Vars;
  background: string | undefined;
  charactersOnScreen: { characterId: string; spriteId: string; position: string }[];
  camera: { zoom: number; panX: number; panY: number };
  cgOverlay: string | null;
  ending: SceneEnding | null;
}

const idleCamera = { zoom: 1, panX: 0, panY: 0 };

export function GamePreview() {
  const { project, selectedChapterIndex, assetUrls } = useEditorStore();
  const chapter = project.chapters[selectedChapterIndex];

  const [gameState, setGameState] = useState<GameState>({
    phase: 'start',
    sceneId: chapter?.firstSceneId || '',
    eventIndex: 0,
    variables: { ...project.variables },
    background: undefined,
    charactersOnScreen: [],
    camera: idleCamera,
    cgOverlay: null,
    ending: null,
  });

  const [displayedText, setDisplayedText] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [showChoices, setShowChoices] = useState(false);
  const [testName, setTestName] = useState('');
  const typingRef = useRef<number | null>(null);

  // ── Аудио (object URLs из assetUrls) ──
  const bgAudioRef = useRef<{ audio: HTMLAudioElement; track: string } | null>(null);
  const voiceAudioRef = useRef<HTMLAudioElement | null>(null);

  const stopVoice = useCallback(() => {
    voiceAudioRef.current?.pause();
    voiceAudioRef.current = null;
  }, []);

  const stopAllAudio = useCallback(() => {
    bgAudioRef.current?.audio.pause();
    bgAudioRef.current = null;
    stopVoice();
  }, [stopVoice]);

  // Останавливаем всё при размонтировании превью
  useEffect(() => stopAllAudio, [stopAllAudio]);

  const playMusic = useCallback((track: string | undefined) => {
    if (!track) return; // музыка сцены не задана — прежний трек продолжает играть
    if (bgAudioRef.current?.track === track) return;
    const url = assetUrls.get(track);
    bgAudioRef.current?.audio.pause();
    bgAudioRef.current = null;
    if (!url) return;
    const audio = new Audio(url);
    audio.loop = true;
    audio.volume = 0.7;
    void audio.play().catch(() => {});
    bgAudioRef.current = { audio, track };
  }, [assetUrls]);

  const playSfx = useCallback((path: string | undefined) => {
    if (!path) return;
    const url = assetUrls.get(path);
    if (!url) return;
    const audio = new Audio(url);
    void audio.play().catch(() => {});
  }, [assetUrls]);

  const playVoice = useCallback((path: string | undefined) => {
    stopVoice();
    if (!path) return;
    const url = assetUrls.get(path);
    if (!url) return;
    const audio = new Audio(url);
    voiceAudioRef.current = audio;
    void audio.play().catch(() => {});
  }, [assetUrls, stopVoice]);

  const currentScene = chapter?.scenes.find(s => s.id === gameState.sceneId);
  const currentEvent = gameState.phase === 'playing' ? currentScene?.events[gameState.eventIndex] : undefined;

  const beginScene = useCallback((sceneId: string) => {
    const scene = chapter?.scenes.find(s => s.id === sceneId);
    if (!scene) {
      setGameState(prev => ({ ...prev, phase: 'chapterEnd' }));
      return;
    }
    playMusic(scene.music);
    setGameState(prev => ({
      ...prev,
      phase: 'playing',
      sceneId,
      eventIndex: 0,
      background: scene.background || prev.background,
      charactersOnScreen: scene.charactersOnScreen.length > 0 ? scene.charactersOnScreen : prev.charactersOnScreen,
      camera: idleCamera,
      cgOverlay: null,
    }));
  }, [chapter, playMusic]);

  const startPlaying = useCallback(() => {
    stopAllAudio();
    const first = chapter?.firstSceneId || '';
    setGameState({
      phase: chapter?.recap?.trim() ? 'recap' : 'playing',
      sceneId: first,
      eventIndex: 0,
      variables: { ...project.variables },
      background: undefined,
      charactersOnScreen: [],
      camera: idleCamera,
      cgOverlay: null,
      ending: null,
    });
    if (!chapter?.recap?.trim()) {
      // beginScene выставит фон/персонажей/музыку по первой сцене
      const scene = chapter?.scenes.find(s => s.id === first);
      if (scene) {
        playMusic(scene.music);
        setGameState(prev => ({
          ...prev,
          phase: 'playing',
          background: scene.background,
          charactersOnScreen: scene.charactersOnScreen,
        }));
      } else {
        setGameState(prev => ({ ...prev, phase: 'chapterEnd' }));
      }
    }
  }, [chapter, project.variables, playMusic, stopAllAudio]);

  /** Конец сцены (формат v2): ending → branches → nextSceneId → конец главы. */
  const finishScene = useCallback(() => {
    if (!currentScene) return;
    stopVoice();
    if (currentScene.ending) {
      setGameState(prev => ({ ...prev, phase: 'ending', ending: currentScene.ending! }));
      return;
    }
    const branch = pickBranch(gameState.variables, currentScene.branches);
    if (branch && branch.nextSceneId) {
      beginScene(branch.nextSceneId);
      return;
    }
    if (currentScene.nextSceneId) {
      beginScene(currentScene.nextSceneId);
      return;
    }
    setGameState(prev => ({ ...prev, phase: 'chapterEnd' }));
  }, [currentScene, gameState.variables, beginScene, stopVoice]);

  const advanceEvent = useCallback(() => {
    if (!currentScene) return;
    stopVoice();
    const nextIndex = gameState.eventIndex + 1;
    if (nextIndex < currentScene.events.length) {
      setGameState(prev => ({ ...prev, eventIndex: nextIndex, cgOverlay: null }));
    } else {
      finishScene();
    }
  }, [currentScene, gameState.eventIndex, finishScene, stopVoice]);

  // Обработка текущего события
  useEffect(() => {
    if (gameState.phase !== 'playing' || !currentEvent) return;

    const rawText = currentEvent.text || '';
    if ((currentEvent.type === 'dialogue' || currentEvent.type === 'narration') && rawText) {
      const text = interpolate(rawText, gameState.variables, project.meta, testName);
      setIsTyping(true);
      setDisplayedText('');
      setShowChoices(false);
      playVoice(currentEvent.voice);
      let i = 0;
      const interval = setInterval(() => {
        i++;
        setDisplayedText(text.slice(0, i));
        if (i >= text.length) {
          clearInterval(interval);
          setIsTyping(false);
        }
      }, 30);
      typingRef.current = interval as unknown as number;
      return () => clearInterval(interval);
    } else if (currentEvent.type === 'choice') {
      setShowChoices(true);
      setDisplayedText('');
    } else {
      // Невизуальные и «самопроигрывающиеся» события
      let delay = 100;
      if (currentEvent.type === 'setVariable' && currentEvent.variable) {
        setGameState(prev => ({
          ...prev,
          variables: applyEffects(prev.variables, { [currentEvent.variable!]: currentEvent.value ?? '' }),
        }));
      } else if (currentEvent.type === 'changeBackground') {
        setGameState(prev => ({ ...prev, background: currentEvent.asset }));
      } else if (currentEvent.type === 'changeSprite') {
        setGameState(prev => ({
          ...prev,
          charactersOnScreen: prev.charactersOnScreen.map(c =>
            c.characterId === currentEvent.characterId ? { ...c, spriteId: currentEvent.spriteId || c.spriteId } : c
          ),
        }));
      } else if (currentEvent.type === 'playSound') {
        playSfx(currentEvent.asset);
      } else if (currentEvent.type === 'effect') {
        delay = Math.min(currentEvent.effectDuration ?? 500, 1500);
      } else if (currentEvent.type === 'showEmotion') {
        delay = 900;
      } else if (currentEvent.type === 'cameraMove') {
        setGameState(prev => ({
          ...prev,
          camera: {
            zoom: currentEvent.zoom ?? 1,
            panX: currentEvent.panX ?? 0,
            panY: currentEvent.panY ?? 0,
          },
        }));
        delay = Math.min(currentEvent.cameraDuration ?? 1000, 1200);
      } else if (currentEvent.type === 'showCg') {
        // CG ждёт клика — advance произойдёт в handleClick
        setGameState(prev => ({ ...prev, cgOverlay: currentEvent.cgImage || null }));
        return;
      }
      const timeout = setTimeout(() => advanceEvent(), delay);
      return () => clearTimeout(timeout);
    }
  }, [gameState.sceneId, gameState.eventIndex, gameState.phase]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleClick = () => {
    if (gameState.phase !== 'playing') return;
    if (gameState.cgOverlay !== null) {
      setGameState(prev => ({ ...prev, cgOverlay: null }));
      advanceEvent();
      return;
    }
    if (isTyping) {
      if (typingRef.current) clearInterval(typingRef.current);
      const raw = currentEvent?.text || '';
      setDisplayedText(interpolate(raw, gameState.variables, project.meta, testName));
      setIsTyping(false);
      return;
    }
    if (showChoices) return;
    advanceEvent();
  };

  const handleChoice = (choice: Choice) => {
    // Применяем эффекты как движок (variable_engine.dart): "+N"/"-N" —
    // инкремент/декремент, "toggle" — инверсия bool, иначе — присвоение.
    setGameState(prev => ({
      ...prev,
      variables: applyEffects(prev.variables, choice.effects),
    }));
    setShowChoices(false);
    if (choice.nextSceneId) {
      beginScene(choice.nextSceneId);
    } else {
      advanceEvent();
    }
  };

  const stop = () => {
    stopAllAudio();
    setGameState(prev => ({ ...prev, phase: 'start', cgOverlay: null }));
  };

  // ── Рендер ──

  const scene = currentScene;
  const layers = (scene?.backgroundLayers || []).slice().sort((a, b) => a.depth - b.depth);
  const hasLayers = gameState.phase === 'playing' && layers.length > 0;

  const bgImageUrl = gameState.background ? assetUrls.get(`backgrounds/${gameState.background}`) : undefined;
  const bgStyle: React.CSSProperties = hasLayers
    ? { background: '#000' }
    : bgImageUrl
      ? { backgroundImage: `url(${bgImageUrl})`, backgroundSize: 'cover', backgroundPosition: 'center' }
      : { background: getGradient(gameState.background) };

  const debugPanel = (
    <div className="gp-debug">
      <div className="gp-testname-row">
        <label title="Подставляется в {name}, если переменная player_name не задана">Имя ({'{name}'})</label>
        <input
          value={testName}
          onChange={(e) => setTestName(e.target.value)}
          placeholder={project.meta.playerNamePrompt?.defaultName || 'Ты'}
        />
      </div>
      {(project.meta.statsDisplay?.length || 0) > 0 && (
        <div className="gp-stats">
          {project.meta.statsDisplay!.map((stat) => {
            const raw = gameState.variables[stat.variable];
            const value = typeof raw === 'number' ? raw : Number(raw) || 0;
            const max = stat.max && stat.max > 0 ? stat.max : 100;
            const pct = Math.max(0, Math.min(100, (value / max) * 100));
            return (
              <div key={stat.variable} className="gp-stat">
                <span className="gp-stat-label">
                  <span className="gp-stat-icon" style={{ color: stat.color || '#e91e63' }}>{statIcon(stat.icon)}</span>
                  {stat.label || stat.variable}
                </span>
                <div className="gp-stat-bar">
                  <div className="gp-stat-fill" style={{ width: `${pct}%`, background: stat.color || '#e91e63' }} />
                </div>
                <span className="gp-stat-value">{value}/{max}</span>
              </div>
            );
          })}
        </div>
      )}
      <details>
        <summary>Переменные ({Object.keys(gameState.variables).length})</summary>
        <div className="gp-vars">
          {Object.entries(gameState.variables).map(([k, v]) => (
            <div key={k} className="gp-var">{k}: <strong>{String(v)}</strong></div>
          ))}
        </div>
      </details>
    </div>
  );

  // Start screen
  if (gameState.phase === 'start') {
    return (
      <div className="game-preview">
        <div className="phone-frame">
          <div className="phone-screen start-screen">
            <div className="start-content">
              <div className="start-icon">▶</div>
              <h3>{chapter?.title || 'Глава'}</h3>
              <p>Интерактивный предпросмотр</p>
              <button className="play-btn" onClick={startPlaying}>Играть</button>
            </div>
          </div>
        </div>
        {debugPanel}
      </div>
    );
  }

  // Recap screen (v2 1.8)
  if (gameState.phase === 'recap') {
    return (
      <div className="game-preview">
        <div className="phone-frame">
          <div className="phone-screen start-screen">
            <div className="start-content gp-recap">
              <h3>Ранее…</h3>
              <p className="gp-recap-text">{interpolate(chapter?.recap || '', gameState.variables, project.meta, testName)}</p>
              <button className="play-btn" onClick={() => beginScene(chapter?.firstSceneId || '')}>Продолжить</button>
            </div>
          </div>
        </div>
        {debugPanel}
      </div>
    );
  }

  // Ending screen (v2 1.3)
  if (gameState.phase === 'ending' && gameState.ending) {
    const ending = gameState.ending;
    const endingImgUrl = ending.image ? assetUrls.get(ending.image) : undefined;
    return (
      <div className="game-preview">
        <div className="phone-frame">
          <div className="phone-screen gp-ending-screen">
            {endingImgUrl && <img src={endingImgUrl} alt={ending.title} className="gp-ending-image" />}
            <div className="gp-ending-content">
              <div className="gp-ending-label">Концовка получена</div>
              <h3>{interpolate(ending.title || ending.id, gameState.variables, project.meta, testName)}</h3>
              {ending.description && (
                <p>{interpolate(ending.description, gameState.variables, project.meta, testName)}</p>
              )}
              <button className="play-btn" onClick={stop}>В библиотеку</button>
            </div>
          </div>
        </div>
        {debugPanel}
      </div>
    );
  }

  // End of chapter (no ending)
  if (gameState.phase === 'chapterEnd' || !scene) {
    return (
      <div className="game-preview">
        <div className="phone-frame">
          <div className="phone-screen start-screen">
            <div className="start-content">
              <div className="start-icon">✅</div>
              <h3>Конец главы</h3>
              <p>Все сцены пройдены</p>
              <button className="play-btn" onClick={startPlaying}>Начать сначала</button>
            </div>
          </div>
        </div>
        {debugPanel}
      </div>
    );
  }

  const speakerChar = currentEvent?.speaker
    ? project.characters.find(c => c.id === currentEvent.speaker)
    : null;

  const dialogueTheme = project.meta.dialogueTheme || 'ornate';
  const dialogueStyle = project.meta.dialogueStyle || 'classic';

  // Determine speaker's on-screen position
  const speakerSide = currentEvent?.speaker
    ? gameState.charactersOnScreen.find(sc => sc.characterId === currentEvent.speaker)?.position || 'center'
    : 'center';

  // Custom color CSS vars
  const customStyle = {} as React.CSSProperties & Record<string, string>;
  if (project.meta.dialogueFrameColor) {
    customStyle['--frame-color'] = project.meta.dialogueFrameColor;
  }
  if (project.meta.dialogueBgColor) {
    customStyle['--frame-bg'] = project.meta.dialogueBgColor;
  }

  const cam = gameState.camera;
  const stageStyle: React.CSSProperties = {
    transform: `scale(${cam.zoom}) translate(${-cam.panX * 0.3}px, ${-cam.panY * 0.3}px)`,
    transition: 'transform 0.8s ease',
  };

  const cgUrl = gameState.cgOverlay ? assetUrls.get(gameState.cgOverlay) : undefined;
  const emotionImgUrl = currentEvent?.type === 'showEmotion' && currentEvent.image
    ? assetUrls.get(currentEvent.image)
    : undefined;

  return (
    <div className="game-preview">
      <div className="phone-frame">
        <div className="phone-screen" style={{ ...bgStyle, ...customStyle }} onClick={handleClick}>
          {/* Сцена (фон + слои + персонажи) — двигается камерой */}
          <div className="gp-stage" style={stageStyle}>
            {/* Параллакс-слои (v2 1.10): depth 0 — дальний неподвижный */}
            {hasLayers && layers.map((layer, i) => {
              const url = assetUrls.get(`backgrounds/${layer.image}`);
              const shiftX = (layer.offsetX ?? 0) - cam.panX * layer.depth * 0.4;
              const shiftY = (layer.offsetY ?? 0) - cam.panY * layer.depth * 0.4;
              return url ? (
                <img
                  key={i}
                  src={url}
                  alt=""
                  className="gp-parallax-layer"
                  style={{
                    transform: `translate(${shiftX}px, ${shiftY}px) scale(${1 + layer.depth * 0.06})`,
                    zIndex: i,
                  }}
                />
              ) : null;
            })}

            {/* Characters */}
            <div className="gp-characters">
              {gameState.charactersOnScreen.map(sc => {
                const char = project.characters.find(c => c.id === sc.characterId);
                const spriteUrl = char ? resolveSpriteUrl(char, sc.spriteId, assetUrls) : undefined;
                return (
                  <div key={sc.characterId} className={`gp-character ${sc.position}`}>
                    {spriteUrl ? (
                      <img src={spriteUrl} alt={char?.name} className="gp-sprite" />
                    ) : (
                      <div className="gp-char-placeholder">
                        {char?.name?.[0] || '?'}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Top HUD */}
          <div className="gp-hud">
            <span className="gp-scene-label">
              {scene.id} · Event {gameState.eventIndex + 1}/{scene.events.length}
            </span>
            <button className="gp-stop-btn" onClick={(e) => { e.stopPropagation(); stop(); }}>✕</button>
          </div>

          {/* Dialogue/Narration — themed frame */}
          {currentEvent && (currentEvent.type === 'dialogue' || currentEvent.type === 'narration') && (
            <div className={`gp-frame gp-frame-${dialogueTheme} ${dialogueStyle === 'center' ? 'gp-frame-center' : ''}`}>
              {/* Name tab */}
              <div className={`gp-frame-name gp-name-${dialogueTheme} gp-name-${speakerSide}`}>
                {currentEvent.type === 'dialogue' && speakerChar ? (
                  <span>{speakerChar.name}</span>
                ) : (
                  <span className="gp-narration-dots">· · ·</span>
                )}
              </div>
              {/* Text body */}
              <div className={`gp-frame-body gp-body-${dialogueTheme}${currentEvent.type === 'narration' ? ' gp-narration' : ` gp-tail-${speakerSide}`}`}>
                <div className={`gp-text ${currentEvent.type === 'narration' ? 'narration' : ''}`}>
                  {displayedText}
                  {isTyping && <span className="gp-cursor">|</span>}
                </div>
                {currentEvent.voice && <span className="gp-voice-badge" title={currentEvent.voice}>🎙</span>}
                {!isTyping && <div className="gp-advance-hint">▼</div>}
                {/* Corner ornaments */}
                {dialogueTheme !== 'modern' && dialogueTheme !== 'glassmorphism' && dialogueTheme !== 'noir' && (
                  <>
                    <span className="gp-corner gp-corner-tl" />
                    <span className="gp-corner gp-corner-tr" />
                    <span className="gp-corner gp-corner-bl" />
                    <span className="gp-corner gp-corner-br" />
                  </>
                )}
              </div>
            </div>
          )}

          {/* Choices — themed; составные условия v2 через isChoiceVisible */}
          {showChoices && currentEvent?.choices && (
            <div className={`gp-choices gp-choices-${dialogueTheme}`}>
              {currentEvent.choices.map((choice, i) => {
                if (!isChoiceVisible(gameState.variables, choice)) return null;
                return (
                  <button
                    key={i}
                    className={`gp-choice gp-choice-${dialogueTheme} ${choice.premium ? 'premium' : ''}`}
                    onClick={(e) => { e.stopPropagation(); handleChoice(choice); }}
                  >
                    {choice.premium && <span className="gp-diamond">💎 {choice.cost}</span>}
                    {interpolate(choice.text, gameState.variables, project.meta, testName)}
                    {(choice.unlockOutfits?.length || 0) > 0 && <span className="gp-outfit-hint" title={`Разблокирует: ${choice.unlockOutfits!.join(', ')}`}>👗</span>}
                  </button>
                );
              })}
            </div>
          )}

          {/* CG overlay (клик — продолжить) */}
          {gameState.cgOverlay !== null && (
            <div className="gp-cg-overlay">
              {cgUrl ? (
                <img src={cgUrl} alt="CG" className="gp-cg-image" />
              ) : (
                <div className="gp-cg-missing">🖼️ {gameState.cgOverlay}</div>
              )}
              <div className="gp-cg-hint">нажмите, чтобы продолжить</div>
            </div>
          )}

          {/* Effects overlay */}
          {currentEvent?.type === 'effect' && (
            <div className={`gp-effect gp-effect-${currentEvent.effectType}`} />
          )}

          {/* Emotion: картинка (v2 1.7) или emoji */}
          {currentEvent?.type === 'showEmotion' && (
            <div className="gp-emotion">
              {emotionImgUrl ? (
                <img src={emotionImgUrl} alt={currentEvent.emotionType || 'emotion'} className="gp-emotion-image" />
              ) : (
                getEmotionEmoji(currentEvent.emotionType)
              )}
            </div>
          )}
        </div>
      </div>

      {debugPanel}
    </div>
  );
}

/** Резолв спрайта с учётом дефолтного аутфита (формат v2 1.5):
 *  outfits[default].sprites[ключ] → outfits[default].sprites["default"] →
 *  базовый спрайт персонажа. */
function resolveSpriteUrl(char: Character, spriteId: string, assetUrls: Map<string, string>): string | undefined {
  const equipped = char.outfits?.find((o) => o.default) || undefined;
  if (equipped) {
    const byKey = equipped.sprites?.[spriteId] || equipped.sprites?.['default'];
    if (byKey) {
      const url = assetUrls.get(byKey);
      if (url) return url;
    }
  }
  const base = char.sprites.find((sp) => sp.id === spriteId);
  return base ? assetUrls.get(base.image) : undefined;
}

function statIcon(icon?: string): string {
  const map: Record<string, string> = {
    heart: '♥', star: '★', flame: '🔥', diamond: '💎', moon: '🌙', sun: '☀️', leaf: '🍃',
  };
  return map[icon || ''] || '♥';
}

function getGradient(bg?: string): string {
  switch (bg) {
    case 'city_night.png': return 'linear-gradient(180deg, #0D1B2A, #1B263B, #415A77)';
    case 'cafe_night.png': return 'linear-gradient(180deg, #2D1B1B, #4A2C2A, #6B3A3A)';
    case 'mansion.png': return 'linear-gradient(180deg, #1A0A2E, #2D1854, #4A2D7A)';
    default: return 'linear-gradient(180deg, #0F3460, #1A1A2E)';
  }
}

function getEmotionEmoji(type?: string): string {
  const map: Record<string, string> = {
    heart: '❤️', sweatDrop: '💧', question: '❓', exclamation: '❗',
    anger: '💢', sparkle: '✨', musicNote: '🎵', zzz: '💤',
  };
  return map[type || ''] || '💭';
}
