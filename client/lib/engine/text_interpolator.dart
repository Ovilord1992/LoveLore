/// Интерполяция плейсхолдеров в текстах новеллы (спека 1.4).
///
/// Поддерживаются:
/// - `{name}` — имя игрока. Цепочка: переменная `player_name` →
///   `displayName` профиля → `meta.playerNamePrompt.defaultName` → «Ты».
/// - `{var:key}` — значение переменной `key` (целые числа без дробной части).
///
/// ВАЖНО: применяется ПОСЛЕ перевода — ключи переводов содержат
/// плейсхолдеры как есть.
class TextInterpolator {
  static final RegExp _varPattern = RegExp(r'\{var:([^}]+)\}');

  const TextInterpolator._();

  /// Разрешить имя игрока по цепочке из спеки 1.4.
  static String resolvePlayerName({
    Map<String, dynamic> variables = const {},
    String? profileName,
    String? promptDefaultName,
  }) {
    final fromVar = variables['player_name'];
    if (fromVar is String && fromVar.trim().isNotEmpty) return fromVar.trim();
    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }
    if (promptDefaultName != null && promptDefaultName.trim().isNotEmpty) {
      return promptDefaultName.trim();
    }
    return 'Ты';
  }

  /// Применить интерполяцию к тексту.
  static String interpolate(
    String text, {
    Map<String, dynamic> variables = const {},
    String? profileName,
    String? promptDefaultName,
  }) {
    if (text.isEmpty || !text.contains('{')) return text;

    var result = text;

    if (result.contains('{name}')) {
      final name = resolvePlayerName(
        variables: variables,
        profileName: profileName,
        promptDefaultName: promptDefaultName,
      );
      result = result.replaceAll('{name}', name);
    }

    result = result.replaceAllMapped(_varPattern, (match) {
      final key = match.group(1)!;
      return formatValue(variables[key]);
    });

    return result;
  }

  /// Отформатировать значение переменной: целые числа — без «.0»,
  /// отсутствующая переменная — пустая строка.
  static String formatValue(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      if (value is int) return value.toString();
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toString();
    }
    return value.toString();
  }
}
