/**
 * Чистый хелпер слияния состояния релиза глав при (пере)заливке ZIP.
 *
 * Правила (спека 2.4):
 *  - существующие главы (по number) сохраняют isReleased/releasedAt;
 *  - новые главы: у новой новеллы — released сразу, при перезаливке — isReleased=false;
 *  - главы, исчезнувшие из ZIP, удаляются (removedNumbers).
 */

export interface IncomingChapter {
  number: number;
  title: string;
}

export interface ExistingChapterState {
  number: number;
  isReleased: boolean;
  releasedAt: Date | null;
}

export interface MergedChapterState {
  number: number;
  title: string;
  isReleased: boolean;
  releasedAt: Date | null;
}

export interface ChapterMergeResult {
  chapters: MergedChapterState[];
  releasedCount: number;
  removedNumbers: number[];
}

export function mergeChapterReleaseState(
  incoming: IncomingChapter[],
  existing: ExistingChapterState[],
  isNewNovel: boolean,
  now: Date = new Date()
): ChapterMergeResult {
  const byNumber = new Map(existing.map((c) => [c.number, c]));

  const chapters: MergedChapterState[] = incoming.map((ch) => {
    const prev = byNumber.get(ch.number);
    if (prev) {
      return { number: ch.number, title: ch.title, isReleased: prev.isReleased, releasedAt: prev.releasedAt };
    }
    if (isNewNovel) {
      return { number: ch.number, title: ch.title, isReleased: true, releasedAt: now };
    }
    return { number: ch.number, title: ch.title, isReleased: false, releasedAt: null };
  });

  const incomingNumbers = new Set(incoming.map((c) => c.number));
  const removedNumbers = existing
    .filter((c) => !incomingNumbers.has(c.number))
    .map((c) => c.number);

  return {
    chapters,
    releasedCount: chapters.filter((c) => c.isReleased).length,
    removedNumbers,
  };
}
