/**
 * Тест-режим контента (спека 4.9): пользователь с ролью admin видит
 * неопубликованные новеллы и невыпущенные главы. Роль берётся из БД
 * (optionalAuthMiddleware), а не из клейма токена.
 */

export function isContentAdmin(role: string | undefined): boolean {
  return role === 'admin';
}

export function novelVisible(
  novel: { isPublished: boolean } | null | undefined,
  role: string | undefined
): boolean {
  return !!novel && (novel.isPublished || isContentAdmin(role));
}

export function chapterAccessible(
  chapter: { isReleased: boolean } | null | undefined,
  role: string | undefined
): boolean {
  return !!chapter && (chapter.isReleased || isContentAdmin(role));
}
