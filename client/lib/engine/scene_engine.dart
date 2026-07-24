import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/analytics_service.dart';
import '../services/novel_loader.dart';
import '../services/novel_api_service.dart';
import '../services/reading_progress_service.dart';
import '../services/save_service.dart';
import '../services/user_profile_service.dart';
import '../services/achievement_service.dart';
import '../services/locale_service.dart';
import '../services/wardrobe_service.dart';
import 'variable_engine.dart';
import 'condition_evaluator.dart';
import 'text_interpolator.dart';

/// Состояние перехода между главами
enum ChapterTransition {
  none,
  loading,
  needsDownload,
  notReleased,
  completed,
  error,
  // v2: достигнута концовка — показать экран концовки
  ending,
}

/// Основной провайдер движка игры
final sceneEngineProvider =
    StateNotifierProvider<SceneEngine, GameState?>((ref) {
  return SceneEngine(ref);
});

/// Провайдер состояния перехода между главами
final chapterTransitionProvider = StateProvider<ChapterTransition>(
  (ref) => ChapterTransition.none,
);

/// Уведомление об изменении стата (для toast-оверлея «+1 ♥ Мия»)
class StatChangeNotice {
  final String variable;
  final String label;
  final String? icon; // heart | star | flame | diamond | moon | sun | leaf
  final String? color; // HEX
  final num delta;
  final num newValue;

  const StatChangeNotice({
    required this.variable,
    required this.label,
    this.icon,
    this.color,
    required this.delta,
    required this.newValue,
  });
}

/// Последний батч изменений статов (game_screen показывает toast и очищает)
final statChangesProvider =
    StateProvider<List<StatChangeNotice>>((ref) => const []);

/// Движок проигрывания сцен
class SceneEngine extends StateNotifier<GameState?> {
  final Ref _ref;
  final VariableEngine _variableEngine = VariableEngine();
  final ConditionEvaluator _conditionEvaluator = ConditionEvaluator();

  /// Кап истории реплик (backlog)
  static const int backlogCap = 200;

  Chapter? _currentChapter;
  Scene? _currentScene;
  List<Character> _characters = [];
  int _nextChapterNumber = 0;
  NovelTranslation? _translation;
  NovelMeta? _novelMeta;
  // Защита от повторного входа в переход между главами (двойные тапы)
  bool _transitioning = false;

  // v2: активная концовка (для экрана концовки)
  SceneEnding? _activeEnding;

  // v2: ожидающий показа рекап главы («Ранее…»)
  String? _pendingRecap;

  // Backlog: история показанных реплик и выборов (in-memory, кап 200)
  final List<BacklogEntry> _backlog = [];
  String? _lastLoggedKey;

  SceneEngine(this._ref) : super(null);

  // Геттеры
  Scene? get currentScene => _currentScene;
  Chapter? get currentChapter => _currentChapter;
  List<Character> get characters => _characters;
  int get nextChapterNumber => _nextChapterNumber;
  NovelTranslation? get translation => _translation;
  NovelMeta? get novelMeta => _novelMeta;
  SceneEnding? get currentEnding => _activeEnding;
  List<BacklogEntry> get backlog => List.unmodifiable(_backlog);

  /// Рекап текущей главы, ожидающий показа (оригинальный текст — переводить
  /// и интерполировать через [trx] на экране)
  String? get pendingRecap => _pendingRecap;

  /// Нужно ли спросить имя игрока (спека 1.4): playerNamePrompt.enabled
  /// и переменная player_name ещё не установлена.
  bool get needsPlayerName {
    if (state == null) return false;
    if (_novelMeta?.playerNamePrompt?.enabled != true) return false;
    final current = state!.variables['player_name'];
    return current is! String || current.trim().isEmpty;
  }

  /// Установить имя игрока (пустое → defaultName из meta)
  void setPlayerName(String name) {
    if (state == null) return;
    final trimmed = name.trim();
    final effective = trimmed.isNotEmpty
        ? trimmed
        : (_novelMeta?.playerNamePrompt?.defaultName ?? 'Ты');
    final vars = Map<String, dynamic>.from(state!.variables);
    vars['player_name'] = effective;
    state = state!.copyWith(variables: vars);
  }

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

