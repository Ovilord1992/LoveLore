import '../models/scene.dart';
import '../models/game_state.dart';

/// Evaluates conditions against game state variables
class ConditionEvaluator {
  /// Проверяет, выполнено ли условие
  bool evaluate(Condition condition, GameState state) {
    final actual = state.variables[condition.variable];
    final expected = condition.value;

    if (actual == null) return false;

    switch (condition.operator) {
      case '==':
        return actual == expected;
      case '!=':
        return actual != expected;
      case '>=':
        return _toNum(actual) >= _toNum(expected);
      case '<=':
        return _toNum(actual) <= _toNum(expected);
      case '>':
        return _toNum(actual) > _toNum(expected);
      case '<':
        return _toNum(actual) < _toNum(expected);
      default:
        return false;
    }
  }

  /// v2: проверка набора условий с логикой and/or.
  ///
  /// Приоритет: непустой [conditions] → одиночное [legacy] → true (нет условий).
  /// [logic]: "or" — достаточно одного; иначе (включая null/"and") — все.
  bool evaluateAll(
    List<Condition>? conditions,
    String? logic,
    Condition? legacy,
    GameState state,
  ) {
    if (conditions != null && conditions.isNotEmpty) {
      final isOr = (logic ?? 'and').toLowerCase() == 'or';
      if (isOr) {
        return conditions.any((c) => evaluate(c, state));
      }
      return conditions.every((c) => evaluate(c, state));
    }
    if (legacy != null) return evaluate(legacy, state);
    return true;
  }

  /// Проверяет, доступен ли выбор (v2: conditions[] приоритетнее condition)
  bool isChoiceAvailable(Choice choice, GameState state) {
    return evaluateAll(
      choice.conditions,
      choice.conditionsLogic,
      choice.condition,
      state,
    );
  }

  /// Проверяет, срабатывает ли ветка branches
  bool branchMatches(SceneBranch branch, GameState state) {
    return evaluateAll(
      branch.conditions,
      branch.conditionsLogic,
      branch.condition,
      state,
    );
  }

  /// v2: резолв перехода в конце сцены — первая сработавшая ветка
  /// [Scene.branches], иначе [Scene.nextSceneId], иначе null (конец главы).
  String? resolveNextSceneId(Scene scene, GameState state) {
    final branches = scene.branches;
    if (branches != null) {
      for (final branch in branches) {
        if (branchMatches(branch, state)) return branch.nextSceneId;
      }
    }
    return scene.nextSceneId;
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }
}
