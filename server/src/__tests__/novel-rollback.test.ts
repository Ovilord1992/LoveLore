/**
 * Тесты версий контента и отката новеллы (спека 4.3): архивирование с
 * ротацией последних 5 версий, восстановление ZIP + merge release-состояния
 * глав, version++. Mock-prisma + реальная файловая система во временной
 * директории (UPLOAD_DIR читается сервисом при вызове).
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import fs from 'fs';
import os from 'os';
import path from 'path';
import AdmZip from 'adm-zip';

const mocks = vi.hoisted(() => {
  type NovelRow = {
    id: string;
    version: number;
    zipFilename: string | null;
    chaptersCount: number;
    releasedChapters: number;
    fileSize: number;
  };
  type ChapterRow = {
    id: string;
    novelId: string;
    number: number;
    title: string;
    isReleased: boolean;
    releasedAt: Date | null;
  };
  type ArchiveRow = {
    id: string;
    novelId: string;
    version: number;
    filePath: string;
    sizeBytes: number;
    createdAt: Date;
  };

  const state = {
    novel: null as NovelRow | null,
    chapters: [] as ChapterRow[],
    archives: [] as ArchiveRow[],
  };

  function resetState() {
    state.novel = null;
    state.chapters = [];
    state.archives = [];
  }

  const randomUuid = () =>
    (globalThis as unknown as { crypto: { randomUUID: () => string } }).crypto.randomUUID();

  const prismaMock: any = {
    novel: {
      findUnique: async ({ where }: any) =>
        state.novel && state.novel.id === where.id ? { ...state.novel } : null,
      update: async ({ where, data }: any) => {
        const n = state.novel;
        if (!n || n.id !== where.id) throw new Error('novel not found');
        if (data.version?.increment) n.version += data.version.increment;
        if (typeof data.chaptersCount === 'number') n.chaptersCount = data.chaptersCount;
        if (typeof data.releasedChapters === 'number') n.releasedChapters = data.releasedChapters;
        if (typeof data.fileSize === 'number') n.fileSize = data.fileSize;
        return {
          id: n.id,
          version: n.version,
          chaptersCount: n.chaptersCount,
          releasedChapters: n.releasedChapters,
        };
      },
    },
    chapter: {
      findMany: async ({ where }: any) =>
        state.chapters
          .filter((c) => c.novelId === where.novelId)
          .map((c) => ({ number: c.number, isReleased: c.isReleased, releasedAt: c.releasedAt })),
      upsert: async ({ where, update, create }: any) => {
        const w = where.novelId_number;
        const existing = state.chapters.find((c) => c.novelId === w.novelId && c.number === w.number);
        if (existing) {
          if (update.title !== undefined) existing.title = update.title;
          return existing;
        }
        const row = {
          id: randomUuid(),
          novelId: create.novelId,
          number: create.number,
          title: create.title,
          isReleased: create.isReleased,
          releasedAt: create.releasedAt,
        };
        state.chapters.push(row);
        return row;
      },
      deleteMany: async ({ where }: any) => {
        const numbers = new Set(where.number.in as number[]);
        const before = state.chapters.length;
        state.chapters = state.chapters.filter(
          (c) => !(c.novelId === where.novelId && numbers.has(c.number))
        );
        return { count: before - state.chapters.length };
      },
    },
    novelArchive: {
      findUnique: async ({ where }: any) => {
        const w = where.novelId_version;
        return state.archives.find((a) => a.novelId === w.novelId && a.version === w.version) ?? null;
      },
      findMany: async ({ where, orderBy, skip, select }: any) => {
        let rows = state.archives.filter((a) => a.novelId === where.novelId);
        if (orderBy?.version === 'desc') rows = [...rows].sort((a, b) => b.version - a.version);
        if (skip) rows = rows.slice(skip);
        if (select) {
          return rows.map((a) => ({ version: a.version, sizeBytes: a.sizeBytes, createdAt: a.createdAt }));
        }
        return rows.map((a) => ({ ...a }));
      },
      upsert: async ({ where, update, create }: any) => {
        const w = where.novelId_version;
        const existing = state.archives.find((a) => a.novelId === w.novelId && a.version === w.version);
        if (existing) {
          existing.filePath = update.filePath;
          existing.sizeBytes = update.sizeBytes;
          return existing;
        }
        const row = { id: randomUuid(), createdAt: new Date(), ...create };
        state.archives.push(row);
        return row;
      },
      deleteMany: async ({ where }: any) => {
        const ids = new Set(where.id.in as string[]);
        const before = state.archives.length;
        state.archives = state.archives.filter((a) => !ids.has(a.id));
        return { count: before - state.archives.length };
      },
    },
  };

  return { state, resetState, prismaMock };
});

const { state, resetState } = mocks;

vi.mock('../db', () => ({ default: mocks.prismaMock }));

import { archiveCurrentZip, MAX_ARCHIVE_VERSIONS } from '../novels/archive';
import { rollbackNovelToVersion } from '../novels/rollback';
import { extractChaptersFromZip } from '../utils/zip';

const NOVEL_ID = 'test_novel';

let tmpDir: string;
let prevUploadDir: string | undefined;

function makeZipBuffer(chapterNumbers: number[]): Buffer {
  const zip = new AdmZip();
  zip.addFile('meta.json', Buffer.from(JSON.stringify({ id: NOVEL_ID, title: 'Test Novel' })));
  for (const n of chapterNumbers) {
    zip.addFile(
      `chapters/chapter_${n}.json`,
      Buffer.from(
        JSON.stringify({ id: `chapter_${n}`, number: n, title: `Глава ${n}`, firstSceneId: 's1', scenes: [{}] })
      )
    );
  }
  return zip.toBuffer();
}

function packPath(): string {
  return path.join(tmpDir, 'packs', `${NOVEL_ID}.zip`);
}

function writePack(chapterNumbers: number[]): void {
  fs.mkdirSync(path.dirname(packPath()), { recursive: true });
  fs.writeFileSync(packPath(), makeZipBuffer(chapterNumbers));
}

function archiveFile(version: number): string {
  return path.join(tmpDir, 'history', NOVEL_ID, `v${version}.zip`);
}

/** Заранее положить версию в историю (файл + строка), минуя сервис. */
function seedArchive(version: number, chapterNumbers: number[]): void {
  fs.mkdirSync(path.dirname(archiveFile(version)), { recursive: true });
  fs.writeFileSync(archiveFile(version), makeZipBuffer(chapterNumbers));
  state.archives.push({
    id: `arch-${version}`,
    novelId: NOVEL_ID,
    version,
    filePath: path.join('history', NOVEL_ID, `v${version}.zip`),
    sizeBytes: fs.statSync(archiveFile(version)).size,
    createdAt: new Date(),
  });
}

