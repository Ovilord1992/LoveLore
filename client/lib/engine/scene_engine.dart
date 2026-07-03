import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/novel_loader.dart';
import '../services/novel_api_service.dart';
import '../services/save_service.dart';
import '../services/user_profile_service.dart';
import '../services/achievement_service.dart';
import '../services/locale_service.dart';
import 'variable_engine.dart';
import 'condition_evaluator.dart';

/// Состояние перехода между главами
enum ChapterTransition { none, loading, needsDownload, notReleased, completed, error }

/// Основной провайдер движка игры
final sceneEngineProvider =
    StateNotifierProvider<SceneEngine, GameState?>((ref) {
  return SceneEngine(ref);
});

/// Провайдер состояния перехода между главами
final chapterTransitionProvider = StateProvider<ChapterTransition>(
  (ref) => ChapterTransition.none,
);

/// Движок проигрывания сцен
class SceneEngine extends StateNotifier<GameState?> {
  final Ref _ref;
  final VariableEngine _variableEngine = VariableEngine();
  final ConditionEvaluator _conditionEvaluator = ConditionEvaluator();

  Chapter? _currentChapter;
  Scene? _currentScene;
  List<Character> _characters = [];
  int _nextChapterNumber = 0;
  NovelTranslation? _translation;
  NovelMeta? _novelMeta;
  // Защита от повторного входа в переход между главами (двойные тапы)
  bool _transitioning = false;

  SceneEngine(this._ref) : super(null);

  // Геттеры
  Scene? get currentScene => _currentScene;
  Chapter? get currentChapter => _currentChapter;
  List<Character> get characters => _characters;
  int get nextChapterNumber => _nextChapterNumber;
  NovelTranslation? get translation => _translation;
  NovelMeta? get novelMeta => _novelMeta;

  /// Установить перевод для текущей новеллы
  void setTranslation(NovelTranslation? translation) {
    _translation = translation;
  }

  /// Перезагрузить перевод по текущей локали (смена языка «на лету»).
  /// Без этого запущенная новелла оставалась бы на старом языке до перезапуска.
  Future<void> reloadTranslation() async {
    if (state == null) return;
    final loader = _ref.read(novelLoaderProvider);
    final locale = _ref.read(localeProvider);
    _translation = await loader.loadTranslation(state!.novelId, locale.name);
    // Форсируем ребилд подписчиков (новый инстанс state).
    state = state!.copyWith();
  }

  /// Перевести текст через текущий перевод
  String tr(String? original) {
    if (original == null || original.isEmpty) return original ?? '';
    return _translation?.translate(original) ?? original;
  }

  /// Перевести имя персонажа
  String trCharacter(String characterId, String originalName) {
    return _translation?.translateCharacter(characterId, originalName) ?? originalName;
  }

  /// Индекс текущей сцены в списке сцен главы (для прогресс-бара)
  int get currentSceneIndex {
    if (_currentChapter == null || _currentScene == null) return 0;
    final idx = _currentChapter!.scenes.indexWhere((s) => s.id == _currentScene!.id);
    return idx >= 0 ? idx + 1 : 0;
  }

  /// Общее количество сцен в текущей главе
  int get totalScenes => _currentChapter?.scenes.length ?? 0;

  SceneEvent? get currentEvent {
    if (_currentScene == null || state == null) return null;
    final idx = state!.currentEventIndex;
    if (idx >= _currentScene!.events.length) return null;
    return _currentScene!.events[idx];
  }

  /// Индекс текущего события (для дедупликации авто-переходов в UI)
  int get currentEventIndex => state?.currentEventIndex ?? 0;

  bool get hasNextEvent {
    if (_currentScene == null || state == null) return false;
    return state!.currentEventIndex < _currentScene!.events.length - 1;
  }

