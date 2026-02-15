import '../models/game_state.dart';

/// Управляет переменными игрового состояния
class VariableEngine {
  /// Применяет эффекты выбора к состоянию
  GameState applyEffects(GameState state, Map<String, dynamic>? effects) {
    if (effects == null || effects.isEmpty) return state;

    final newVars = Map<String, dynamic>.from(state.variables);

    for (final entry in effects.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String && (value.startsWith('+') || value.startsWith('-'))) {
        // Инкремент/декремент: "+3", "-1"
        final delta = num.tryParse(value) ?? 0;
        final current = _toNum(newVars[key]);
        newVars[key] = current + delta;
      } else if (value is String && value == 'toggle') {
        // Переключение boolean
        newVars[key] = !(newVars[key] as bool? ?? false);
      } else {
        // Прямое присвоение
        newVars[key] = value;
      }
    }

    return state.copyWith(variables: newVars);
  }

  /// Инициализирует переменные из конфига новеллы
  GameState initializeVariables(
      GameState state, Map<String, dynamic> defaults) {
    final newVars = Map<String, dynamic>.from(defaults);
    newVars.addAll(state.variables); // существующие значения имеют приоритет
    return state.copyWith(variables: newVars);
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }
}
