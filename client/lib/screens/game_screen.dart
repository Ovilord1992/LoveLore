import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/locale_service.dart';
import '../services/settings_service.dart';
import 'package:path_provider/path_provider.dart';
import '../engine/scene_engine.dart';
import '../models/scene.dart';
import '../models/game_state.dart';
import '../services/audio_service.dart';
import '../services/save_service.dart';
import '../services/currency_service.dart';
import '../services/user_profile_service.dart';
import '../services/achievement_service.dart';
import '../services/ad_service.dart';
import '../services/vip_service.dart';
import '../services/wardrobe_service.dart';
import '../widgets/dialogue_box.dart';
import '../widgets/dialogue_overlay.dart';
import '../widgets/choice_buttons.dart';
import '../widgets/recap_overlay.dart';
import '../widgets/save_load_sheet.dart';
import '../widgets/scene_transitions.dart';
import '../widgets/stats_panel.dart';
import '../widgets/chapter_progress.dart';
import '../widgets/achievement_popup.dart';
import 'dialogue_log_screen.dart';
import 'wardrobe_screen.dart';
import '../app/theme.dart';
import 'settings_screen.dart';

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
  AudioService? _audio;
  // Активный эффект
  SceneEvent? _activeEffect;
  // CG-арт оверлей
  SceneEvent? _activeCg;
  File? _cgFile;
  String? _cgAsset; // встроенный asset, если файл не скачан
  // Камера
  double _cameraZoom = 1.0;
  double _cameraPanX = 0.0;
  double _cameraPanY = 0.0;
  int _cameraDuration = 1000;
  // Эмоции
  SceneEvent? _activeEmotion;
  File? _emotionFile;
  String? _emotionAsset;
  // Оверрайды визуала внутри сцены (события changeBackground/changeSprite)
  String? _overridesSceneId;
  String? _bgOverride;
  Map<String, String> _spriteOverrides = {};
  // Ключ последнего запланированного авто-события (дедуп rebuild'ов)
  String? _lastAutoKey;
  // Ключ последней озвученной реплики (v2 voice)
  String? _lastVoiceKey;
  // Fast-forward по прочитанному (v2)
  bool _fastForward = false;
  Timer? _ffTimer;
  // Показан ли запрос имени игрока
  bool _namePromptShown = false;
  // Путь Documents (резолв картинок концовки)
  String? _docsPath;
  // Immersive mode: top UI auto-hide
  late AnimationController _uiAnimController;
  Timer? _uiHideTimer;
  bool _uiVisible = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _uiAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    getApplicationDocumentsDirectory().then((dir) {
      if (mounted) setState(() => _docsPath = dir.path);
    });
    // Откладываем загрузку, чтобы не модифицировать провайдеры во время build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNovel());
  }

  Future<void> _loadNovel() async {
    _audio = ref.read(audioServiceProvider);
    // VIP — безлимитные билеты
    final vip = ref.read(vipServiceProvider);
    if (!vip.isActive) {
      final currency = ref.read(currencyServiceProvider.notifier);
      if (!currency.spendTicket(refId: widget.novelId)) {
        if (mounted) {
          _showNoTicketsDialog();
        }
        return;
      }
    }

    await ref
        .read(sceneEngineProvider.notifier)
        .startNovel(widget.novelId, forceNew: widget.forceNew);
    _saveService = ref.read(saveServiceProvider.notifier);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _fadeController.forward();
    _maybeShowNamePrompt();
  }

  /// v2: запрос имени игрока при первом старте (playerNamePrompt, спека 1.4)
  void _maybeShowNamePrompt() {
    if (_namePromptShown) return;
    final engine = ref.read(sceneEngineProvider.notifier);
    if (!engine.needsPlayerName) return;
    _namePromptShown = true;
    final prompt = engine.novelMeta?.playerNamePrompt;
    final controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: Text(
            engine.tr(prompt?.prompt ?? 'Как тебя зовут?'),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: prompt?.defaultName ?? '',
              hintStyle: const TextStyle(color: Colors.white38),
              counterStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                engine.setPlayerName(controller.text);
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'Продолжить',
                style: TextStyle(color: AppTheme.primary),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showNoTicketsDialog() {
    final currency = ref.read(currencyServiceProvider.notifier);
    final adService = ref.read(adServiceProvider);
    final timeLeft = currency.timeToNextTicket;
    final min = timeLeft.inMinutes;
    final sec = timeLeft.inSeconds % 60;

    if (adService.adsEnabled) adService.preloadAd();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Нет билетов ⚡',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Билеты закончились.\nСледующий через $min м $sec с.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: Text(
              ref.tr('back'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          if (adService.canShowAd)
            TextButton(
              onPressed: () async {
                final success = await adService.showRewardedAd(
                  rewardType: 'tickets',
                  onReward: (_, amount) {
                    ref
                        .read(currencyServiceProvider.notifier)
                        .addTickets(amount, reason: 'ad_reward');
                  },
                );
                if (success && ctx.mounted) {
                  Navigator.pop(ctx);
                  _loadNovelAfterTicket();
                }
              },
              child: Text(
                '📺 Реклама → +${adService.ticketReward} 🎫',
                style: const TextStyle(color: AppTheme.cyan),
              ),
            ),
          TextButton(
            onPressed: () {
              final cs = ref.read(currencyServiceProvider.notifier);
              if (cs.canAfford(10)) {
                cs.spendDiamonds(
                  10,
                  reason: 'spend_choice',
                  refId: 'ticket_skip:${widget.novelId}',
                );
                Navigator.pop(ctx);
                _loadNovelAfterTicket();
              } else {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${ref.tr('not_enough_diamonds')} 💎'),
                    backgroundColor: AppTheme.surfaceDark,
                  ),
                );
              }
            },
            child: const Text(
              '💎 10 алмазов',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadNovelAfterTicket() async {
    await ref
        .read(sceneEngineProvider.notifier)
        .startNovel(widget.novelId, forceNew: widget.forceNew);
    _saveService = ref.read(saveServiceProvider.notifier);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _fadeController.forward();
    _maybeShowNamePrompt();
  }

  Future<void> _autoSave() async {
    final state = ref.read(sceneEngineProvider);
    if (state != null) {
      await ref.read(saveServiceProvider.notifier).saveGame(state);
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
    _audio?.stopVoice();
    _fadeController.dispose();
    _uiAnimController.dispose();
    _uiHideTimer?.cancel();
    _ffTimer?.cancel();
    super.dispose();
  }

  // ── Immersive UI show/hide ──
  void _showUI() {
    _uiHideTimer?.cancel();
    if (!_uiVisible) {
      setState(() => _uiVisible = true);
      _uiAnimController.forward();
    }
    _uiHideTimer = Timer(const Duration(seconds: 5), _hideUI);
  }

  void _hideUI() {
    _uiHideTimer?.cancel();
    _uiAnimController.reverse().then((_) {
      if (mounted) setState(() => _uiVisible = false);
    });
  }

  void _resetUITimer() {
    if (_uiVisible) {
      _uiHideTimer?.cancel();
      _uiHideTimer = Timer(const Duration(seconds: 5), _hideUI);
    }
  }

  // ── Fast-forward: автопродвижение по прочитанным событиям (v2) ──

  void _toggleFastForward() {
    setState(() => _fastForward = !_fastForward);
    _ffTimer?.cancel();
    _ffTimer = null;
    if (_fastForward) {
      _ffTimer = Timer.periodic(
        const Duration(milliseconds: 120),
        (_) => _ffTick(),
      );
    }
  }

  void _stopFastForward() {
    _ffTimer?.cancel();
    _ffTimer = null;
    if (_fastForward && mounted) {
      setState(() => _fastForward = false);
    }
  }

  void _ffTick() {
    if (!mounted) return;
    // Пока активен оверлей — ждём (оверлей сам продвинет сюжет)
    if (_activeEffect != null || _activeCg != null || _activeEmotion != null) {
      return;
    }
    final engine = ref.read(sceneEngineProvider.notifier);
    if (ref.read(chapterTransitionProvider) != ChapterTransition.none ||
        engine.pendingRecap != null) {
      _stopFastForward();
      return;
    }
    final event = engine.currentEvent;
    if (event == null) {
      engine.nextEvent();
      return;
    }
    if (event.type == EventType.choice) {
      // Стоп на выборе
      _stopFastForward();
      return;
    }
    if (event.type == EventType.dialogue ||
        event.type == EventType.narration) {
      if (engine.isCurrentEventRead) {
        engine.nextEvent();
      } else {
        // Дошли до непрочитанного — стоп
        _stopFastForward();
      }
    }
    // Остальные (авто-)события продвигаются сами.
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(sceneEngineProvider);
    final engine = ref.read(sceneEngineProvider.notifier);
    final chapterTransition = ref.watch(chapterTransitionProvider);
    final wardrobeState = ref.watch(wardrobeServiceProvider);

    // Смена языка «на лету»: перезагружаем перевод текущей новеллы.
    ref.listen(localeProvider, (prev, next) {
      if (prev != next) {
        engine.reloadTranslation();
      }
    });

    if (_isLoading || gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Показываем UI перехода между главами / экран концовки
    if (chapterTransition != ChapterTransition.none) {
      if (chapterTransition == ChapterTransition.ending) {
        return _buildEndingScreen(engine);
      }
      return _buildChapterTransitionScreen(chapterTransition, engine);
    }

    final scene = engine.currentScene;
    final event = engine.currentEvent;

    // При входе в новую сцену сбрасываем внутрисценовые оверрайды визуала
    // и камеру, запускаем фоновую музыку сцены.
    final sceneId = scene?.id;
    if (sceneId != _overridesSceneId) {
      _overridesSceneId = sceneId;
      _bgOverride = null;
      _spriteOverrides = {};
      _cameraZoom = 1.0;
      _cameraPanX = 0.0;
      _cameraPanY = 0.0;
      final music = scene?.music;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final audio = ref.read(audioServiceProvider);
        if (music != null && music.isNotEmpty) {
          audio.playBgMusicFile('${widget.novelId}/$music');
        }
      });
    }

    // v2: озвучка реплики — играет при показе события, обрывается на следующем
    _handleVoice(engine, event);

    final layers = scene?.backgroundLayers;
    final hasLayers = layers != null && layers.isNotEmpty;
    final recap = engine.pendingRecap;

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Пока показан оверлей (эффект/CG/эмоция) — тап игнорируем: оверлей
          // сам продвинет сюжет через onComplete, иначе строка проскочит.
          if (_activeEffect != null ||
              _activeCg != null ||
              _activeEmotion != null) {
            return;
          }
          // Тап руками выключает fast-forward
          if (_fastForward) _stopFastForward();
          // Тапом продвигаем только реплики; авто-события (камера, звук,
          // setVariable) продвигаются сами, choice — по кнопке.
          if (event != null &&
              (event.type == EventType.dialogue ||
                  event.type == EventType.narration)) {
            engine.nextEvent();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Фон с камерой (zoom/pan). v2: многослойный параллакс —
            // pan применяется к слоям с коэффициентом depth (спека 1.10),
            // поэтому у обёртки камеры pan обнуляется (иначе двойной сдвиг).
            CameraTransformWidget(
              zoom: _cameraZoom,
              panX: hasLayers ? 0.0 : _cameraPanX,
              panY: hasLayers ? 0.0 : _cameraPanY,
              duration: _cameraDuration,
              child: hasLayers
                  ? ParallaxBackground(
                      layers: layers,
                      novelId: widget.novelId,
                      panX: _cameraPanX,
                      panY: _cameraPanY,
                      panDuration: _cameraDuration,
                    )
                  : AnimatedBackground(
                      backgroundKey: _bgOverride ?? scene?.background,
                      novelId: widget.novelId,
                      duration: Duration(
                        milliseconds: scene?.transition?.duration ?? 800,
                      ),
                    ),
            ),

            // Персонажи на экране
            if (scene != null) _buildCharacters(scene, engine, wardrobeState),

            // Диалог / Выбор
            _buildEventPositioned(event, engine),

            // Верхняя панель (immersive: hidden by default, tap top area to reveal)
            // Invisible tap zone at top of screen to reveal UI
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).padding.top + 56,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _showUI,
              ),
            ),
            // Animated top panel
            if (_uiVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _uiAnimController,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 4,
                      right: 4,
                      bottom: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            _resetUITimer();
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: ChapterProgressIndicator(
                            currentSceneIndex: engine.currentSceneIndex,
                            totalScenes: engine.totalScenes,
                            chapterTitle: engine.currentChapter?.title,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // v2: панель статов (если statsDisplay задан)
                            if (engine.novelMeta?.statsDisplay.isNotEmpty ==
                                true)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.favorite_border,
                                  color: Colors.white70,
                                ),
                                tooltip: 'Отношения',
                                onPressed: () {
                                  _resetUITimer();
                                  showStatsPanel(
                                    context,
                                    stats:
                                        engine.novelMeta?.statsDisplay ?? [],
                                    variables: gameState.variables,
                                    translate: engine.tr,
                                  );
                                },
                              ),
                            // Backlog — лог диалогов
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.menu_book,
                                color: Colors.white70,
                              ),
                              tooltip: 'Лог диалогов',
                              onPressed: () {
                                _resetUITimer();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DialogueLogScreen(
                                      entries: engine.backlog,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // v2: fast-forward по прочитанному
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.fast_forward,
                                color: _fastForward
                                    ? AppTheme.primary
                                    : Colors.white70,
                              ),
                              tooltip: 'Пропуск прочитанного',
                              onPressed: () {
                                _resetUITimer();
                                _toggleFastForward();
                              },
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.checkroom,
                                color: Colors.white70,
                              ),
                              tooltip: ref.tr('wardrobe'),
                              onPressed: () {
                                _resetUITimer();
                                _openWardrobe(context, engine);
                              },
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.save_outlined,
                                color: Colors.white70,
                              ),
                              tooltip: 'Сохранить / Загрузить',
                              onPressed: () {
                                _resetUITimer();
                                showSaveLoadSheet(
                                    context, ref, widget.novelId);
                              },
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.menu,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                _resetUITimer();
                                _showPauseMenu(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Оверлей визуального эффекта
            if (_activeEffect != null)
              SceneEffectOverlay(
                key: ValueKey('effect_${_activeEffect.hashCode}'),
                effectType: _activeEffect!.effectType ?? EffectType.shake,
                duration: _activeEffect!.effectDuration ?? 500,
                intensity: _activeEffect!.effectIntensity ?? 0.7,
                onComplete: () {
                  setState(() => _activeEffect = null);
                  engine.nextEvent();
                },
              ),

            // CG-арт оверлей
            if (_activeCg != null)
              CgOverlay(
                key: ValueKey('cg_${_activeCg.hashCode}'),
                imageFile: _cgFile,
                assetPath: _cgAsset,
                transition: _activeCg!.cgTransition ?? CgTransition.fade,
                duration: _activeCg!.cgDuration ?? 800,
                onDismiss: () {
                  // Разблокировать CG в профиле (синхронизируется с сервером)
                  // и проверить достижения-коллекционера.
                  // v2: ключ — `<novelId>|<путь>` (группировка в галерее).
                  final cg = _activeCg?.cgImage;
                  if (cg != null) {
                    ref
                        .read(userProfileProvider.notifier)
                        .unlockCG('${widget.novelId}|$cg');
                    _checkAchievements();
                  }
                  setState(() {
                    _activeCg = null;
                    _cgFile = null;
                    _cgAsset = null;
                  });
                  engine.nextEvent();
                },
              ),

            // Эмоции-иконки
            if (_activeEmotion != null && scene != null)
              ..._buildEmotionOverlays(scene, engine),

            // v2: toast-уведомления об изменении статов («+1 ♥ Мия»)
            const StatToastHost(),

            // v2: рекап главы «Ранее…» (поверх всего, пропускаемый)
            if (recap != null)
              RecapOverlay(
                chapterTitle: engine.tr(engine.currentChapter?.title ?? ''),
                recapText: engine.trx(recap),
                onDismiss: () => engine.dismissRecap(),
              ),
          ],
        ),
      ),
    );
  }

  /// v2: проиграть/оборвать озвучку при смене события (спека 1.6)
  void _handleVoice(SceneEngine engine, SceneEvent? event) {
    final key = _eventKey(engine);
    if (_lastVoiceKey == key) return;
    _lastVoiceKey = key;
    final isSpeech = event != null &&
        (event.type == EventType.dialogue ||
            event.type == EventType.narration);
    final voice = isSpeech ? event.voice : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final audio = ref.read(audioServiceProvider);
      if (voice != null && voice.isNotEmpty) {
        audio.playVoice(widget.novelId, voice);
      } else {
        audio.stopVoice();
      }
    });
  }

  Widget _buildCharacters(
    Scene scene,
    SceneEngine engine,
    WardrobeState wardrobeState,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final spriteH = screenHeight * 0.83;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: scene.charactersOnScreen.map((sc) {
        final character = engine.getCharacter(sc.characterId);
        if (character == null) return const SizedBox.shrink();

        // Найти путь к спрайту (с учётом оверрайда от события changeSprite).
        // v2: резолв через экипированный аутфит (спека 1.5) с полным
        // фолбэком на базовые спрайты персонажа.
        final effectiveSpriteId = _spriteOverrides[sc.characterId] ?? sc.spriteId;
        final equippedOutfitId = wardrobeState.equippedOutfits[
            WardrobeService.equipKey(widget.novelId, sc.characterId)];
        final spriteImage = character.resolveSpriteImage(
          effectiveSpriteId,
          equippedOutfitId: equippedOutfitId,
        );

        // Горизонтальный сдвиг для позиционирования как в Клубе Романтики
        final xOffset = switch (sc.position) {
          CharacterPosition.left => -screenWidth * 0.25,
          CharacterPosition.right => screenWidth * 0.25,
          CharacterPosition.center => 0.0,
        };

        final sprite = AnimatedCharacterSprite(
          key: ValueKey(
              '${sc.characterId}_${equippedOutfitId ?? ''}_$effectiveSpriteId'),
          characterId: sc.characterId,
          spriteImage: spriteImage,
          novelId: widget.novelId,
          displayLetter: character.name[0],
          animation: sc.animation,
          spriteHeight: spriteH,
          imageAlignment: Alignment.bottomCenter,
        );

        final positionedSprite = sc.position == CharacterPosition.left
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(-1, 1, 1),
                child: sprite,
              )
            : sprite;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(xOffset, 0.0),
            child: positionedSprite,
          ),
        );
      }).toList(),
    );
  }

  void _handleChoice(Choice choice, SceneEvent event, SceneEngine engine) {
    if (choice.premium && choice.cost > 0) {
      final currency = ref.read(currencyServiceProvider.notifier);
      if (!currency.canAfford(choice.cost)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.tr('not_enough_diamonds')} (${choice.cost} 💎)',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.surfaceDark,
          ),
        );
        return;
      }
      // refId по спеке 2.2: `<novelId>:<sceneId>:<индекс выбора>`
      final choiceIndex = event.choices?.indexOf(choice) ?? -1;
      currency.spendDiamonds(
        choice.cost,
        reason: 'spend_choice',
        refId:
            '${widget.novelId}:${engine.currentScene?.id ?? ''}:$choiceIndex',
      );
      ref.read(userProfileProvider.notifier).incrementPremiumChoices();
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
      final varUnlocked = achievementService.checkVariableAchievements(
        gameState.variables,
      );
      unlocked.addAll(varUnlocked);
    }

    if (unlocked.isNotEmpty && mounted) {
      final translatedHeader = ref.tr('achievement_unlocked');
      AchievementPopup.showAll(
        context,
        unlocked,
        ref: ref,
        header: translatedHeader,
      );
    }
  }

  Widget _buildEventPositioned(SceneEvent? event, SceneEngine engine) {
    final settings = ref.watch(settingsServiceProvider);
    // Per-novel dialogueStyle overrides user setting if specified
    final novelStyle = engine.novelMeta?.dialogueStyle;
    final useOverlay =
        novelStyle == 'center' ||
        (novelStyle == null && settings.useOverlayDialogue);

    // Overlay mode: dialogue/narration fills entire screen
    if (useOverlay &&
        event != null &&
        (event.type == EventType.dialogue ||
            event.type == EventType.narration)) {
      final character = event.speaker != null
          ? engine.getCharacter(event.speaker!)
          : null;
      final speakerName = character != null
          ? engine.trCharacter(character.id, character.name)
          : null;

      // Determine speaker's on-screen position
      String speakerSide = 'center';
      if (event.speaker != null) {
        final scene = engine.currentScene;
        final sc = scene?.charactersOnScreen
            .where((c) => c.characterId == event.speaker)
            .firstOrNull;
        if (sc != null) {
          speakerSide = switch (sc.position) {
            CharacterPosition.left => 'left',
            CharacterPosition.right => 'right',
            CharacterPosition.center => 'center',
          };
        }
      }

      return Positioned.fill(
        child: DialogueOverlay(
          speakerName: speakerName,
          speakerColor: character?.color != null
              ? _parseColor(character!.color!)
              : null,
          text: engine.trx(event.text),
          onTap: () => engine.nextEvent(),
          frameTheme: engine.novelMeta?.frameTheme ?? DialogueFrameTheme.ornate,
          customFrameColor: _parseHexColor(
            engine.novelMeta?.dialogueFrameColor,
          ),
          customBgColor: _parseHexColor(engine.novelMeta?.dialogueBgColor),
          centered: novelStyle == 'center',
          speakerSide: speakerSide,
        ),
      );
    }

    // Classic mode or choices/other events: pinned to bottom
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _buildEventUI(event, engine),
    );
  }

  Widget _buildEventUI(SceneEvent? event, SceneEngine engine) {
    if (event == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black54,
        child: Center(
          child: Text(
            ref.tr('end_of_chapter'),
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    switch (event.type) {
      case EventType.choice:
        final available = engine.getAvailableChoices(event.choices ?? []);
        return ChoiceButtons(
          choices: available,
          onChoiceSelected: (choice) => _handleChoice(choice, event, engine),
          timeLimit: event.timeLimit,
          defaultChoiceIndex: event.defaultChoiceIndex,
          translateText: engine.trx,
          frameTheme: engine.novelMeta?.frameTheme ?? DialogueFrameTheme.ornate,
          customFrameColor: _parseHexColor(
            engine.novelMeta?.dialogueFrameColor,
          ),
          customBgColor: _parseHexColor(engine.novelMeta?.dialogueBgColor),
        );

      case EventType.dialogue:
        final character = event.speaker != null
            ? engine.getCharacter(event.speaker!)
            : null;
        final speakerName = character != null
            ? engine.trCharacter(character.id, character.name)
            : null;
        return DialogueBox(
          speakerName: speakerName,
          speakerColor: character?.color != null
              ? _parseColor(character!.color!)
              : null,
          text: engine.trx(event.text),
          onTap: () => engine.nextEvent(),
        );

      case EventType.narration:
        return DialogueBox(
          text: engine.trx(event.text),
          onTap: () => engine.nextEvent(),
        );

      default:
        // Оверлейные события — с guard'ом _activeX == null (idempotent).
        if (event.type == EventType.effect && event.effectType != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeEffect == null) {
              setState(() => _activeEffect = event);
            }
          });
          return const SizedBox.shrink();
        }
        if (event.type == EventType.showCg && event.cgImage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted && _activeCg == null) {
              final appDir = await getApplicationDocumentsDirectory();
              final file = File(
                '${appDir.path}/novels/${widget.novelId}/${event.cgImage}',
              );
              final exists = file.existsSync();
              setState(() {
                _activeCg = event;
                _cgFile = exists ? file : null;
                // Fallback на встроенный asset (источник №1).
                _cgAsset = exists
                    ? null
                    : 'assets/novels/${widget.novelId}/${event.cgImage}';
              });
            }
          });
          return const SizedBox.shrink();
        }
        if (event.type == EventType.showEmotion &&
            (event.emotionType != null || event.image != null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted && _activeEmotion == null) {
              // v2: эмоция картинкой из новеллы (файл → asset → emoji)
              File? file;
              String? asset;
              final img = event.image;
              if (img != null && img.isNotEmpty) {
                final appDir = await getApplicationDocumentsDirectory();
                final f = File(
                  '${appDir.path}/novels/${widget.novelId}/$img',
                );
                if (f.existsSync()) {
                  file = f;
                } else {
                  asset = 'assets/novels/${widget.novelId}/$img';
                }
              }
              if (!mounted) return;
              setState(() {
                _activeEmotion = event;
                _emotionFile = file;
                _emotionAsset = asset;
              });
            }
          });
          return const SizedBox.shrink();
        }
        // Мгновенные/таймерные события (камера, смена фона/спрайта, звук,
        // установка переменной, неизвестный тип) применяются РОВНО ОДИН РАЗ
        // по ключу события. Это устраняет rebuild-шторм cameraMove: раньше
        // каждый кадр вешал новый setState + Future.delayed(nextEvent).
        final autoKey = _eventKey(engine);
        if (_lastAutoKey != autoKey) {
          _lastAutoKey = autoKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applyAutoEvent(event, engine, autoKey);
          });
        }
        return const SizedBox.shrink();
    }
  }

  /// Уникальный ключ текущего события — для дедупликации авто-переходов.
  String _eventKey(SceneEngine engine) =>
      '${engine.currentChapter?.id}/${engine.currentScene?.id}/${engine.currentEventIndex}';

  /// Продвинуть сюжет, только если движок всё ещё на том же событии
  /// (защита от двойного advance, если игрок тапнул вручную).
  void _autoAdvance(SceneEngine engine, String key, {int delayMs = 0}) {
    if (delayMs <= 0) {
      if (_eventKey(engine) == key) engine.nextEvent();
      return;
    }
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted && _eventKey(engine) == key) engine.nextEvent();
    });
  }

  void _applyAutoEvent(SceneEvent event, SceneEngine engine, String key) {
    switch (event.type) {
      case EventType.cameraMove:
        setState(() {
          _cameraZoom = event.zoom ?? 1.0;
          _cameraPanX = event.panX ?? 0.0;
          _cameraPanY = event.panY ?? 0.0;
          _cameraDuration = event.cameraDuration ?? 1000;
        });
        _autoAdvance(engine, key, delayMs: event.cameraDuration ?? 1000);
        break;
      case EventType.changeBackground:
        if (event.asset != null) {
          setState(() => _bgOverride = event.asset);
        }
        _autoAdvance(engine, key);
        break;
      case EventType.changeSprite:
        if (event.characterId != null && event.spriteId != null) {
          setState(() {
            _spriteOverrides = {
              ..._spriteOverrides,
              event.characterId!: event.spriteId!,
            };
          });
        }
        _autoAdvance(engine, key);
        break;
      case EventType.playSound:
        if (event.asset != null) {
          ref
              .read(audioServiceProvider)
              .playSfxFile('${widget.novelId}/${event.asset}');
        }
        _autoAdvance(engine, key);
        break;
      case EventType.setVariable:
        engine.applySetVariable(event.variable, event.value);
        _autoAdvance(engine, key);
        break;
      default:
        // Неизвестный тип — просто пропускаем, не блокируя сюжет.
        _autoAdvance(engine, key);
    }
  }

  List<Widget> _buildEmotionOverlays(Scene scene, SceneEngine engine) {
    if (_activeEmotion == null) return [];
    final charId = _activeEmotion!.characterId;
    final sc = scene.charactersOnScreen
        .where((c) => c.characterId == charId)
        .firstOrNull;
    void onEmotionComplete() {
      setState(() {
        _activeEmotion = null;
        _emotionFile = null;
        _emotionAsset = null;
      });
      engine.nextEvent();
    }

    if (sc == null) {
      // Персонаж не на экране — показываем по центру
      return [
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          left: 0,
          right: 0,
          child: Center(
            child: EmotionBubble(
              key: ValueKey('emotion_${_activeEmotion.hashCode}'),
              emotionType: _activeEmotion!.emotionType ?? EmotionType.heart,
              imageFile: _emotionFile,
              assetPath: _emotionAsset,
              onComplete: onEmotionComplete,
            ),
          ),
        ),
      ];
    }

    final horizontalAlign = switch (sc.position) {
      CharacterPosition.left => 0.2,
      CharacterPosition.right => 0.8,
      CharacterPosition.center => 0.5,
    };

    return [
      Positioned(
        top: MediaQuery.of(context).size.height * 0.2,
        left: MediaQuery.of(context).size.width * horizontalAlign - 20,
        child: EmotionBubble(
          key: ValueKey('emotion_${_activeEmotion.hashCode}'),
          emotionType: _activeEmotion!.emotionType ?? EmotionType.heart,
          imageFile: _emotionFile,
          assetPath: _emotionAsset,
          onComplete: onEmotionComplete,
        ),
      ),
    ];
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    return _parseColor(hex);
  }

  /// v2: экран концовки (спека 1.3)
  Widget _buildEndingScreen(SceneEngine engine) {
    final ending = engine.currentEnding;
    final meta = engine.novelMeta;
    final profile = ref.watch(userProfileProvider);
    final totalEndings = meta?.endings.length ?? 0;
    final unlockedForNovel = profile.endingsForNovel(widget.novelId);
    final unlockedCount = totalEndings > 0
        ? meta!.endings.where((e) => unlockedForNovel.contains(e.id)).length
        : 0;

    // Резолв картинки концовки: Documents → asset
    Widget? endingImage;
    final imgPath = ending?.image;
    if (imgPath != null && imgPath.isNotEmpty) {
      File? file;
      if (_docsPath != null) {
        final f = File('$_docsPath/novels/${widget.novelId}/$imgPath');
        if (f.existsSync()) file = f;
      }
      endingImage = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: file != null
            ? Image.file(file, fit: BoxFit.cover)
            : Image.asset(
                'assets/novels/${widget.novelId}/$imgPath',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D1854), AppTheme.bgDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (endingImage != null) ...[
                    Flexible(child: endingImage),
                    const SizedBox(height: 24),
                  ] else ...[
                    const Icon(
                      Icons.auto_awesome,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    engine.trx(ending?.title ?? 'Конец'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (ending?.description != null &&
                      ending!.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      engine.trx(ending.description),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (totalEndings > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Концовки: $unlockedCount из $totalEndings',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.cyan,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
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
      ),
    );
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
            colors: [Color(0xFF0F3460), AppTheme.bgDark],
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
                      : transition == ChapterTransition.error
                      ? Icons.wifi_off
                      : transition == ChapterTransition.loading
                      ? Icons.downloading
                      : Icons.download,
                  size: 64,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 24),

                // Заголовок
                Text(
                  transition == ChapterTransition.completed
                      ? 'Конец истории'
                      : transition == ChapterTransition.notReleased
                      ? 'Продолжение следует...'
                      : transition == ChapterTransition.error
                      ? 'Нет соединения'
                      : transition == ChapterTransition.loading
                      ? ref.tr('loading')
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
                      : transition == ChapterTransition.error
                      ? 'Не удалось загрузить следующую главу.\nПроверьте интернет и повторите.'
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
                    valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                  ),

                if (transition == ChapterTransition.needsDownload)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await engine.downloadAndStartNextChapter();
                    },
                    icon: const Icon(Icons.download),
                    label: Text('${ref.tr('download')} $nextNum'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
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

                if (transition == ChapterTransition.error) ...[
                  ElevatedButton.icon(
                    onPressed: () => engine.retryNextChapter(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
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
                  const SizedBox(height: 12),
                ],

                if (transition == ChapterTransition.completed ||
                    transition == ChapterTransition.notReleased ||
                    transition == ChapterTransition.error)
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

  void _showPauseMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _PauseMenuDialog(
        onResume: () => Navigator.of(ctx).pop(),
        onSave: () {
          Navigator.of(ctx).pop();
          // Быстрый автосейв + меню слотов
          _autoSave();
          showSaveLoadSheet(context, ref, widget.novelId);
        },
        onWardrobe: () {
          Navigator.of(ctx).pop();
          _openWardrobe(context, ref.read(sceneEngineProvider.notifier));
        },
        onLog: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DialogueLogScreen(
                entries: ref.read(sceneEngineProvider.notifier).backlog,
              ),
            ),
          );
        },
        onSettings: () {
          Navigator.of(ctx).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        },
        onExit: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openWardrobe(BuildContext context, SceneEngine engine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WardrobeScreen(
          novelId: widget.novelId,
          characters: engine.characters,
        ),
      ),
    );
  }
}

class _PauseMenuDialog extends ConsumerWidget {
  final VoidCallback onResume;
  final VoidCallback onSave;
  final VoidCallback onWardrobe;
  final VoidCallback onLog;
  final VoidCallback onSettings;
  final VoidCallback onExit;

  const _PauseMenuDialog({
    required this.onResume,
    required this.onSave,
    required this.onWardrobe,
    required this.onLog,
    required this.onSettings,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(24),
            border: const Border(
              top: BorderSide(width: 2, color: Color(0xFFE91E63)),
            ),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '⏸ Pause',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              _menuItem(Icons.save, '💾 ${ref.tr("save")}', onSave),
              const Divider(color: Colors.white10),
              _menuItem(
                  Icons.checkroom, '👗 ${ref.tr("wardrobe")}', onWardrobe),
              const Divider(color: Colors.white10),
              _menuItem(Icons.menu_book, '📖 Лог диалогов', onLog),
              const Divider(color: Colors.white10),
              _menuItem(Icons.settings, '⚙️ ${ref.tr("settings")}', onSettings),
              const Divider(color: Colors.white10),
              _menuItem(
                Icons.exit_to_app,
                '🚪 Exit',
                onExit,
                isDestructive: true,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onResume,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Resume',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.redAccent : Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDestructive ? Colors.redAccent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
