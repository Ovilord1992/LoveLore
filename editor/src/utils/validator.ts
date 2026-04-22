import type { NovelProject, Scene } from '../types/novel';

export interface ValidationError {
  type: 'error' | 'warning';
  message: string;
  chapterId?: string;
  sceneId?: string;
  eventIndex?: number;
}

/** Валидация проекта новеллы.
 *  @param project - проект новеллы
 *  @param images  - (опционально) Map путей ассетов "backgrounds/x.png" → File.
 *                   Если передана, валидатор дополнительно проверит, что все
 *                   ссылки на фоны/спрайты/CG разрешаются. Если опущена —
 *                   проверка ассетов пропускается.
 */
export function validateProject(
  project: NovelProject,
  images?: Map<string, File>,
): ValidationError[] {
  const errors: ValidationError[] = [];

  // Метаданные
  if (!project.meta.title.trim()) {
    errors.push({ type: 'error', message: 'Название новеллы не указано' });
  }
  if (!project.meta.author.trim()) {
    errors.push({ type: 'warning', message: 'Автор не указан' });
  }
  if (!project.meta.id.trim() || project.meta.id === 'new_novel') {
    errors.push({ type: 'error', message: 'ID новеллы не задан' });
  }

  // Персонажи
  const charIds = new Set(project.characters.map((c) => c.id));

  // Карта персонаж→спрайты для проверки ссылок charactersOnScreen / changeSprite
  const charSpriteMap = new Map<string, Map<string, string>>();
  for (const ch of project.characters) {
    const spriteMap = new Map<string, string>();
    for (const sprite of ch.sprites) {
      spriteMap.set(sprite.id, sprite.image);
    }
    charSpriteMap.set(ch.id, spriteMap);
  }

  const checkAssets = images !== undefined;

  // Главы и сцены
  for (const chapter of project.chapters) {
    const sceneIds = new Set(chapter.scenes.map((s) => s.id));

    // Проверяем firstSceneId
    if (!sceneIds.has(chapter.firstSceneId)) {
      errors.push({
        type: 'error',
        message: `Глава "${chapter.title}": начальная сцена "${chapter.firstSceneId}" не найдена`,
        chapterId: chapter.id,
      });
    }

    if (chapter.scenes.length === 0) {
      errors.push({
        type: 'error',
        message: `Глава "${chapter.title}" не содержит сцен`,
        chapterId: chapter.id,
      });
    }

    // Проверяем каждую сцену
    for (const scene of chapter.scenes) {
      // nextSceneId
      if (scene.nextSceneId && !sceneIds.has(scene.nextSceneId)) {
        errors.push({
          type: 'error',
          message: `Сцена "${scene.id}": ссылка на несуществующую сцену "${scene.nextSceneId}"`,
          chapterId: chapter.id,
          sceneId: scene.id,
        });
      }

      // --- Проверка ассетов: фон ---
      if (checkAssets && scene.background && scene.background.trim()) {
        const path = `backgrounds/${scene.background}`;
        if (!images!.has(path)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий фон: ${scene.background}`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        }
      }

      // --- Проверка ассетов: слои фона ---
      if (checkAssets && scene.backgroundLayers) {
        for (const layer of scene.backgroundLayers) {
          if (!layer.image || !layer.image.trim()) continue;
          const path = `backgrounds/${layer.image}`;
          if (!images!.has(path)) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий слой фона: ${layer.image}`,
              chapterId: chapter.id,
              sceneId: scene.id,
            });
          }
        }
      }

      // Персонажи на сцене
      for (const sc of scene.charactersOnScreen) {
        if (!charIds.has(sc.characterId)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}": персонаж "${sc.characterId}" не найден`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
          continue;
        }

        // --- Проверка ассетов: спрайт ---
        if (checkAssets) {
          const spriteMap = charSpriteMap.get(sc.characterId);
          const spritePath = spriteMap?.get(sc.spriteId);
          if (!spritePath) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий спрайт: ${sc.characterId}/${sc.spriteId}`,
              chapterId: chapter.id,
              sceneId: scene.id,
            });
          } else if (!images!.has(spritePath)) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий спрайт: ${spritePath}`,
              chapterId: chapter.id,
              sceneId: scene.id,
            });
          }
        }
      }

      // События
      for (let i = 0; i < scene.events.length; i++) {
        const event = scene.events[i];

        // Пустые диалоги
        if ((event.type === 'dialogue' || event.type === 'narration') && !event.text?.trim()) {
          errors.push({
            type: 'warning',
            message: `Сцена "${scene.id}", событие #${i + 1}: пустой текст`,
            chapterId: chapter.id,
            sceneId: scene.id,
            eventIndex: i,
          });
        }

        // Диалог без speaker
        if (event.type === 'dialogue' && event.speaker && !charIds.has(event.speaker)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}", событие #${i + 1}: говорящий "${event.speaker}" не найден среди персонажей`,
            chapterId: chapter.id,
            sceneId: scene.id,
            eventIndex: i,
          });
        }

        // --- Проверка ассетов: changeBackground ---
        if (checkAssets && event.type === 'changeBackground' && event.background?.trim()) {
          const path = `backgrounds/${event.background}`;
          if (!images!.has(path)) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий фон: ${event.background}`,
              chapterId: chapter.id,
              sceneId: scene.id,
              eventIndex: i,
            });
          }
        }

        // --- Проверка ассетов: changeSprite ---
        if (checkAssets && event.type === 'changeSprite' && event.characterId && event.spriteId) {
          const spriteMap = charSpriteMap.get(event.characterId);
          const spritePath = spriteMap?.get(event.spriteId);
          if (!spritePath) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий спрайт: ${event.characterId}/${event.spriteId}`,
              chapterId: chapter.id,
              sceneId: scene.id,
              eventIndex: i,
            });
          } else if (!images!.has(spritePath)) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий спрайт: ${spritePath}`,
              chapterId: chapter.id,
              sceneId: scene.id,
              eventIndex: i,
            });
          }
        }

        // --- Проверка ассетов: showCg ---
        if (checkAssets && event.type === 'showCg' && event.cgImage?.trim()) {
          const path = `cg/${event.cgImage}`;
          if (!images!.has(path)) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий CG: ${event.cgImage}`,
              chapterId: chapter.id,
              sceneId: scene.id,
              eventIndex: i,
            });
          }
        }

        // --- Проверка ассетов: play_sound ---
        // В editorStore сейчас нет Map для звуков (только images),
        // поэтому проверку звука пропускаем — не блокируем валидацию.
        // TODO: когда появится sounds Map — добавить аналогичную проверку.

        // Выборы
        if (event.type === 'choice' && event.choices) {
          if (event.choices.length === 0) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}", событие #${i + 1}: выбор без вариантов`,
              chapterId: chapter.id,
              sceneId: scene.id,
              eventIndex: i,
            });
          }

          for (const choice of event.choices) {
            if (!choice.text.trim()) {
              errors.push({
                type: 'warning',
                message: `Сцена "${scene.id}", событие #${i + 1}: пустой текст варианта`,
                chapterId: chapter.id,
                sceneId: scene.id,
                eventIndex: i,
              });
            }
            if (choice.nextSceneId && !sceneIds.has(choice.nextSceneId)) {
              errors.push({
                type: 'error',
                message: `Сцена "${scene.id}": выбор "${choice.text}" ведёт к несуществующей сцене "${choice.nextSceneId}"`,
                chapterId: chapter.id,
                sceneId: scene.id,
                eventIndex: i,
              });
            }
          }
        }
      }
    }

    // Проверяем достижимость сцен
    const reachable = findReachableScenes(chapter.scenes, chapter.firstSceneId);
    for (const scene of chapter.scenes) {
      if (!reachable.has(scene.id)) {
        errors.push({
          type: 'warning',
          message: `Сцена "${scene.id}" недостижима из начальной сцены`,
          chapterId: chapter.id,
          sceneId: scene.id,
        });
      }
    }
  }

  return errors;
}

/** BFS по графу сцен для нахождения достижимых */
function findReachableScenes(scenes: Scene[], startId: string): Set<string> {
  const reachable = new Set<string>();
  const queue = [startId];

  while (queue.length > 0) {
    const id = queue.shift()!;
    if (reachable.has(id)) continue;
    reachable.add(id);

    const scene = scenes.find((s) => s.id === id);
    if (!scene) continue;

    // nextSceneId
    if (scene.nextSceneId) queue.push(scene.nextSceneId);

    // Выборы ведущие к другим сценам
    for (const event of scene.events) {
      if (event.type === 'choice' && event.choices) {
        for (const choice of event.choices) {
          if (choice.nextSceneId) queue.push(choice.nextSceneId);
        }
      }
    }
  }

  return reachable;
}
