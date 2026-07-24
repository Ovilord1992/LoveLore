import 'package:flutter_test/flutter_test.dart';
import 'package:navell/engine/condition_evaluator.dart';
import 'package:navell/models/game_state.dart';
import 'package:navell/models/scene.dart';

GameState _state(Map<String, dynamic> vars) => GameState(
      novelId: 'n1',
      currentChapterId: 'chapter_1',
      currentSceneId: 's1',
      variables: vars,
      lastPlayed: DateTime(2026, 1, 1),
    );

void main() {
  final evaluator = ConditionEvaluator();

  group('ConditionEvaluator.evaluate — все операторы', () {
    test('==', () {
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '==', value: 5),
          _state({'love': 5}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'met', operator: '==', value: true),
          _state({'met': true}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '==', value: 5),
          _state({'love': 4}),
        ),
        isFalse,
      );
    });

    test('!=', () {
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '!=', value: 5),
          _state({'love': 4}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '!=', value: 5),
          _state({'love': 5}),
        ),
        isFalse,
      );
    });

    test('>=', () {
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '>=', value: 5),
          _state({'love': 5}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '>=', value: 5),
          _state({'love': 6}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '>=', value: 5),
          _state({'love': 4}),
        ),
        isFalse,
      );
    });

    test('<=', () {
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '<=', value: 5),
          _state({'love': 5}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '<=', value: 5),
          _state({'love': 6}),
        ),
        isFalse,
      );
    });

    test('>', () {
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '>', value: 5),
          _state({'love': 6}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '>', value: 5),
          _state({'love': 5}),
        ),
        isFalse,
      );
    });

    test('<', () {
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '<', value: 5),
          _state({'love': 4}),
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          const Condition(variable: 'love', operator: '<', value: 5),
          _state({'love': 5}),
        ),
        isFalse,
      );
    });

    test('отсутствующая переменная — false', () {
      expect(
        evaluator.evaluate(
          const Condition(variable: 'missing', operator: '>=', value: 0),
          _state({}),
        ),
        isFalse,
      );
    });
  });

  group('Составные условия (and/or)', () {
    const c1 = Condition(variable: 'love', operator: '>=', value: 10);
    const c2 = Condition(variable: 'brave', operator: '>', value: 3);

    test('and: все должны выполниться', () {
      expect(
        evaluator.evaluateAll(
            [c1, c2], 'and', null, _state({'love': 10, 'brave': 4})),
        isTrue,
      );
      expect(
        evaluator.evaluateAll(
            [c1, c2], 'and', null, _state({'love': 10, 'brave': 3})),
        isFalse,
      );
    });

    test('and — по умолчанию (logic == null)', () {
      expect(
        evaluator.evaluateAll(
            [c1, c2], null, null, _state({'love': 10, 'brave': 2})),
        isFalse,
      );
      expect(
        evaluator.evaluateAll(
            [c1, c2], null, null, _state({'love': 10, 'brave': 4})),
        isTrue,
      );
    });

    test('or: достаточно одного', () {
      expect(
        evaluator.evaluateAll(
            [c1, c2], 'or', null, _state({'love': 0, 'brave': 4})),
        isTrue,
      );
      expect(
        evaluator.evaluateAll(
            [c1, c2], 'or', null, _state({'love': 0, 'brave': 0})),
        isFalse,
      );
    });
  });

  group('isChoiceAvailable', () {
    test('легаси одиночное condition работает', () {
      const choice = Choice(
        text: 't',
        nextSceneId: 's2',
        condition: Condition(variable: 'love', operator: '>=', value: 5),
      );
      expect(evaluator.isChoiceAvailable(choice, _state({'love': 5})), isTrue);
      expect(evaluator.isChoiceAvailable(choice, _state({'love': 4})), isFalse);
    });

    test('без условий — всегда доступен', () {
      const choice = Choice(text: 't', nextSceneId: 's2');
      expect(evaluator.isChoiceAvailable(choice, _state({})), isTrue);
    });

    test('приоритет conditions[] над легаси condition', () {
      // Легаси провалилось бы, но conditions[] выполняется → приоритет у него
      const choice = Choice(
        text: 't',
        nextSceneId: 's2',
        condition: Condition(variable: 'love', operator: '>=', value: 100),
        conditions: [Condition(variable: 'brave', operator: '>', value: 1)],
      );
      expect(
        evaluator.isChoiceAvailable(choice, _state({'love': 0, 'brave': 2})),
        isTrue,
      );
      // И наоборот: conditions[] провалились — легаси не спасает
      expect(
        evaluator.isChoiceAvailable(choice, _state({'love': 100, 'brave': 0})),
        isFalse,
      );
    });
  });
}
