import 'package:flutter_test/flutter_test.dart';
import 'package:navell/engine/variable_engine.dart';
import 'package:navell/models/game_state.dart';

GameState _state(Map<String, dynamic> vars) => GameState(
      novelId: 'n1',
      currentChapterId: 'chapter_1',
      currentSceneId: 's1',
      variables: vars,
      lastPlayed: DateTime(2026, 1, 1),
    );

void main() {
  final engine = VariableEngine();

  group('VariableEngine.applyEffects', () {
    test('инкремент "+N"', () {
      final result = engine.applyEffects(_state({'love': 2}), {'love': '+3'});
      expect(result.variables['love'], 5);
    });

    test('инкремент от отсутствующей переменной — от нуля', () {
      final result = engine.applyEffects(_state({}), {'love': '+2'});
      expect(result.variables['love'], 2);
    });

    test('декремент "-N"', () {
      final result = engine.applyEffects(_state({'love': 5}), {'love': '-2'});
      expect(result.variables['love'], 3);
    });

    test('toggle: false → true → false', () {
      var result = engine.applyEffects(_state({}), {'met': 'toggle'});
      expect(result.variables['met'], isTrue);
      result = engine.applyEffects(result, {'met': 'toggle'});
      expect(result.variables['met'], isFalse);
    });

    test('прямое присвоение (число, строка, bool)', () {
      final result = engine.applyEffects(_state({'love': 1}), {
        'love': 10,
        'route': 'mia',
        'met': true,
      });
      expect(result.variables['love'], 10);
      expect(result.variables['route'], 'mia');
      expect(result.variables['met'], isTrue);
    });

    test('null/пустые эффекты не меняют состояние', () {
      final initial = _state({'love': 1});
      expect(engine.applyEffects(initial, null), same(initial));
      expect(engine.applyEffects(initial, {}), same(initial));
    });

    test('несколько эффектов за раз', () {
      final result = engine.applyEffects(_state({'a': 1, 'b': 5}), {
        'a': '+1',
        'b': '-2',
      });
      expect(result.variables['a'], 2);
      expect(result.variables['b'], 3);
    });
  });
}