  /// Начать новеллу (или продолжить с сохранения)
  Future<void> startNovel(String novelId, {bool forceNew = false}) async {
    // Сбрасываем состояние перехода от предыдущей новеллы, иначе экран
    // «Конец истории»/«Продолжение следует» залипнет на новой новелле.
    _transitioning = false;
    _nextChapterNumber = 0;
    _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.none;

    final loader = _ref.read(novelLoaderProvider);
    _novelMeta = await loader.loadNovelMeta(novelId);
    _characters = await loader.loadCharacters(novelId);

    // Загрузить перевод по текущему языку
    final locale = _ref.read(localeProvider);
    final langCode = locale.name; // ru, en, es, etc.
    _translation = await loader.loadTranslation(novelId, langCode);

    // Попытаться загрузить сохранение
    final saveService = _ref.read(saveServiceProvider.notifier);
    final savedState = forceNew ? null : saveService.loadGame(novelId);

    if (savedState != null) {
      // Восстановить главу и сцену из сохранения
      _currentChapter = await loader.loadChapter(novelId, savedState.currentChapterId);
      if (_currentChapter != null) {
        _currentScene = _currentChapter!.getScene(savedState.currentSceneId);
        if (_currentScene == null) {
          debugPrint(
              '[SceneEngine] Saved scene "${savedState.currentSceneId}" not found '
              'in chapter ${_currentChapter!.id}, falling back to firstSceneId');
          _currentScene = _currentChapter!.getScene(_currentChapter!.firstSceneId);
          if (_currentScene == null) {
            debugPrint(
                '[SceneEngine] firstSceneId "${_currentChapter!.firstSceneId}" '
                'also missing in chapter ${_currentChapter!.id}; staying at null');
          }
        }
        // Если использовался fallback — синхронизируем currentSceneId/currentEventIndex
        // в state, иначе автосейв перепишет save со старой невалидной sceneId.
        if (_currentScene != null && _currentScene!.id != savedState.currentSceneId) {
          state = savedState.copyWith(
            currentSceneId: _currentScene!.id,
            currentEventIndex: 0,
          );
        } else {
          state = savedState;
        }
        return;
      }
    }

    // Новая игра
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

    // Статистика: новая новелла начата
    _ref.read(userProfileProvider.notifier).incrementNovelsStarted();
    _ref.read(achievementServiceProvider).checkAndGrant();
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
    } else {
      // Конец главы — переход к следующей.
      // Guard от повторного входа: без него быстрые тапы на последнем событии
      // многократно накручивают статистику и запускают гонку сетевых запросов.
      if (_transitioning) return;
      _transitioning = true;
      _ref.read(userProfileProvider.notifier).incrementChaptersRead();
      _ref.read(achievementServiceProvider).checkAndGrant();
      _goToNextChapter();
    }
  }

  /// Установить переменную из события setVariable (поддерживает "+N"/"-N"/"toggle"/значение)
  void applySetVariable(String? variable, dynamic value) {
    if (state == null || variable == null || variable.isEmpty) return;
    state = _variableEngine.applyEffects(state!, {variable: value});
  }

  /// Повторить проверку следующей главы после сетевой ошибки (из UI)
  Future<void> retryNextChapter() async {
    if (state == null || _currentChapter == null) return;
    _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.loading;
    _transitioning = true;
    await _goToNextChapter();
  }

  /// Перейти к следующей главе
  Future<void> _goToNextChapter() async {
    if (state == null || _currentChapter == null) {
      _transitioning = false;
      return;
    }

    _nextChapterNumber = _currentChapter!.number + 1;
    final nextChapterId = 'chapter_$_nextChapterNumber';

    final transition = _ref.read(chapterTransitionProvider.notifier);
    try {
      final loader = _ref.read(novelLoaderProvider);

      // Пробуем загрузить локально
      final nextChapter = await loader.loadChapter(state!.novelId, nextChapterId);

      if (nextChapter != null) {
        _currentChapter = nextChapter;
        _currentScene = nextChapter.getScene(nextChapter.firstSceneId);
        state = state!.copyWith(
          currentChapterId: nextChapterId,
          currentSceneId: nextChapter.firstSceneId,
          currentEventIndex: 0,
          lastPlayed: DateTime.now(),
        );
        transition.state = ChapterTransition.none;
        return;
      }

      // Главы нет локально — проверяем на сервере
      final api = _ref.read(novelApiServiceProvider);
      final chapters = await api.fetchChaptersList(state!.novelId);

      // null → сеть/сервер недоступны. НЕ трактуем как конец истории, иначе
      // офлайн-игрок увидит ложный «Конец истории» и испортит novelsCompleted.
      if (chapters == null) {
        transition.state = ChapterTransition.error;
        return;
      }

      final serverChapter =
          chapters.where((c) => c.number == _nextChapterNumber).firstOrNull;

      if (serverChapter == null) {
        // Главы действительно нет — конец новеллы
        transition.state = ChapterTransition.completed;
        _ref.read(userProfileProvider.notifier).incrementNovelsCompleted();
        _ref.read(achievementServiceProvider).checkAndGrant();
        return;
      }

      if (!serverChapter.isReleased) {
        // Глава не вышла ещё
        transition.state = ChapterTransition.notReleased;
        return;
      }

      // Глава вышла, нужно скачать
      transition.state = ChapterTransition.needsDownload;
    } finally {
      _transitioning = false;
    }
  }

  /// Скачать и начать следующую главу (вызывается из UI)
  Future<bool> downloadAndStartNextChapter() async {
    if (state == null) return false;

    _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.loading;

    final api = _ref.read(novelApiServiceProvider);
    final success = await api.downloadChapter(state!.novelId, _nextChapterNumber);

    if (!success) {
      _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.needsDownload;
      return false;
    }

    // Загружаем скачанную главу
    final loader = _ref.read(novelLoaderProvider);
    final nextChapterId = 'chapter_$_nextChapterNumber';
    final nextChapter = await loader.loadChapter(state!.novelId, nextChapterId);

    if (nextChapter == null) {
      _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.needsDownload;
      return false;
    }

    _currentChapter = nextChapter;
    _currentScene = nextChapter.getScene(nextChapter.firstSceneId);
    state = state!.copyWith(
      currentChapterId: nextChapterId,
      currentSceneId: nextChapter.firstSceneId,
      currentEventIndex: 0,
      lastPlayed: DateTime.now(),
    );
    _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.none;
    return true;
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
