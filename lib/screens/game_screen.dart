import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/scene_engine.dart';
import '../models/scene.dart';
import '../models/game_state.dart';
import '../services/save_service.dart';
import '../services/currency_service.dart';
import '../services/user_profile_service.dart';
import '../services/achievement_service.dart';
import '../widgets/dialogue_box.dart';
import '../widgets/choice_buttons.dart';
import '../widgets/scene_transitions.dart';
import '../widgets/relationship_bar.dart';
import '../widgets/chapter_progress.dart';
import '../widgets/achievement_popup.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String novelId;
  final bool forceNew;

  const GameScreen({super.key, required this.novelId, this.forceNew = false});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _fadeController;
  // Кешируем ссылки для безопасного сохранения в deactivate
  SaveService? _saveService;
  GameState? _lastState;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Откладываем загрузку, чтобы не модифицировать провайдеры во время build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNovel());
  }

  Future<void> _loadNovel() async {
    // Проверяем и тратим билет
    final currency = ref.read(currencyServiceProvider.notifier);
    if (!currency.spendTicket()) {
      if (mounted) {
        _showNoTicketsDialog();
      }
      return;
    }

    await ref.read(sceneEngineProvider.notifier).startNovel(
      widget.novelId,
      forceNew: widget.forceNew,
    );
    _saveService = ref.read(saveServiceProvider);
    setState(() => _isLoading = false);
    _fadeController.forward();
  }

  void _showNoTicketsDialog() {
    final currency = ref.read(currencyServiceProvider.notifier);
    final timeLeft = currency.timeToNextTicket;
    final min = timeLeft.inMinutes;
    final sec = timeLeft.inSeconds % 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Нет билетов ⚡', style: TextStyle(color: Colors.white)),
        content: Text(
          'Билеты закончились.\nСледующий через $min м $sec с.\n\nИли потрать 💎 10 алмазов.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('Назад', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final cs = ref.read(currencyServiceProvider.notifier);
              if (cs.canAfford(10)) {
                cs.spendDiamonds(10);
                Navigator.pop(ctx);
                _loadNovelAfterTicket();
              } else {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Не хватает алмазов 💎'),
                    backgroundColor: Color(0xFF16213E),
                  ),
                );
              }
            },
            child: const Text('💎 10 алмазов', style: TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNovelAfterTicket() async {
    await ref.read(sceneEngineProvider.notifier).startNovel(
      widget.novelId,
      forceNew: widget.forceNew,
    );
    _saveService = ref.read(saveServiceProvider);
    setState(() => _isLoading = false);
    _fadeController.forward();
  }

  Future<void> _autoSave() async {
    final state = ref.read(sceneEngineProvider);
    if (state != null) {
      await ref.read(saveServiceProvider).saveGame(state);
    }
  }

  @override
  void deactivate() {
    // Сохраняем до того как ref будет уничтожен
    _lastState = ref.read(sceneEngineProvider);
    if (_lastState != null && _saveService != null) {
      _saveService!.saveGame(_lastState!);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(sceneEngineProvider);
    final engine = ref.read(sceneEngineProvider.notifier);
    final chapterTransition = ref.watch(chapterTransitionProvider);

    if (_isLoading || gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Показываем UI перехода между главами
    if (chapterTransition != ChapterTransition.none) {
      return _buildChapterTransitionScreen(chapterTransition, engine);
    }

    final scene = engine.currentScene;
    final event = engine.currentEvent;

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (event != null && event.type != EventType.choice) {
            engine.nextEvent();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Фон с анимированными переходами
            AnimatedBackground(backgroundKey: scene?.background, novelId: widget.novelId),

            // Персонажи на экране
            if (scene != null) _buildCharacters(scene, engine),

            // Диалог / Выбор
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildEventUI(event, engine),
            ),

            // Верхняя панель
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // Прогресс по главе
                  ChapterProgressIndicator(
                    currentSceneIndex: engine.currentSceneIndex,
                    totalScenes: engine.totalScenes,
                    chapterTitle: engine.currentChapter?.title,
                  ),
                  IconButton(
                    icon: const Icon(Icons.save_outlined, color: Colors.white70),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _autoSave();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Сохранено ✓'),
                            duration: Duration(seconds: 1),
                            backgroundColor: Color(0xFF16213E),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Шкала отношений (справа)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              right: 8,
              child: _buildRelationships(gameState, engine),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacters(Scene scene, SceneEngine engine) {
    return Stack(
      children: scene.charactersOnScreen.map((sc) {
        final character = engine.getCharacter(sc.characterId);
        if (character == null) return const SizedBox.shrink();

        // Найти путь к спрайту
        String? spriteImage;
        try {
          final sprite = character.sprites.firstWhere((s) => s.id == sc.spriteId);
          spriteImage = sprite.image;
        } catch (_) {}

        final alignment = switch (sc.position) {
          CharacterPosition.left => Alignment.bottomLeft,
          CharacterPosition.right => Alignment.bottomRight,
          CharacterPosition.center => Alignment.bottomCenter,
        };

        return Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 200),
            child: AnimatedCharacterSprite(
              key: ValueKey('${sc.characterId}_${sc.spriteId}'),
              characterId: sc.characterId,
              spriteImage: spriteImage,
              novelId: widget.novelId,
              displayLetter: character.name[0],
              animation: sc.animation,
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleChoice(Choice choice, SceneEngine engine) {
    if (choice.premium && choice.cost > 0) {
      final currency = ref.read(currencyServiceProvider.notifier);
      if (!currency.canAfford(choice.cost)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не хватает алмазов (нужно ${choice.cost} 💎)'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF16213E),
          ),
        );
        return;
      }
      currency.spendDiamonds(choice.cost);
    }
    ref.read(userProfileProvider.notifier).incrementChoicesMade();
    engine.makeChoice(choice);

    // Проверяем достижения после выбора
    _checkAchievements();
  }

  void _checkAchievements() {
    final achievementService = ref.read(achievementServiceProvider);
    final unlocked = achievementService.checkAndGrant();

    // Проверяем достижения на основе переменных
    final gameState = ref.read(sceneEngineProvider);
    if (gameState != null) {
      final varUnlocked =
          achievementService.checkVariableAchievements(gameState.variables);
      unlocked.addAll(varUnlocked);
    }

    if (unlocked.isNotEmpty && mounted) {
      AchievementPopup.showAll(context, unlocked);
    }
  }

  Widget _buildRelationships(GameState gameState, SceneEngine engine) {
    // Собираем переменные отношений (содержат _love или _trust)
    final relationships = <String, RelationshipInfo>{};
    for (final entry in gameState.variables.entries) {
      if (entry.key.contains('_love') || entry.key.contains('_trust')) {
        final charId = entry.key.split('_').first;
        final character = engine.getCharacter(charId);
        if (character != null && entry.value is num) {
          relationships[entry.key] = RelationshipInfo(
            characterName: character.name,
            value: entry.value as num,
            color: character.color != null
                ? _parseColor(character.color!)
                : const Color(0xFFE91E63),
          );
        }
      }
    }

    if (relationships.isEmpty) return const SizedBox.shrink();

    return RelationshipPanel(relationships: relationships);
  }

  Widget _buildEventUI(SceneEvent? event, SceneEngine engine) {
    if (event == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black54,
        child: const Center(
          child: Text(
            'Конец главы',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    switch (event.type) {
      case EventType.choice:
        final available = engine.getAvailableChoices(event.choices ?? []);
        return ChoiceButtons(
          choices: available,
          onChoiceSelected: (choice) => _handleChoice(choice, engine),
        );

      case EventType.dialogue:
        final character =
            event.speaker != null ? engine.getCharacter(event.speaker!) : null;
        return DialogueBox(
          speakerName: character?.name,
          speakerColor:
              character?.color != null ? _parseColor(character!.color!) : null,
          text: event.text ?? '',
          onTap: () => engine.nextEvent(),
        );

      case EventType.narration:
        return DialogueBox(
          text: event.text ?? '',
          onTap: () => engine.nextEvent(),
        );

      default:
        engine.nextEvent();
        return const SizedBox.shrink();
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildChapterTransitionScreen(
    ChapterTransition transition,
    SceneEngine engine,
  ) {
    final nextNum = engine.nextChapterNumber;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Иконка
                Icon(
                  transition == ChapterTransition.completed
                      ? Icons.auto_stories
                      : transition == ChapterTransition.notReleased
                          ? Icons.lock_clock
                          : transition == ChapterTransition.loading
                              ? Icons.downloading
                              : Icons.download,
                  size: 64,
                  color: const Color(0xFFE91E63),
                ),
                const SizedBox(height: 24),

                // Заголовок
                Text(
                  transition == ChapterTransition.completed
                      ? 'Конец истории'
                      : transition == ChapterTransition.notReleased
                          ? 'Продолжение следует...'
                          : transition == ChapterTransition.loading
                              ? 'Загрузка...'
                              : 'Глава $nextNum',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Подзаголовок
                Text(
                  transition == ChapterTransition.completed
                      ? 'Спасибо за прохождение! 💖'
                      : transition == ChapterTransition.notReleased
                          ? 'Глава $nextNum ещё не вышла.\nСледите за обновлениями!'
                          : transition == ChapterTransition.loading
                              ? 'Загружаем следующую главу...'
                              : 'Следующая глава доступна!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Кнопки
                if (transition == ChapterTransition.loading)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFFE91E63)),
                  ),

                if (transition == ChapterTransition.needsDownload)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await engine.downloadAndStartNextChapter();
                    },
                    icon: const Icon(Icons.download),
                    label: Text('Скачать главу $nextNum'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),

                if (transition == ChapterTransition.completed ||
                    transition == ChapterTransition.notReleased)
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Вернуться в библиотеку'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
