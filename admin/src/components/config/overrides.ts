/** Строка списка overrides: dot-путь → значение (строковое представление). */
export interface OverrideRow {
  uid: number;
  k: string;
  v: string;
}

// Сквозной счётчик uid (модульный — общий для всех редакторов, чтобы ключи не пересекались)
let uidSeq = 1;
export const takeOverrideUid = () => uidSeq++;

/**
 * Автопарс значения override: числа, true/false/null и JSON (объекты/массивы/строки
 * в кавычках) распознаются; всё остальное — обычная строка.
 */
export const parseOverrideValue = (raw: string): unknown => {
  const s = raw.trim();
  if (s === '') return '';
  if (/^(true|false|null)$/.test(s) || /^-?\d+(\.\d+)?([eE][+-]?\d+)?$/.test(s) || /^["[{]/.test(s)) {
    try {
      return JSON.parse(s);
    } catch {
      return raw;
    }
  }
  return raw;
};

/** Обратное преобразование для отображения: строки — как есть, остальное — JSON. */
export const displayOverrideValue = (v: unknown): string => {
  if (v === undefined) return '';
  if (typeof v === 'string') {
    // Строка, которая распарсилась бы как число/bool/JSON, показывается в кавычках —
    // иначе при сохранении она поменяла бы тип.
    return parseOverrideValue(v) === v ? v : JSON.stringify(v);
  }
  return JSON.stringify(v);
};

/** Объект overrides → строки редактора */
export const overridesToRows = (overrides: unknown): OverrideRow[] => {
  const obj = overrides && typeof overrides === 'object' && !Array.isArray(overrides)
    ? (overrides as Record<string, unknown>)
    : {};
  return Object.entries(obj).map(([k, v]) => ({ uid: takeOverrideUid(), k, v: displayOverrideValue(v) }));
};

/** Строки редактора → объект overrides (пустые ключи отбрасываются) */
export const rowsToOverrides = (rows: OverrideRow[]): Record<string, unknown> => {
  const out: Record<string, unknown> = {};
  for (const r of rows) {
    const key = r.k.trim();
    if (key) out[key] = parseOverrideValue(r.v);
  }
  return out;
};
