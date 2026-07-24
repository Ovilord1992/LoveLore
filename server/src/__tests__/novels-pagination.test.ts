/**
 * Тесты пагинации каталога (спека 2.5): envelope при наличии ?page,
 * легаси-ответ с капом 200 без параметров.
 */
import { describe, it, expect } from 'vitest';
import {
  parseCatalogPaging,
  LEGACY_CATALOG_CAP,
  MAX_CATALOG_LIMIT,
  DEFAULT_CATALOG_LIMIT,
} from '../utils/pagination';

describe('Catalog paging — легаси-режим (без page)', () => {
  it('без параметров: не пагинирован, кап 200', () => {
    const p = parseCatalogPaging({});
    expect(p.paginated).toBe(false);
    expect(p.take).toBe(LEGACY_CATALOG_CAP);
    expect(p.skip).toBe(0);
  });

  it('limit без page игнорируется (легаси-клиенты не шлют limit)', () => {
    const p = parseCatalogPaging({ limit: '10' });
    expect(p.paginated).toBe(false);
    expect(p.take).toBe(LEGACY_CATALOG_CAP);
  });
});

describe('Catalog paging — envelope-режим (?page)', () => {
  it('page=1 без limit → дефолтный limit', () => {
    const p = parseCatalogPaging({ page: '1' });
    expect(p.paginated).toBe(true);
    expect(p.page).toBe(1);
    expect(p.limit).toBe(DEFAULT_CATALOG_LIMIT);
    expect(p.skip).toBe(0);
  });

  it('page=3&limit=50 → skip 100', () => {
    const p = parseCatalogPaging({ page: '3', limit: '50' });
    expect(p.page).toBe(3);
    expect(p.limit).toBe(50);
    expect(p.skip).toBe(100);
    expect(p.take).toBe(50);
  });

  it('limit клампится сверху', () => {
    const p = parseCatalogPaging({ page: '1', limit: '5000' });
    expect(p.limit).toBe(MAX_CATALOG_LIMIT);
  });

  it('кривые значения нормализуются', () => {
    const p = parseCatalogPaging({ page: 'abc', limit: '-5' });
    expect(p.paginated).toBe(true);
    expect(p.page).toBe(1);
    expect(p.limit).toBeGreaterThanOrEqual(1);
  });

  it('page=0 нормализуется к 1', () => {
    const p = parseCatalogPaging({ page: '0' });
    expect(p.page).toBe(1);
    expect(p.skip).toBe(0);
  });
});
