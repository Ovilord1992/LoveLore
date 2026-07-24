import type { Choice, Condition, ConditionsLogic, NovelMeta, SceneBranch } from '../types/novel';

export type Vars = Record<string, string | number | boolean>;

function toNum(value: unknown): number {
  if (typeof value === 'number') return value;
  if (typeof value === 'boolean') return value ? 1 : 0;
  if (typeof value === 'string') {
    const n = Number(value);
    return isNaN(n) ? 0 : n;
  }
  return 0;
}

/** Порт client/lib/engine/condition_evaluator.dart: одно условие.
 *  Для bool-значений ==/!= сравнивают истинность, численные операторы
 *  работают через приведение к числу (true=1, false=0). */
export function evaluateCondition(vars: Vars, cond: Condition): boolean {
  const raw = vars[cond.variable];
  if (typeof cond.value === 'boolean') {
    const b = typeof raw === 'boolean' ? raw : toNum(raw) !== 0;
    switch (cond.operator) {
      case '==': return b === cond.value;
      case '!=': return b !== cond.value;
      default: return evaluateNumeric(toNum(raw), cond.operator, toNum(cond.value));
    }
  }
  return evaluateNumeric(toNum(raw), cond.operator, cond.value);
}

function evaluateNumeric(value: number, op: Condition['operator'], target: number): boolean {
  switch (op) {
    case '>=': return value >= target;
    case '<=': return value <= target;
    case '==': return value === target;
    case '!=': return value !== target;
    case '>': return value > target;
    case '<': return value < target;
    default: return true;
  }
}

/** Составные условия (формат v2 1.1): "and" (дефолт) | "or".
 *  Пустой массив условий трактуется как «всегда истинно». */
export function evaluateConditions(
  vars: Vars,
  conditions: Condition[] | undefined,
  logic: ConditionsLogic | undefined,
): boolean {
  if (!conditions || conditions.length === 0) return true;
  return logic === 'or'
    ? conditions.some((c) => evaluateCondition(vars, c))
    : conditions.every((c) => evaluateCondition(vars, c));
}

/** Видимость варианта выбора: приоритет у `conditions`, легаси `condition`
 *  работает, если массива нет (формат v2 1.1). */
export function isChoiceVisible(vars: Vars, choice: Choice): boolean {
  if (choice.conditions && choice.conditions.length > 0) {
    return evaluateConditions(vars, choice.conditions, choice.conditionsLogic);
  }
  if (choice.condition) return evaluateCondition(vars, choice.condition);
  return true;
}

/** Выбрать сработавшую ветку (формат v2 1.2): первая по порядку. */
export function pickBranch(vars: Vars, branches: SceneBranch[] | undefined): SceneBranch | undefined {
  if (!branches) return undefined;
  return branches.find((b) => evaluateConditions(vars, b.conditions, b.conditionsLogic));
}

/** Порт variable_engine.dart для превью:
 *  "+N"/"-N" — инкремент/декремент числа, "toggle" — инверсия bool,
 *  иначе — прямое присвоение. */
export function applyEffects(variables: Vars, effects?: Vars): Vars {
  if (!effects) return variables;
  const next: Vars = { ...variables };
  for (const [key, value] of Object.entries(effects)) {
    if (typeof value === 'string' && (value.startsWith('+') || value.startsWith('-'))) {
      const delta = Number(value);
      next[key] = toNum(next[key]) + (isNaN(delta) ? 0 : delta);
    } else if (value === 'toggle') {
      next[key] = !(typeof next[key] === 'boolean' ? next[key] : false);
    } else {
      next[key] = value;
    }
  }
  return next;
}

/** Интерполяция текста (формат v2 1.4): {name} и {var:key}.
 *  Выполняется ПОСЛЕ перевода (ключи переводов содержат плейсхолдеры как есть).
 *  Цепочка имени: player_name → testName (превью) → meta.playerNamePrompt.defaultName → "Ты". */
export function interpolate(
  text: string,
  vars: Vars,
  meta: NovelMeta,
  testName?: string,
): string {
  const playerName =
    (typeof vars['player_name'] === 'string' && (vars['player_name'] as string).trim())
      ? String(vars['player_name'])
      : (testName && testName.trim())
        ? testName
        : (meta.playerNamePrompt?.defaultName?.trim() ? meta.playerNamePrompt.defaultName : 'Ты');

  return text
    .replace(/\{name\}/g, playerName)
    .replace(/\{var:([^}]+)\}/g, (_, key: string) => {
      const v = vars[key.trim()];
      if (v === undefined) return '';
      if (typeof v === 'number') return Number.isInteger(v) ? String(v) : String(v);
      return String(v);
    });
}

/** Короткая подпись условия для рёбер графа/списков: "love>=10". */
export function conditionSummary(conditions: Condition[] | undefined, logic?: ConditionsLogic): string {
  if (!conditions || conditions.length === 0) return 'всегда';
  const glue = logic === 'or' ? ' | ' : ' & ';
  return conditions
    .map((c) => `${c.variable || '?'}${c.operator}${String(c.value)}`)
    .join(glue);
}
