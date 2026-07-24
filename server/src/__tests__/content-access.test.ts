/**
 * Тест-режим контента (спека 4.9): админ видит неопубликованное/невыпущенное,
 * обычный пользователь и аноним — нет. Плюс секция links конфига (спека 4.10).
 */
import { describe, it, expect } from 'vitest';
import { isContentAdmin, novelVisible, chapterAccessible } from '../utils/content-access';
import { validateGameConfigInput } from '../config/schema';

describe('content-access — роли', () => {
  it('admin — контент-админ; user/аноним — нет', () => {
    expect(isContentAdmin('admin')).toBe(true);
    expect(isContentAdmin('user')).toBe(false);
    expect(isContentAdmin(undefined)).toBe(false);
  });
});

describe('content-access — видимость новеллы', () => {
  it('опубликованная видна всем', () => {
    expect(novelVisible({ isPublished: true }, undefined)).toBe(true);
    expect(novelVisible({ isPublished: true }, 'user')).toBe(true);
  });

  it('неопубликованная видна только админу', () => {
    expect(novelVisible({ isPublished: false }, 'admin')).toBe(true);
    expect(novelVisible({ isPublished: false }, 'user')).toBe(false);
    expect(novelVisible({ isPublished: false }, undefined)).toBe(false);
  });

  it('null-новелла не видна никому, включая админа', () => {
    expect(novelVisible(null, 'admin')).toBe(false);
    expect(novelVisible(undefined, undefined)).toBe(false);
  });
});

describe('content-access — доступ к главе', () => {
  it('выпущенная глава доступна всем', () => {
    expect(chapterAccessible({ isReleased: true }, undefined)).toBe(true);
  });

  it('невыпущенная — только админу', () => {
    expect(chapterAccessible({ isReleased: false }, 'admin')).toBe(true);
    expect(chapterAccessible({ isReleased: false }, 'user')).toBe(false);
    expect(chapterAccessible({ isReleased: false }, undefined)).toBe(false);
  });

  it('отсутствующая глава недоступна и админу', () => {
    expect(chapterAccessible(null, 'admin')).toBe(false);
  });
});

describe('config — секция links (спека 4.10)', () => {
  it('валидные URL и пустые строки проходят', () => {
    const r = validateGameConfigInput({
      links: { privacyPolicyUrl: 'https://amoria.app/privacy', termsUrl: '' },
    });
    expect(r.ok).toBe(true);
  });

  it('не-URL отклоняется с ошибкой по секции links', () => {
    const r = validateGameConfigInput({ links: { privacyPolicyUrl: 'not a url' } });
    expect(r.ok).toBe(false);
    if (!r.ok) {
      expect(r.errors.some((e) => e.section === 'links')).toBe(true);
    }
  });

  it('неизвестные ключи внутри links не отклоняются (passthrough)', () => {
    const r = validateGameConfigInput({
      links: { privacyPolicyUrl: 'https://a.b/p', supportUrl: 'https://a.b/s' },
    });
    expect(r.ok).toBe(true);
  });
});
