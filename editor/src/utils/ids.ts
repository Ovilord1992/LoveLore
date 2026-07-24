import type { Chapter } from '../types/novel';

/** Собрать id всех сцен во всех главах — для гарантии глобальной уникальности.
 *  Важно: updateScene в сторе правит сцены по id во ВСЕХ главах, поэтому id
 *  сцен обязаны быть уникальны глобально, иначе будут задеты чужие сцены. */
export function allSceneIds(chapters: Chapter[]): Set<string> {
  const ids = new Set<string>();
  for (const ch of chapters) {
    for (const s of ch.scenes) ids.add(s.id);
  }
  return ids;
}

/** Сгенерировать уникальный id сцены с префиксом главы, не совпадающий ни с
 *  одной существующей сценой (детерминированно, без Date.now/random). */
export function uniqueSceneId(chapterId: string, existing: Set<string>): string {
  let n = 1;
  let candidate = `${chapterId}_scene_${n}`;
  while (existing.has(candidate)) {
    n++;
    candidate = `${chapterId}_scene_${n}`;
  }
  return candidate;
}

/** Id для дубликата сцены: `<исходный>_copy`, `<исходный>_copy2`, … —
 *  детерминированно и глобально уникально. */
export function uniqueCopySceneId(sourceId: string, existing: Set<string>): string {
  let candidate = `${sourceId}_copy`;
  let n = 2;
  while (existing.has(candidate)) {
    candidate = `${sourceId}_copy${n}`;
    n++;
  }
  return candidate;
}

/** Следующий номер главы: max(number) + 1 — гарантирует уникальный id даже при
 *  разрывах нумерации. */
export function nextChapterNumber(chapters: Chapter[]): number {
  return chapters.reduce((max, c) => Math.max(max, c.number), 0) + 1;
}

/** Уникальный id персонажа (char_N), не совпадающий с существующими. */
export function uniqueCharacterId(characters: { id: string }[]): string {
  const existing = new Set(characters.map((c) => c.id));
  let n = characters.length + 1;
  while (existing.has(`char_${n}`)) n++;
  return `char_${n}`;
}

/** Уникальный id спрайта (sprite_N) в пределах персонажа. */
export function uniqueSpriteId(sprites: { id: string }[]): string {
  const existing = new Set(sprites.map((s) => s.id));
  let n = sprites.length + 1;
  while (existing.has(`sprite_${n}`)) n++;
  return `sprite_${n}`;
}

/** Уникальный id аутфита (outfit_N) в пределах персонажа. */
export function uniqueOutfitId(outfits: { id: string }[]): string {
  const existing = new Set(outfits.map((o) => o.id));
  let n = outfits.length + 1;
  while (existing.has(`outfit_${n}`)) n++;
  return `outfit_${n}`;
}
