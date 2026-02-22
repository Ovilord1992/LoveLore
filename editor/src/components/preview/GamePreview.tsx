import { useState, useEffect, useCallback, useRef } from 'react';
import { useEditorStore } from '../../store/editorStore';
import type { SceneEvent, Choice } from '../../types/novel';
import './GamePreview.css';

interface GameState {
  chapterIndex: number;
  sceneId: string;
  eventIndex: number;
  variables: Record<string, string | number | boolean>;
  background: string | undefined;
  charactersOnScreen: { characterId: string; spriteId: string; position: string }[];
  isPlaying: boolean;
}

export function GamePreview() {
  const { project, selectedChapterIndex, imageUrls } = useEditorStore();
  const chapter = project.chapters[selectedChapterIndex];

  const [gameState, setGameState] = useState<GameState>({
    chapterIndex: selectedChapterIndex,
    sceneId: chapter?.firstSceneId || '',
    eventIndex: 0,
    variables: { ...project.variables },
    background: undefined,
    charactersOnScreen: [],
    isPlaying: false,
  });

  const [displayedText, setDisplayedText] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [showChoices, setShowChoices] = useState(false);
  const typingRef = useRef<number | null>(null);

  const currentScene = chapter?.scenes.find(s => s.id === gameState.sceneId);
  const currentEvent = currentScene?.events[gameState.eventIndex];

  const startPlaying = useCallback(() => {
    setGameState({
      chapterIndex: selectedChapterIndex,
      sceneId: chapter?.firstSceneId || '',
      eventIndex: 0,
      variables: { ...project.variables },
      background: undefined,
      charactersOnScreen: [],
      isPlaying: true,
    });
  }, [selectedChapterIndex, chapter, project.variables]);

  const goToScene = useCallback((sceneId?: string) => {
    if (!sceneId) {
      setGameState(prev => ({ ...prev, isPlaying: false }));
      return;
    }
    const scene = chapter?.scenes.find(s => s.id === sceneId);
    if (!scene) {
      setGameState(prev => ({ ...prev, isPlaying: false }));
      return;
    }
    setGameState(prev => ({
      ...prev,
      sceneId,
      eventIndex: 0,
      background: scene.background || prev.background,
      charactersOnScreen: scene.charactersOnScreen.length > 0 ? scene.charactersOnScreen : prev.charactersOnScreen,
    }));
  }, [chapter]);

  const advanceEvent = useCallback(() => {
    if (!currentScene) return;
    const nextIndex = gameState.eventIndex + 1;
    if (nextIndex < currentScene.events.length) {
      setGameState(prev => ({ ...prev, eventIndex: nextIndex }));
    } else {
      goToScene(currentScene.nextSceneId);
    }
  }, [currentScene, gameState.eventIndex, goToScene]);

  const processNonVisualEvent = useCallback((event: SceneEvent) => {
    if (event.type === 'set_variable' && event.variable) {
      setGameState(prev => ({
        ...prev,
        variables: { ...prev.variables, [event.variable!]: event.value ?? '' },
      }));
    }
    if (event.type === 'changeBackground') {
      setGameState(prev => ({ ...prev, background: event.background }));
    }
    if (event.type === 'changeSprite') {
      setGameState(prev => ({
        ...prev,
        charactersOnScreen: prev.charactersOnScreen.map(c =>
          c.characterId === event.characterId ? { ...c, spriteId: event.spriteId || c.spriteId } : c
        ),
      }));
    }
  }, []);

  // Typewriter effect
  useEffect(() => {
    if (!gameState.isPlaying || !currentEvent) return;

    const text = currentEvent.text || '';
    if ((currentEvent.type === 'dialogue' || currentEvent.type === 'narration') && text) {
      setIsTyping(true);
      setDisplayedText('');
      setShowChoices(false);
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
      processNonVisualEvent(currentEvent);
      const timeout = setTimeout(() => advanceEvent(), 100);
      return () => clearTimeout(timeout);
    }
  }, [gameState.sceneId, gameState.eventIndex, gameState.isPlaying]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleClick = () => {
    if (!gameState.isPlaying) return;
    if (isTyping) {
      if (typingRef.current) clearInterval(typingRef.current);
      setDisplayedText(currentEvent?.text || '');
      setIsTyping(false);
      return;
    }
    if (showChoices) return;
    advanceEvent();
  };

  const handleChoice = (choice: Choice) => {
    if (choice.effects) {
      setGameState(prev => ({
        ...prev,
        variables: { ...prev.variables, ...choice.effects },
      }));
    }
    setShowChoices(false);
    goToScene(choice.nextSceneId);
  };

  const bgImageUrl = gameState.background ? imageUrls.get(`backgrounds/${gameState.background}`) : undefined;
  const bgStyle: React.CSSProperties = bgImageUrl
    ? { backgroundImage: `url(${bgImageUrl})`, backgroundSize: 'cover', backgroundPosition: 'center' }
    : { background: getGradient(gameState.background) };

  // Start screen
  if (!gameState.isPlaying) {
    return (
      <div className="game-preview">
        <div className="phone-frame">
          <div className="phone-screen start-screen">
            <div className="start-content">
              <div className="start-icon">{currentScene ? '▶' : '✅'}</div>
              <h3>{!currentScene && gameState.sceneId ? 'Конец главы' : (chapter?.title || 'Глава')}</h3>
              <p>{!currentScene && gameState.sceneId ? 'Все сцены пройдены' : 'Интерактивный предпросмотр'}</p>
              <button className="play-btn" onClick={startPlaying}>
                {!currentScene && gameState.sceneId ? 'Начать сначала' : 'Играть'}
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // End screen (no current scene while playing)
  if (!currentScene) {
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
  const customStyle: React.CSSProperties = {};
  if (project.meta.dialogueFrameColor) {
    customStyle['--frame-color' as string] = project.meta.dialogueFrameColor;
  }
  if (project.meta.dialogueBgColor) {
    customStyle['--frame-bg' as string] = project.meta.dialogueBgColor;
  }

  return (
    <div className="game-preview">
      <div className="phone-frame">
        <div className="phone-screen" style={{ ...bgStyle, ...customStyle }} onClick={handleClick}>
          {/* Top HUD */}
          <div className="gp-hud">
            <span className="gp-scene-label">
              {currentScene.id} · Event {gameState.eventIndex + 1}/{currentScene.events.length}
            </span>
            <button className="gp-stop-btn" onClick={(e) => { e.stopPropagation(); setGameState(prev => ({ ...prev, isPlaying: false })); }}>✕</button>
          </div>

          {/* Characters */}
          <div className="gp-characters">
            {gameState.charactersOnScreen.map(sc => {
              const char = project.characters.find(c => c.id === sc.characterId);
              const sprite = char?.sprites.find(sp => sp.id === sc.spriteId);
              const spriteUrl = sprite ? imageUrls.get(sprite.image) : undefined;
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

          {/* Choices — themed */}
          {showChoices && currentEvent?.choices && (
            <div className={`gp-choices gp-choices-${dialogueTheme}`}>
              {currentEvent.choices.map((choice, i) => {
                if (choice.condition) {
                  const varVal = gameState.variables[choice.condition.variable] as number ?? 0;
                  const check = evaluateCondition(varVal, choice.condition.operator, choice.condition.value);
                  if (!check) return null;
                }
                return (
                  <button
                    key={i}
                    className={`gp-choice gp-choice-${dialogueTheme} ${choice.premium ? 'premium' : ''}`}
                    onClick={(e) => { e.stopPropagation(); handleChoice(choice); }}
                  >
                    {choice.premium && <span className="gp-diamond">💎 {choice.cost}</span>}
                    {choice.text}
                  </button>
                );
              })}
            </div>
          )}

          {/* Effects overlay */}
          {currentEvent?.type === 'effect' && (
            <div className={`gp-effect gp-effect-${currentEvent.effectType}`} />
          )}

          {/* Emotion */}
          {currentEvent?.type === 'showEmotion' && (
            <div className="gp-emotion">
              {getEmotionEmoji(currentEvent.emotionType)}
            </div>
          )}
        </div>
      </div>

      {/* Variables debug */}
      <div className="gp-debug">
        <details>
          <summary>Переменные ({Object.keys(gameState.variables).length})</summary>
          <div className="gp-vars">
            {Object.entries(gameState.variables).map(([k, v]) => (
              <div key={k} className="gp-var">{k}: <strong>{String(v)}</strong></div>
            ))}
          </div>
        </details>
      </div>
    </div>
  );
}

function getGradient(bg?: string): string {
  switch (bg) {
    case 'city_night.png': return 'linear-gradient(180deg, #0D1B2A, #1B263B, #415A77)';
    case 'cafe_night.png': return 'linear-gradient(180deg, #2D1B1B, #4A2C2A, #6B3A3A)';
    case 'mansion.png': return 'linear-gradient(180deg, #1A0A2E, #2D1854, #4A2D7A)';
    default: return 'linear-gradient(180deg, #0F3460, #1A1A2E)';
  }
}

function evaluateCondition(value: number, op: string, target: number): boolean {
  switch (op) {
    case '>=': return value >= target;
    case '<=': return value <= target;
    case '==': return value === target;
    case '!=': return value !== target;
    case '>': return value > target;
    case '<': return value < target;
    default: return true;
  }
}

function getEmotionEmoji(type?: string): string {
  const map: Record<string, string> = {
    heart: '❤️', sweatDrop: '💧', question: '❓', exclamation: '❗',
    anger: '💢', sparkle: '✨', musicNote: '🎵', zzz: '💤',
  };
  return map[type || ''] || '💭';
}
