import 'package:flutter/material.dart';

/// Анимации переходов между сценами
class SceneTransitions {
  /// Плавное затухание / появление
  static Widget fade({
    required Widget child,
    required Animation<double> animation,
  }) {
    return FadeTransition(opacity: animation, child: child);
  }

  /// Сдвиг слева
  static Widget slideLeft({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  /// Растворение (dissolve) — комбинация fade двух виджетов
  static Widget dissolve({
    required Widget child,
    required Animation<double> animation,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }
}

/// Анимированный фон сцены с плавными переходами
class AnimatedBackground extends StatelessWidget {
  final String? backgroundKey;
  final Duration duration;

  const AnimatedBackground({
    super.key,
    this.backgroundKey,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      child: Container(
        key: ValueKey(backgroundKey),
        decoration: BoxDecoration(
          gradient: _getGradient(backgroundKey),
        ),
      ),
    );
  }

  /// Маппинг ключей фона на градиенты (пока нет изображений)
  LinearGradient _getGradient(String? key) {
    switch (key) {
      case 'city_night.png':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
        );
      case 'cafe_night.png':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D1B1B), Color(0xFF4A2C2A), Color(0xFF6B3A3A)],
        );
      case 'mansion.png':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0A2E), Color(0xFF2D1854), Color(0xFF4A2D7A)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
        );
    }
  }
}

/// Виджет персонажа с анимациями появления/ухода
class AnimatedCharacterSprite extends StatefulWidget {
  final String characterId;
  final String displayLetter;
  final String? animation;

  const AnimatedCharacterSprite({
    super.key,
    required this.characterId,
    required this.displayLetter,
    this.animation,
  });

  @override
  State<AnimatedCharacterSprite> createState() =>
      _AnimatedCharacterSpriteState();
}

class _AnimatedCharacterSpriteState extends State<AnimatedCharacterSprite>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: 120,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Center(
            child: Text(
              widget.displayLetter,
              style: const TextStyle(
                fontSize: 48,
                color: Colors.white24,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
