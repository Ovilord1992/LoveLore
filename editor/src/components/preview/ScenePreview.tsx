import { useEditorStore } from '../../store/editorStore';
import './ScenePreview.css';

export function ScenePreview() {
  const { project, selectedChapterIndex, selectedSceneId, selectedEventIndex } = useEditorStore();
  const imageUrls = useEditorStore((s) => s.imageUrls);

  const chapter = project.chapters[selectedChapterIndex];
  const scene = chapter?.scenes.find((s) => s.id === selectedSceneId);

  if (!scene) {
    return (
      <div className="scene-preview empty">
        <div className="phone-frame">
          <div className="phone-screen">
            <p>Выберите сцену для превью</p>
          </div>
        </div>
      </div>
    );
  }

  const event = selectedEventIndex !== null ? scene.events[selectedEventIndex] : scene.events[0];

  // Фон: сначала ищем загруженное изображение, потом градиент
  const bgImageUrl = scene.background ? imageUrls.get(`backgrounds/${scene.background}`) : undefined;
  const bgStyle: React.CSSProperties = bgImageUrl
    ? { backgroundImage: `url(${bgImageUrl})`, backgroundSize: 'cover', backgroundPosition: 'center' }
    : { background: getBackgroundGradient(scene.background) };

  return (
    <div className="scene-preview">
      <div className="phone-frame">
        <div className="phone-screen" style={bgStyle}>
          {/* Персонажи */}
          <div className="preview-characters">
            {scene.charactersOnScreen.map((sc) => {
              const char = project.characters.find((c) => c.id === sc.characterId);
              const sprite = char?.sprites.find((sp) => sp.id === sc.spriteId);
              const spriteUrl = sprite ? imageUrls.get(sprite.image) : undefined;
              return (
                <div key={sc.characterId} className={`preview-character ${sc.position}`}>
                  {spriteUrl ? (
                    <img src={spriteUrl} alt={char?.name || sc.characterId} className="character-sprite" />
                  ) : (
                    <div className="character-placeholder">
                      {char?.name?.[0] || '?'}
                    </div>
                  )}
                  <span className="character-name" style={{ color: char?.color }}>{char?.name || sc.characterId}</span>
                </div>
              );
            })}
          </div>

          {/* Текущее событие */}
          {event && (
            <div className="preview-event">
              {event.type === 'dialogue' && (
                <div className="preview-dialogue">
                  {event.speaker && (
                    <div className="preview-speaker" style={{ color: getSpeakerColor(event.speaker, project.characters) }}>
                      {project.characters.find((c) => c.id === event.speaker)?.name || event.speaker}
                    </div>
                  )}
                  <div className="preview-text">{event.text || '...'}</div>
                </div>
              )}

              {event.type === 'narration' && (
                <div className="preview-narration">
                  <div className="preview-text italic">{event.text || '...'}</div>
                </div>
              )}

              {event.type === 'choice' && (
                <div className="preview-choices">
                  {event.choices?.map((choice, i) => (
                    <div key={i} className={`preview-choice ${choice.premium ? 'premium' : ''}`}>
                      {choice.premium && <span className="diamond">💎 {choice.cost}</span>}
                      {choice.text || 'Вариант...'}
                    </div>
                  ))}
                </div>
              )}

              {event.type === 'changeBackground' && (
                <div className="preview-narration">
                  <div className="preview-text italic">🖼 Смена фона → {event.asset || '...'}</div>
                </div>
              )}

              {event.type === 'changeSprite' && (
                <div className="preview-narration">
                  <div className="preview-text italic">🎭 Смена спрайта → {event.characterId} / {event.spriteId || '...'}</div>
                </div>
              )}

              {event.type === 'effect' && (
                <div className="preview-narration">
                  <div className="preview-text italic">✨ Эффект: {event.effectType || '...'} ({event.effectDuration || 500}мс, {((event.effectIntensity ?? 0.7) * 100).toFixed(0)}%)</div>
                </div>
              )}

              {event.type === 'showCg' && (
                <div className="preview-narration">
                  <div className="preview-text italic">🖼️ CG: {event.cgImage || '...'} ({event.cgTransition || 'fade'}, {event.cgDuration || 800}мс)</div>
                </div>
              )}

              {event.type === 'cameraMove' && (
                <div className="preview-narration">
                  <div className="preview-text italic">📷 Камера: zoom={event.zoom?.toFixed(1) || '1.0'} pan=({event.panX || 0}, {event.panY || 0}) {event.cameraDuration || 1000}мс</div>
                </div>
              )}

              {event.type === 'showEmotion' && (
                <div className="preview-narration">
                  <div className="preview-text italic">💭 Эмоция: {event.emotionType || '...'} → {project.characters.find(c => c.id === event.characterId)?.name || event.characterId || '...'}</div>
                </div>
              )}
            </div>
          )}

          {/* Навигация событий */}
          <div className="preview-nav">
            {scene.events.map((_, i) => (
              <div
                key={i}
                className={`preview-nav-dot ${i === (selectedEventIndex ?? 0) ? 'active' : ''}`}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function getBackgroundGradient(bg?: string): string {
  switch (bg) {
    case 'city_night.png': return 'linear-gradient(180deg, #0D1B2A, #1B263B, #415A77)';
    case 'cafe_night.png': return 'linear-gradient(180deg, #2D1B1B, #4A2C2A, #6B3A3A)';
    case 'mansion.png': return 'linear-gradient(180deg, #1A0A2E, #2D1854, #4A2D7A)';
    default: return 'linear-gradient(180deg, #0F3460, #1A1A2E)';
  }
}

function getSpeakerColor(speakerId: string, characters: { id: string; color: string }[]): string {
  return characters.find((c) => c.id === speakerId)?.color || '#e91e63';
}
