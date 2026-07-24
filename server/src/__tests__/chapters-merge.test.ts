/**
 * Юнит-тесты хелпера mergeChapterReleaseState: сохранение isReleased/releasedAt
 * при перезаливке ZIP (спека 2.4).
 */
import { describe, it, expect } from 'vitest';
import { mergeChapterReleaseState } from '../utils/chapters';

const now = new Date('2026-07-24T12:00:00Z');
const oldDate = new Date('2026-01-01T00:00:00Z');

describe('mergeChapterReleaseState', () => {
  it('новая новелла: все главы released сразу', () => {
    const result = mergeChapterReleaseState(
      [
        { number: 1, title: 'Глава 1' },
        { number: 2, title: 'Глава 2' },
      ],
      [],
      true,
      now
    );
    expect(result.releasedCount).toBe(2);
    expect(result.removedNumbers).toEqual([]);
    for (const ch of result.chapters) {
      expect(ch.isReleased).toBe(true);
      expect(ch.releasedAt).toBe(now);
    }
  });

  it('перезаливка: существующие главы сохраняют isReleased/releasedAt по number', () => {
    const result = mergeChapterReleaseState(
      [
        { number: 1, title: 'Глава 1 (новый заголовок)' },
        { number: 2, title: 'Глава 2' },
      ],
      [
        { number: 1, isReleased: true, releasedAt: oldDate },
        { number: 2, isReleased: false, releasedAt: null },
      ],
      false,
      now
    );

    const ch1 = result.chapters.find((c) => c.number === 1)!;
    const ch2 = result.chapters.find((c) => c.number === 2)!;
    expect(ch1.isReleased).toBe(true);
    expect(ch1.releasedAt).toBe(oldDate); // НЕ сброшен
    expect(ch1.title).toBe('Глава 1 (новый заголовок)');
    expect(ch2.isReleased).toBe(false);
    expect(result.releasedCount).toBe(1); // не chaptersCount!
  });

  it('перезаливка: новые главы создаются невыпущенными', () => {
    const result = mergeChapterReleaseState(
      [
        { number: 1, title: 'Глава 1' },
        { number: 2, title: 'Глава 2 (новая)' },
        { number: 3, title: 'Глава 3 (новая)' },
      ],
      [{ number: 1, isReleased: true, releasedAt: oldDate }],
      false,
      now
    );

    expect(result.chapters.find((c) => c.number === 2)!.isReleased).toBe(false);
    expect(result.chapters.find((c) => c.number === 3)!.isReleased).toBe(false);
    expect(result.chapters.find((c) => c.number === 2)!.releasedAt).toBeNull();
    expect(result.releasedCount).toBe(1);
  });

  it('главы, исчезнувшие из ZIP, попадают в removedNumbers', () => {
    const result = mergeChapterReleaseState(
      [{ number: 1, title: 'Глава 1' }],
      [
        { number: 1, isReleased: true, releasedAt: oldDate },
        { number: 2, isReleased: true, releasedAt: oldDate },
        { number: 3, isReleased: false, releasedAt: null },
      ],
      false,
      now
    );
    expect(result.removedNumbers.sort()).toEqual([2, 3]);
    expect(result.releasedCount).toBe(1);
  });

  it('запланированная глава (releasedAt в будущем) переживает перезаливку', () => {
    const future = new Date('2026-12-31T00:00:00Z');
    const result = mergeChapterReleaseState(
      [{ number: 5, title: 'Глава 5' }],
      [{ number: 5, isReleased: false, releasedAt: future }],
      false,
      now
    );
    expect(result.chapters[0]!.isReleased).toBe(false);
    expect(result.chapters[0]!.releasedAt).toBe(future); // план сохранён
  });
});
