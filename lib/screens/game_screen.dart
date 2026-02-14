import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/scene_engine.dart';
import '../models/scene.dart';
import '../widgets/dialogue_box.dart';
import '../widgets/choice_buttons.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String novelId;

  const GameScreen({super.key, required this.novelId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadNovel();
  }

  Future<void> _loadNovel() async {
    await ref.read(sceneEngineProvider.notifier).startNovel(widget.novelId);
    setState(() => _isLoading = false);
    _fadeController.forward();
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

    if (_isLoading || gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            // Фон
            _buildBackground(scene),

            // Персонажи на экране
            if (scene != null) _buildCharacters(scene, engine),

            // Диалог / Выбор
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildEventUI(event, engine),
            ),

            // Кнопка "назад"
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(Scene? scene) {
    // Пока используем цветной градиент, позже заменим на изображения
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F3460),
            const Color(0xFF1A1A2E),
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

        final alignment = switch (sc.position) {
          CharacterPosition.left => Alignment.bottomLeft,
          CharacterPosition.right => Alignment.bottomRight,
          CharacterPosition.center => Alignment.bottomCenter,
        };

        return Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Placeholder для спрайта
                Container(
                  width: 120,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      character.name[0],
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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
          onChoiceSelected: (choice) => engine.makeChoice(choice),
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
}
