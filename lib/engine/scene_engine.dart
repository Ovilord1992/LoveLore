import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/novel_loader.dart';
import 'variable_engine.dart';
import 'condition_evaluator.dart';

/// Основной провайдер движка игры
final sceneEngineProvider =
    StateNotifierProvider.autoDispose<SceneEngine, GameState?>((ref) {
  return SceneEngine(ref);
});

/// Движок проигрывания сцен
class SceneEngine extends StateNotifier<GameState?> {
  final Ref _ref;
  final VariableEngine _variableEngine = VariableEngine();
  final ConditionEvaluator _conditionEvaluator = ConditionEvaluator();

  Chapter? _currentChapter;
  Scene? _currentScene;
  List<Character> _characters = [];

  SceneEngine(this._ref) : super(null);

  // Геттеры
  Scene? get currentScene => _currentScene;
  Chapter? get currentChapter => _currentChapter;
  List<Character> get characters => _characters;

  SceneEvent? get currentEvent {
    if (_currentScene == null || state == null) return null;
    final idx = state!.currentEventIndex;
    if (idx >= _currentScene!.events.length) return null;
    return _currentScene!.events[idx];
  }

  bool get hasNextEvent {
    if (_currentScene == null || state == null) return false;
    return state!.currentEventIndex < _currentScene!.events.length - 1;
  }

  /// Начать новеллу
  Future<void> startNovel(String novelId) async {
    final loader = _ref.read(novelLoaderProvider);
    await loader.loadNovelMeta(novelId);
    _characters = await loader.loadCharacters(novelId);
    _currentChapter = await loader.loadChapter(novelId, 'chapter_1');

    if (_currentChapter == null) return;

    _currentScene = _currentChapter!.getScene(_currentChapter!.firstSceneId);

    final initialVars = await loader.loadInitialVariables(novelId);

    state = GameState.initial(
      novelId: novelId,
      firstChapterId: _currentChapter!.id,
      firstSceneId: _currentChapter!.firstSceneId,
      initialVariables: initialVars,
    );
  }

  /// Загрузить сохранённое состояние
  void loadState(GameState savedState) {
    state = savedState;
  }

  /// Перейти к следующему событию
  void nextEvent() {
    if (state == null || _currentScene == null) return;

    final nextIndex = state!.currentEventIndex + 1;

    if (nextIndex < _currentScene!.events.length) {
      state = state!.copyWith(currentEventIndex: nextIndex);
    } else if (_currentScene!.nextSceneId != null) {
      _goToScene(_currentScene!.nextSceneId!);
    }
  }

  /// Сделать выбор
  void makeChoice(Choice choice) {
    if (state == null) return;

    // Применить эффекты
    state = _variableEngine.applyEffects(state!, choice.effects);

    // Добавить в историю
    final newHistory = List<String>.from(state!.history)
      ..add('${_currentScene!.id}:${choice.text}');
    state = state!.copyWith(history: newHistory);

    // Перейти к следующей сцене
    _goToScene(choice.nextSceneId);
  }

  /// Получить доступные варианты выбора (с учётом условий)
  List<Choice> getAvailableChoices(List<Choice> choices) {
    if (state == null) return choices;
    return choices
        .where((c) => _conditionEvaluator.isChoiceAvailable(c, state!))
        .toList();
  }

  /// Получить персонажа по id
  Character? getCharacter(String characterId) {
    try {
      return _characters.firstWhere((c) => c.id == characterId);
    } catch (_) {
      return null;
    }
  }

  void _goToScene(String sceneId) {
    if (_currentChapter == null) return;

    final scene = _currentChapter!.getScene(sceneId);
    if (scene == null) return;

    _currentScene = scene;
    state = state!.copyWith(
      currentSceneId: sceneId,
      currentEventIndex: 0,
      lastPlayed: DateTime.now(),
    );
  }
}
