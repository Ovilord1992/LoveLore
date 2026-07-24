/**
 * Парсинг пагинации каталога (спека 2.5): с параметром `page` — envelope
 * { items, total, page, limit }; без параметров — легаси-массив с капом 200.
 */

export const LEGACY_CATALOG_CAP = 200;
export const MAX_CATALOG_LIMIT = 200;
export const DEFAULT_CATALOG_LIMIT = 50;

export interface CatalogPaging {
  paginated: boolean;
  page: number;
  limit: number;
  skip: number;
  take: number;
}

export function parseCatalogPaging(query: { page?: unknown; limit?: unknown }): CatalogPaging {
  if (query.page === undefined) {
    return { paginated: false, page: 1, limit: LEGACY_CATALOG_CAP, skip: 0, take: LEGACY_CATALOG_CAP };
  }
  const page = Math.max(1, parseInt(String(query.page), 10) || 1);
  const limit = Math.min(
    MAX_CATALOG_LIMIT,
    Math.max(1, parseInt(String(query.limit), 10) || DEFAULT_CATALOG_LIMIT)
  );
  return { paginated: true, page, limit, skip: (page - 1) * limit, take: limit };
}
