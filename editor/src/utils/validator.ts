import type { Condition, NovelProject, Scene } from '../types/novel';

export interface ValidationError {
  type: 'error' | 'warning';
  message: string;
  chapterId?: string;
  sceneId?: string;
  eventIndex?: number;
}

const STAT_ICONS = new Set(['heart', 'star', 'flame', 'diamond', 'moon', 'sun', 'leaf']);
const HEX_COLOR_RE = /^#[0-9a-fA-F]{6}$/;

/** Валидация проекта новеллы.
 *  @param project - проект новеллы
 *  @param assets  - (опционально) Map путей ассетов "backgrounds/x.png" → File.
 *                   Содержит и картинки, и аудио (music/, sounds/, voice/).
 *                   Если передана, валидатор дополнительно проверит, что все
 *                   ссылки на фоны/спрайты/CG/аудио разрешаются. Если опущена —
 *                   проверка ассетов пропускается.
 */
export function validateProject(
  project: NovelProject,
  assets?: Map<string, File>,
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

  const checkAssets = assets !== undefined;
  const hasAsset = (path: string) => !checkAssets || assets!.has(path);

  // --- meta.endings (v2 1.3) ---
  const metaEndingIds = new Set<string>();
  for (const ending of project.meta.endings || []) {
    if (!ending.id.trim()) {
      errors.push({ type: 'error', message: 'Концовка в мете без id' });
      continue;
    }
    if (metaEndingIds.has(ending.id)) {
      errors.push({ type: 'error', message: `Дублирующийся id концовки в мете: "${ending.id}"` });
    }
    metaEndingIds.add(ending.id);
    if (!ending.title.trim()) {
      errors.push({ type: 'warning', message: `Концовка "${ending.id}": пустой заголовок` });
    }
  }

  // --- meta.statsDisplay (v2 1.9) ---
  for (const stat of project.meta.statsDisplay || []) {
    if (!stat.variable.trim()) {
      errors.push({ type: 'error', message: 'Стат в statsDisplay без имени переменной' });
      continue;
    }
    if (!(stat.variable in project.variables)) {
      errors.push({ type: 'warning', message: `statsDisplay: переменная "${stat.variable}" не объявлена во вкладке «Переменные»` });
    }
    if (stat.icon && !STAT_ICONS.has(stat.icon)) {
      errors.push({ type: 'error', message: `statsDisplay "${stat.variable}": недопустимая иконка "${stat.icon}"` });
    }
    if (stat.color && !HEX_COLOR_RE.test(stat.color)) {
      errors.push({ type: 'warning', message: `statsDisplay "${stat.variable}": цвет "${stat.color}" не hex-формата #RRGGBB` });
    }
    if (stat.max !== undefined && stat.max <= 0) {
      errors.push({ type: 'warning', message: `statsDisplay "${stat.variable}": max должен быть > 0` });
    }
  }

  // --- meta.playerNamePrompt (v2 1.4) ---
  if (project.meta.playerNamePrompt?.enabled && !project.meta.playerNamePrompt.prompt?.trim()) {
    errors.push({ type: 'warning', message: 'playerNamePrompt включён, но текст запроса имени пуст' });
  }

  // Персонажи
  const charIds = new Set(project.characters.map((c) => c.id));

  // Карта персонаж→спрайты для проверки ссылок charactersOnScreen / changeSprite
  const charSpriteMap = new Map<string, Map<string, string>>();
  // Карта "charId:outfitId" для проверки unlockOutfits
  const outfitKeys = new Set<string>();
  for (const ch of project.characters) {
    const spriteMap = new Map<string, string>();
    for (const sprite of ch.sprites) {
      spriteMap.set(sprite.id, sprite.image);
    }
    charSpriteMap.set(ch.id, spriteMap);

    // --- Аутфиты (v2 1.5) ---
    const outfitIds = new Set<string>();
    let defaultCount = 0;
    for (const outfit of ch.outfits || []) {
      if (!outfit.id.trim()) {
        errors.push({ type: 'error', message: `Персонаж "${ch.name}": аутфит без id` });
        continue;
      }
      if (outfitIds.has(outfit.id)) {
        errors.push({ type: 'error', message: `Персонаж "${ch.name}": дублирующийся id аутфита "${outfit.id}"` });
      }
      outfitIds.add(outfit.id);
      outfitKeys.add(`${ch.id}:${outfit.id}`);
      if (!outfit.name.trim()) {
        errors.push({ type: 'warning', message: `Персонаж "${ch.name}": аутфит "${outfit.id}" без названия` });
      }
      if (outfit.default) defaultCount++;
      if (checkAssets && outfit.thumbnail && !hasAsset(outfit.thumbnail)) {
        errors.push({ type: 'error', message: `Аутфит "${ch.id}:${outfit.id}": отсутствует thumbnail: ${outfit.thumbnail}` });
      }
      for (const [key, spritePath] of Object.entries(outfit.sprites || {})) {
        if (!spritePath.trim()) {
          errors.push({ type: 'warning', message: `Аутфит "${ch.id}:${outfit.id}": пустой путь спрайта для ключа "${key}"` });
        } else if (checkAssets && !hasAsset(spritePath)) {
          errors.push({ type: 'error', message: `Аутфит "${ch.id}:${outfit.id}": отсутствует спрайт "${key}": ${spritePath}` });
        }
      }
    }
    if ((ch.outfits?.length || 0) > 0 && defaultCount === 0) {
      errors.push({ type: 'warning', message: `Персонаж "${ch.name}": ни один аутфит не отмечен как default — гардероб может быть пуст при старте` });
    }
    if (defaultCount > 1) {
      errors.push({ type: 'warning', message: `Персонаж "${ch.name}": больше одного default-аутфита` });
    }
  }

  const checkConditions = (
    conditions: Condition[] | undefined,
    where: string,
    chapterId: string,
    sceneId: string,
    eventIndex?: number,
  ) => {
    for (const cond of conditions || []) {
      if (!cond.variable.trim()) {
        errors.push({
          type: 'error',
          message: `${where}: условие без имени переменной`,
          chapterId, sceneId, eventIndex,
        });
      }
    }
  };

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

      // --- Ветки (v2 1.2) ---
      for (let bi = 0; bi < (scene.branches?.length || 0); bi++) {
        const branch = scene.branches![bi];
        if (!branch.nextSceneId || !branch.nextSceneId.trim()) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}", ветка #${bi + 1}: не указана целевая сцена`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        } else if (!sceneIds.has(branch.nextSceneId)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}", ветка #${bi + 1}: ведёт к несуществующей сцене "${branch.nextSceneId}"`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        }
        if (!branch.conditions || branch.conditions.length === 0) {
          errors.push({
            type: 'warning',
            message: `Сцена "${scene.id}", ветка #${bi + 1}: без условий (всегда срабатывает — ветки ниже недостижимы)`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        }
        checkConditions(branch.conditions, `Сцена "${scene.id}", ветка #${bi + 1}`, chapter.id, scene.id);
      }

      // --- Концовка (v2 1.3) ---
      if (scene.ending) {
        if (!scene.ending.id.trim()) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}": концовка без id`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        } else if (metaEndingIds.size > 0 && !metaEndingIds.has(scene.ending.id)) {
          errors.push({
            type: 'warning',
            message: `Сцена "${scene.id}": концовка "${scene.ending.id}" не перечислена в meta.endings (галерея «N из M» её не покажет)`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        }
        if (!scene.ending.title.trim()) {
          errors.push({
            type: 'warning',
            message: `Сцена "${scene.id}": концовка "${scene.ending.id}" без заголовка`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        }
        if (checkAssets && scene.ending.image?.trim() && !hasAsset(scene.ending.image)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}": отсутствует изображение концовки: ${scene.ending.image}`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        }
      }

      // --- Проверка ассетов: фон ---
      if (checkAssets && scene.background && scene.background.trim()) {
        const path = `backgrounds/${scene.background}`;
        if (!assets!.has(path)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий фон: ${scene.background}`,
            chapterId: chapter.id,
            sceneId: scene.id,
          });
        }
      }

      // --- Проверка ассетов: музыка сцены ---
      if (checkAssets && scene.music && scene.music.trim() && !assets!.has(scene.music)) {
        errors.push({
          type: 'error',
          message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующую музыку: ${scene.music}`,
          chapterId: chapter.id,
          sceneId: scene.id,
        });
      }

      // --- Проверка ассетов: слои фона ---
      if (checkAssets && scene.backgroundLayers) {
        for (const layer of scene.backgroundLayers) {
          if (!layer.image || !layer.image.trim()) continue;
          const path = `backgrounds/${layer.image}`;
          if (!assets!.has(path)) {
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
          } else if (!assets!.has(spritePath)) {
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

        // --- Проверка ассетов: озвучка (v2 1.6) ---
        if (checkAssets && (event.type === 'dialogue' || event.type === 'narration')
            && event.voice?.trim() && !assets!.has(event.voice)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}", событие #${i + 1}: отсутствует файл озвучки: ${event.voice}`,
            chapterId: chapter.id,
            sceneId: scene.id,
            eventIndex: i,
          });
        }

        // --- Проверка ассетов: changeBackground (поле asset) ---
        if (checkAssets && event.type === 'changeBackground' && event.asset?.trim()) {
          const path = `backgrounds/${event.asset}`;
          if (!assets!.has(path)) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий фон: ${event.asset}`,
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
          } else if (!assets!.has(spritePath)) {
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
        // cgImage уже содержит префикс "cg/..." (UI кладёт его при загрузке и
        // клиент ждёт novels/<id>/${cgImage}), поэтому проверяем путь как есть,
        // без повторного префикса.
        if (checkAssets && event.type === 'showCg' && event.cgImage?.trim()) {
          if (!assets!.has(event.cgImage)) {
            errors.push({
              type: 'error',
              message: `Сцена "${scene.id}" в главе "${chapter.id}" ссылается на несуществующий CG: ${event.cgImage}`,
              chapterId: chapter.id,
              sceneId: scene.id,
              eventIndex: i,
            });
          }
        }

        // --- Проверка ассетов: playSound (путь как есть: "sounds/door.mp3") ---
        if (checkAssets && event.type === 'playSound' && event.asset?.trim() && !assets!.has(event.asset)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}", событие #${i + 1}: отсутствует звук: ${event.asset}`,
            chapterId: chapter.id,
            sceneId: scene.id,
            eventIndex: i,
          });
        }

        // --- Проверка ассетов: картинка эмоции (v2 1.7) ---
        if (checkAssets && event.type === 'showEmotion' && event.image?.trim() && !assets!.has(event.image)) {
          errors.push({
            type: 'error',
            message: `Сцена "${scene.id}", событие #${i + 1}: отсутствует картинка эмоции: ${event.image}`,
            chapterId: chapter.id,
            sceneId: scene.id,
            eventIndex: i,
          });
        }

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
            if (!choice.nextSceneId || !choice.nextSceneId.trim()) {
              // Пустой nextSceneId (дефолт нового варианта {text:'', nextSceneId:''})
              // — критическая ошибка: выбор никуда не ведёт.
              errors.push({
                type: 'error',
                message: `Сцена "${scene.id}", событие #${i + 1}: вариант "${choice.text || '(без текста)'}" без ссылки на сцену (nextSceneId пуст)`,
                chapterId: chapter.id,
                sceneId: scene.id,
                eventIndex: i,
              });
            } else if (!sceneIds.has(choice.nextSceneId)) {
              errors.push({
                type: 'error',
                message: `Сцена "${scene.id}": выбор "${choice.text}" ведёт к несуществующей сцене "${choice.nextSceneId}"`,
                chapterId: chapter.id,
                sceneId: scene.id,
                eventIndex: i,
              });
            }

            // v2 1.1: составные условия
            checkConditions(choice.conditions, `Сцена "${scene.id}", вариант "${choice.text || '(без текста)'}"`, chapter.id, scene.id, i);

            // v2 1.5: unlockOutfits — ссылки "char:outfit"
            for (const key of choice.unlockOutfits || []) {
              if (!outfitKeys.has(key)) {
                errors.push({
                  type: 'error',
                  message: `Сцена "${scene.id}", вариант "${choice.text || '(без текста)'}": unlockOutfits ссылается на несуществующий аутфит "${key}"`,
                  chapterId: chapter.id,
                  sceneId: scene.id,
                  eventIndex: i,
                });
              }
            }
          }
        }
      }
    }

    // Проверяем достижимость сцен (включая branches)
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

    // Ветки (v2 1.2)
    for (const branch of scene.branches || []) {
      if (branch.nextSceneId) queue.push(branch.nextSceneId);
    }

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
