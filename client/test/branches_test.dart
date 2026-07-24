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

  const branchMia = SceneBranch(
    conditions: [Condition(variable: 'love_mia', operator: '>=', value: 20)],
    nextSceneId: 'scene_mia_route',
  );
  const branchBrave = SceneBranch(
    conditions: [Condition(variable: 'brave', operator: '>', value: 3)],
    nextSceneId: 'scene_brave_route',
  );

  group('resolveNextSceneId (branches, спека 1.2)', () {
    test('первый сработавший branch по порядку', () {
      const scene = Scene(
        id: 's',
        branches: [branchMia, branchBrave],
        nextSceneId: 'scene_default',
      );
      // Оба подходят — берётся ПЕРВЫЙ
      expect(
        evaluator.resolveNextSceneId(
            scene, _state({'love_mia': 25, 'brave': 5})),
        'scene_mia_route',
      );
      // Первый не подходит — берётся второй
      expect(
        evaluator.resolveNextSceneId(
            scene, _state({'love_mia': 5, 'brave': 5})),
        'scene_brave_route',
      );
    });

    test('ни один branch не сработал → фолбэк на scene.nextSceneId', () {
      const scene = Scene(
        id: 's',
        branches: [branchMia, branchBrave],
        nextSceneId: 'scene_default',
      );
      expect(
        evaluator.resolveNextSceneId(scene, _state({'love_mia': 0, 'brave': 0})),
        'scene_default',
      );
    });

    test('нет branches и нет nextSceneId → null (конец главы)', () {
      const scene = Scene(id: 's');
      expect(evaluator.resolveNextSceneId(scene, _state({})), isNull);
    });

    test('branches есть, nextSceneId нет, ничего не сработало → null', () {
      const scene = Scene(id: 's', branches: [branchMia]);
      expect(
        evaluator.resolveNextSceneId(scene, _state({'love_mia': 1})),
        isNull,
      );
    });

    test('branch с conditionsLogic or', () {
      const scene = Scene(
        id: 's',
        branches: [
          SceneBranch(
            conditions: [
              Condition(variable: 'a', operator: '>=', value: 1),
              Condition(variable: 'b', operator: '>=', value: 1),
            ],
            conditionsLogic: 'or',
            nextSceneId: 'scene_or',
          ),
        ],
        nextSceneId: 'scene_default',
      );
      expect(
        evaluator.resolveNextSceneId(scene, _state({'a': 0, 'b': 1})),
        'scene_or',
      );
      expect(
        evaluator.resolveNextSceneId(scene, _state({'a': 0, 'b': 0})),
        'scene_default',
      );
    });

    test('легаси одиночное condition на ветке', () {
      const scene = Scene(
        id: 's',
        branches: [
          SceneBranch(
            condition: Condition(variable: 'x', operator: '==', value: 1),
            nextSceneId: 'scene_x',
          ),
        ],
      );
      expect(
        evaluator.resolveNextSceneId(scene, _state({'x': 1})),
        'scene_x',
      );
    });

    test('branches сериализуются из JSON сцены', () {
      final scene = Scene.fromJson({
        'id': 'scene_party_end',
        'events': <dynamic>[],
        'branches': [
          {
            'conditions': [
              {'variable': 'love_mia', 'operator': '>=', 'value': 20},
            ],
            'conditionsLogic': 'and',
            'nextSceneId': 'scene_mia_route',
          },
        ],
        'nextSceneId': 'scene_default_route',
      });
      expect(scene.branches, hasLength(1));
      expect(
        evaluator.resolveNextSceneId(scene, _state({'love_mia': 30})),
        'scene_mia_route',
      );
      expect(
        evaluator.resolveNextSceneId(scene, _state({'love_mia': 0})),
        'scene_default_route',
      );
    });
  });
}