  /// Перевод + интерполяция плейсхолдеров ({name}, {var:key}).
  /// Порядок из спеки 1.4: перевод → интерполяция.
  String trx(String? original) {
    final translated = tr(original);
    if (translated.isEmpty) return translated;
    return TextInterpolator.interpolate(
      translated,
      variables: state?.variables ?? const {},
      profileName: _profileDisplayName,
      promptDefaultName: _novelMeta?.playerNamePrompt?.defaultName,
    );
  }

  String? get _profileDisplayName {
    try {
      final name = _ref.read(userProfileProvider).displayName;
      // Дефолтный «Читатель» не считается пользовательским именем
      return name == 'Читатель' ? null : name;
    } catch (_) {
      return null;
    }
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

  /// Прочитано ли текущее событие ранее (для fast-forward)
  bool get isCurrentEventRead {
    if (state == null || _currentScene == null) return false;
    return _ref.read(readingProgressProvider).isRead(
          state!.novelId,
          _currentScene!.id,
          state!.currentEventIndex,
        );
  }

  /// Начать новеллу (или продолжить с сохранения)
  Future<void> startNovel(String novelId, {bool forceNew = false}) async {
    // Сбрасываем состояние перехода от предыдущей новеллы, иначе экран
    // «Конец истории»/«Продолжение следует» залипнет на новой новелле.
    _transitioning = false;
    _nextChapterNumber = 0;
    _activeEnding = null;
    _pendingRecap = null;
    _backlog.clear();
    _lastLoggedKey = null;
    _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.none;

    final loader = _ref.read(novelLoaderProvider);
    _novelMeta = await loader.loadNovelMeta(novelId);
    _characters = await loader.loadCharacters(novelId);

    // Загрузить перевод по текущему языку
    final locale = _ref.read(localeProvider);
    final langCode = locale.name; // ru, en, es, etc.
    _translation = await loader.loadTranslation(novelId, langCode);

    // Попытаться загрузить сохранение: самое свежее из автосейва и слотов
    final saveService = _ref.read(saveServiceProvider.notifier);
    final savedState = forceNew ? null : saveService.loadLatest(novelId);

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
        _maybeSetRecap();
        _logCurrent();
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
    final analytics = _ref.read(analyticsServiceProvider);
    analytics.log('novel_start', {'novelId': novelId});
    analytics.log('chapter_start', {
      'novelId': novelId,
      'chapter': _currentChapter!.number,
    });
    _maybeSetRecap();
    _logCurrent();
  }

  /// Загрузить сохранённое состояние (только state; глава должна совпадать)
  void loadState(GameState savedState) {
    state = savedState;
  }

  /// Восстановить игру из произвольного сохранения (ручные слоты).
  /// Загружает главу/сцену, соответствующие [savedState].
  Future<bool> restoreFromState(GameState savedState) async {
    final loader = _ref.read(novelLoaderProvider);
    final chapter =
        await loader.loadChapter(savedState.novelId, savedState.currentChapterId);
    if (chapter == null) return false;
    var scene = chapter.getScene(savedState.currentSceneId);
    var restored = savedState;
    if (scene == null) {
      scene = chapter.getScene(chapter.firstSceneId);
      if (scene == null) return false;
      restored = savedState.copyWith(
        currentSceneId: scene.id,
        currentEventIndex: 0,
      );
    }
    // Индекс события за пределами сцены (битый сейв) — сбрасываем на 0
    if (restored.currentEventIndex >= scene.events.length &&
        scene.events.isNotEmpty) {
      restored = restored.copyWith(currentEventIndex: 0);
    }
    _transitioning = false;
    _activeEnding = null;
    _pendingRecap = null;
    _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.none;
    _currentChapter = chapter;
    _currentScene = scene;
    state = restored.copyWith(lastPlayed: DateTime.now());
    _lastLoggedKey = null;
    _logCurrent();
    return true;
  }

  /// Перейти к следующему событию
  void nextEvent() {
    if (state == null || _currentScene == null) return;

    final nextIndex = state!.currentEventIndex + 1;

    if (nextIndex < _currentScene!.events.length) {
      state = state!.copyWith(currentEventIndex: nextIndex);
      _logCurrent();
      return;
    }

    // Конец сцены. v2: сцена с ending завершает прохождение (без переходов).
    if (_currentScene!.ending != null) {
      if (_transitioning) return;
      _transitioning = true;
      _reachEnding(_currentScene!.ending!);
      return;
    }

    // v2: branches → первый сработавший, иначе scene.nextSceneId
    final targetSceneId =
        _conditionEvaluator.resolveNextSceneId(_currentScene!, state!);
    if (targetSceneId != null) {
      _goToScene(targetSceneId);
      return;
    }

    // Конец главы — переход к следующей.
    // Guard от повторного входа: без него быстрые тапы на последнем событии
    // многократно накручивают статистику и запускают гонку сетевых запросов.
    if (_transitioning) return;
    _transitioning = true;
    _ref.read(analyticsServiceProvider).log('chapter_complete', {
      'novelId': state!.novelId,
      'chapter': _currentChapter?.number,
    });
    _ref.read(userProfileProvider.notifier).incrementChaptersRead();
    _ref.read(achievementServiceProvider).checkAndGrant();
    _goToNextChapter();
  }

  /// v2: достижение концовки — запись в профиль, аналитика, ачивки,
  /// экран концовки (ChapterTransition.ending).
  void _reachEnding(SceneEnding ending) {
    _activeEnding = ending;
    final novelId = state!.novelId;
    final profileNotifier = _ref.read(userProfileProvider.notifier);
    profileNotifier.unlockEnding(novelId, ending.id);
    // Достигнутая концовка = завершённое прохождение
    profileNotifier.incrementNovelsCompleted();
    _ref.read(analyticsServiceProvider).log('ending_reached', {
      'novelId': novelId,
      'endingId': ending.id,
    });
    _ref.read(achievementServiceProvider).onEndingReached(
          novelId,
          ending.id,
          _novelMeta?.endings ?? const [],
        );
    _ref.read(chapterTransitionProvider.notifier).state =
        ChapterTransition.ending;
    _transitioning = false;
  }

  /// Установить переменную из события setVariable (поддерживает "+N"/"-N"/"toggle"/значение)
  void applySetVariable(String? variable, dynamic value) {
    if (state == null || variable == null || variable.isEmpty) return;
    _applyEffects({variable: value});
  }

  /// Применить эффекты к переменным + toast-уведомления по statsDisplay
  void _applyEffects(Map<String, dynamic>? effects) {
    if (state == null || effects == null || effects.isEmpty) return;
    final before = state!.variables;
    state = _variableEngine.applyEffects(state!, effects);
    _emitStatChanges(before, state!.variables);
  }

  void _emitStatChanges(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    final stats = _novelMeta?.statsDisplay;
    if (stats == null || stats.isEmpty) return;
    final changes = <StatChangeNotice>[];
    for (final stat in stats) {
      final oldRaw = before[stat.variable];
      final newRaw = after[stat.variable];
      final oldVal = oldRaw is num ? oldRaw : num.tryParse('$oldRaw') ?? 0;
      final newVal = newRaw is num ? newRaw : num.tryParse('$newRaw');
      if (newVal == null) continue;
      final delta = newVal - oldVal;
      if (delta == 0) continue;
      changes.add(StatChangeNotice(
        variable: stat.variable,
        label: stat.label.isNotEmpty ? tr(stat.label) : stat.variable,
        icon: stat.icon,
        color: stat.color,
        delta: delta,
        newValue: newVal,
      ));
    }
    if (changes.isNotEmpty) {
      _ref.read(statChangesProvider.notifier).state = changes;
    }
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
        _startChapter(nextChapter);
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

  /// Общий вход в новую главу: state, рекап, аналитика, backlog
  void _startChapter(Chapter chapter) {
    _currentChapter = chapter;
    _currentScene = chapter.getScene(chapter.firstSceneId);
    state = state!.copyWith(
      currentChapterId: chapter.id,
      currentSceneId: chapter.firstSceneId,
      currentEventIndex: 0,
      lastPlayed: DateTime.now(),
    );
    _ref.read(analyticsServiceProvider).log('chapter_start', {
      'novelId': state!.novelId,
      'chapter': chapter.number,
    });
    _maybeSetRecap();
    _logCurrent();
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

    _startChapter(nextChapter);
    _ref.read(chapterTransitionProvider.notifier).state = ChapterTransition.none;
    return true;
  }

  /// Сделать выбор
  void makeChoice(Choice choice) {
    if (state == null) return;

    // Применить эффекты (+ toast по статам)
    _applyEffects(choice.effects);

    // v2: сюжетная разблокировка аутфитов ("characterId:outfitId")
    final unlocks = choice.unlockOutfits;
    if (unlocks != null && unlocks.isNotEmpty) {
      final wardrobe = _ref.read(wardrobeServiceProvider.notifier);
      for (final entry in unlocks) {
        final sep = entry.indexOf(':');
        if (sep <= 0 || sep >= entry.length - 1) continue;
        wardrobe.unlockOutfit(
          state!.novelId,
          entry.substring(0, sep),
          entry.substring(sep + 1),
        );
      }
    }

    // Добавить в историю
    final newHistory = List<String>.from(state!.history)
      ..add('${_currentScene!.id}:${choice.text}');
    state = state!.copyWith(history: newHistory);

    // Backlog: сделанный выбор
    _pushBacklog(BacklogEntry(text: trx(choice.text), isChoice: true));

    _ref.read(analyticsServiceProvider).log('choice_made', {
      'novelId': state!.novelId,
      'premium': choice.premium,
    });

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
    _logCurrent();
  }

  // ── Рекап главы («Ранее…», спека 1.8) ──

  /// Показывать рекап, если он есть, ещё не показан в этом прохождении
  /// и мы в начале главы.
  void _maybeSetRecap() {
    _pendingRecap = null;
    final chapter = _currentChapter;
    final st = state;
    if (chapter == null || st == null) return;
    final recap = chapter.recap;
    if (recap == null || recap.isEmpty) return;
    if (st.seenRecaps.contains(chapter.id)) return;
    if (st.currentSceneId != chapter.firstSceneId ||
        st.currentEventIndex != 0) {
      return;
    }
    _pendingRecap = recap;
  }

  /// Закрыть экран рекапа (показ один раз за прохождение — флаг в сейве)
  void dismissRecap() {
    final chapter = _currentChapter;
    _pendingRecap = null;
    if (chapter == null || state == null) return;
    if (state!.seenRecaps.contains(chapter.id)) {
      state = state!.copyWith(); // ребилд подписчиков
      return;
    }
    final seen = List<String>.from(state!.seenRecaps)..add(chapter.id);
    state = state!.copyWith(seenRecaps: seen);
  }

  // ── Backlog + прогресс чтения ──

  /// Залогировать текущее событие: пометить прочитанным и записать в backlog.
  /// Дедуп по ключу «глава/сцена/индекс».
  void _logCurrent() {
    final st = state;
    final scene = _currentScene;
    if (st == null || scene == null) return;
    final idx = st.currentEventIndex;
    if (idx >= scene.events.length) return;
    final key = '${st.currentChapterId}/${scene.id}/$idx';
    if (key == _lastLoggedKey) return;
    _lastLoggedKey = key;

    // Прочитанное событие (для fast-forward)
    try {
      _ref
          .read(readingProgressProvider)
          .markRead(st.novelId, scene.id, idx);
    } catch (_) {}

    final event = scene.events[idx];
    if (event.type == EventType.dialogue ||
        event.type == EventType.narration) {
      final text = trx(event.text);
      if (text.isEmpty) return;
      Character? character;
      if (event.type == EventType.dialogue && event.speaker != null) {
        character = getCharacter(event.speaker!);
      }
      _pushBacklog(BacklogEntry(
        speakerName: character != null
            ? trCharacter(character.id, character.name)
            : null,
        speakerColor: character?.color,
        text: text,
        isNarration: event.type == EventType.narration,
      ));
    }
  }

  void _pushBacklog(BacklogEntry entry) {
    _backlog.add(entry);
    while (_backlog.length > backlogCap) {
      _backlog.removeAt(0);
    }
  }
}
