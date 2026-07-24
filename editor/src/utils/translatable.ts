import type { NovelProject } from '../types/novel';

/** Собрать ВСЕ переводимые строки проекта в порядке появления.
 *  Ключ перевода = исходная строка С плейсхолдерами (формат v2, принцип 3).
 *  Помимо диалогов/нарратива/вариантов выбора включает (формат v2):
 *  recap главы, title/description концовок, playerNamePrompt.prompt,
 *  названия аутфитов, statsDisplay.label. */
export function collectTranslatableStrings(project: NovelProject): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  const push = (s: string | undefined) => {
    if (!s || !s.trim() || seen.has(s)) return;
    seen.add(s);
    result.push(s);
  };

  // playerNamePrompt / statsDisplay из меты
  push(project.meta.playerNamePrompt?.prompt);
  for (const stat of project.meta.statsDisplay || []) push(stat.label);

  // Названия аутфитов
  for (const ch of project.characters) {
    for (const outfit of ch.outfits || []) push(outfit.name);
  }

  for (const chapter of project.chapters) {
    push(chapter.recap);
    for (const scene of chapter.scenes) {
      for (const event of scene.events) {
        if (event.text && (event.type === 'dialogue' || event.type === 'narration')) {
          push(event.text);
        }
        for (const choice of event.choices || []) push(choice.text);
      }
      if (scene.ending) {
        push(scene.ending.title);
        push(scene.ending.description);
      }
    }
  }

  // Заголовки концовок из меты (галерея) — могут не совпадать со сценами
  for (const ending of project.meta.endings || []) push(ending.title);

  return result;
}

export interface StaleTranslationEntry {
  original: string;   // бывший оригинал (ключ, которого больше нет в проекте)
  translated: string; // сохранённый перевод
}

/** Найти «осиротевшие» переводы: ключи, которых больше нет среди строк проекта
 *  (оригинал был изменён/удалён — маппинг по тексту потерял связь). */
export function findStaleTranslations(
  project: NovelProject,
  texts: Record<string, string>,
): StaleTranslationEntry[] {
  const current = new Set(collectTranslatableStrings(project));
  const stale: StaleTranslationEntry[] = [];
  for (const [original, translated] of Object.entries(texts)) {
    if (!translated || !translated.trim()) continue;
    if (!current.has(original)) stale.push({ original, translated });
  }
  return stale;
}