function seedChapter(number: number, isReleased: boolean): void {
  state.chapters.push({
    id: `ch-${number}`,
    novelId: NOVEL_ID,
    number,
    title: `Глава ${number}`,
    isReleased,
    releasedAt: isReleased ? new Date('2026-01-01T00:00:00Z') : null,
  });
}

beforeEach(() => {
  resetState();
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'amoria-rollback-'));
  prevUploadDir = process.env.UPLOAD_DIR;
  process.env.UPLOAD_DIR = tmpDir;
});

afterEach(() => {
  process.env.UPLOAD_DIR = prevUploadDir;
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

describe('NovelArchive — архивирование и ротация', () => {
  it('копирует ZIP в history/<novelId>/v<version>.zip и пишет строку', async () => {
    writePack([1, 2]);
    const ok = await archiveCurrentZip(NOVEL_ID, 1, packPath());
    expect(ok).toBe(true);
    expect(fs.existsSync(archiveFile(1))).toBe(true);
    expect(state.archives).toHaveLength(1);
    expect(state.archives[0]!.version).toBe(1);
    expect(state.archives[0]!.sizeBytes).toBeGreaterThan(0);
  });

  it('возвращает false для отсутствующего исходного файла', async () => {
    expect(await archiveCurrentZip(NOVEL_ID, 1, packPath())).toBe(false);
    expect(state.archives).toHaveLength(0);
  });

  it(`хранит последние ${MAX_ARCHIVE_VERSIONS} версий — старшие удаляются с файлами`, async () => {
    writePack([1]);
    for (let v = 1; v <= 7; v++) {
      await archiveCurrentZip(NOVEL_ID, v, packPath());
    }

    const versions = state.archives.map((a) => a.version).sort((a, b) => a - b);
    expect(versions).toEqual([3, 4, 5, 6, 7]);
    expect(fs.existsSync(archiveFile(1))).toBe(false);
    expect(fs.existsSync(archiveFile(2))).toBe(false);
    for (let v = 3; v <= 7; v++) {
      expect(fs.existsSync(archiveFile(v))).toBe(true);
    }
  });
});

describe('NovelArchive — rollback', () => {
  it('восстанавливает ZIP, мержит release-состояние глав, version++', async () => {
    // Текущее состояние: v2 с главами 1..3 (глава 2 не выпущена).
    writePack([1, 2, 3]);
    state.novel = {
      id: NOVEL_ID,
      version: 2,
      zipFilename: `${NOVEL_ID}.zip`,
      chaptersCount: 3,
      releasedChapters: 2,
      fileSize: fs.statSync(packPath()).size,
    };
    seedChapter(1, true);
    seedChapter(2, false);
    seedChapter(3, true);
    // История: v1 содержала только главы 1..2.
    seedArchive(1, [1, 2]);

    const result = await rollbackNovelToVersion(NOVEL_ID, 1);
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    expect(result.rolledBackTo).toBe(1);
    // История линейна: version++ (2 → 3).
    expect(result.novel.version).toBe(3);
    expect(result.novel.chaptersCount).toBe(2);
    expect(result.novel.releasedChapters).toBe(1);

    // ZIP восстановлен из архива: только главы 1 и 2.
    const restored = extractChaptersFromZip(packPath()).map((c) => c.number);
    expect(restored).toEqual([1, 2]);

    // Merge release-состояния: глава 1 осталась выпущенной, 2 — нет, 3 удалена.
    const byNumber = new Map(state.chapters.map((c) => [c.number, c]));
    expect(byNumber.get(1)!.isReleased).toBe(true);
    expect(byNumber.get(2)!.isReleased).toBe(false);
    expect(byNumber.has(3)).toBe(false);

    // Текущее состояние (v2) записано в историю перед откатом.
    expect(state.archives.some((a) => a.version === 2)).toBe(true);
    expect(fs.existsSync(archiveFile(2))).toBe(true);
  });

  it('ротация при откате не удаляет восстанавливаемую версию', async () => {
    // История заполнена: v1..v5, текущая версия 6. Архивирование текущей (v6)
    // вытеснит v1 — но её содержимое уже прочитано и корректно восстановится.
    writePack([1, 2, 3]);
    state.novel = {
      id: NOVEL_ID,
      version: 6,
      zipFilename: `${NOVEL_ID}.zip`,
      chaptersCount: 3,
      releasedChapters: 3,
      fileSize: fs.statSync(packPath()).size,
    };
    seedChapter(1, true);
    seedChapter(2, true);
    seedChapter(3, true);
    for (let v = 1; v <= 5; v++) seedArchive(v, [1]);

    const result = await rollbackNovelToVersion(NOVEL_ID, 1);
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    // Восстановлено содержимое v1 (одна глава), несмотря на вытеснение файла v1.
    expect(extractChaptersFromZip(packPath()).map((c) => c.number)).toEqual([1]);
    const versions = state.archives.map((a) => a.version).sort((a, b) => a - b);
    expect(versions).toEqual([2, 3, 4, 5, 6]);
  });

  it('404-семантика: несуществующая версия → version_not_found', async () => {
    writePack([1]);
    state.novel = {
      id: NOVEL_ID,
      version: 2,
      zipFilename: `${NOVEL_ID}.zip`,
      chaptersCount: 1,
      releasedChapters: 1,
      fileSize: 1,
    };

    const result = await rollbackNovelToVersion(NOVEL_ID, 42);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toBe('version_not_found');
  });

  it('неизвестная новелла → novel_not_found', async () => {
    const result = await rollbackNovelToVersion('nope', 1);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toBe('novel_not_found');
  });
});
