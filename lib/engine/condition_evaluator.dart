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

  /// Проверяет, доступен ли выбор
  bool isChoiceAvailable(Choice choice, GameState state) {
    if (choice.condition == null) return true;
    return evaluate(choice.condition!, state);
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }
}
