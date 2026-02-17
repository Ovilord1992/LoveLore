import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/scene.dart';

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

  /// Сдвиг справа
  static Widget slideRight({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
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

/// Анимированный фон сцены — загружает изображения из assets или скачанных файлов
class AnimatedBackground extends StatefulWidget {
  final String? backgroundKey;
  final String? novelId;
  final Duration duration;

  const AnimatedBackground({
    super.key,
    this.backgroundKey,
    this.novelId,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  File? _imageFile;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolveBackground();
  }

  @override
  void didUpdateWidget(AnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundKey != widget.backgroundKey) {
      _resolved = false;
      _imageFile = null;
      _resolveBackground();
    }
  }

  Future<void> _resolveBackground() async {
    if (widget.backgroundKey == null || widget.novelId == null) {
      if (mounted) setState(() => _resolved = true);
      return;
    }

    // Ищем в скачанных файлах
    final appDir = await getApplicationDocumentsDirectory();
    final path = '${appDir.path}/novels/${widget.novelId}/${widget.backgroundKey}';
    final file = File(path);
    if (await file.exists()) {
      if (mounted) setState(() { _imageFile = file; _resolved = true; });
      return;
    }

    // Пробуем встроенный asset (не будем ломать, просто пометим resolved)
    if (mounted) setState(() => _resolved = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      child: _resolved && _imageFile != null
          ? Image.file(
              _imageFile!,
              key: ValueKey(widget.backgroundKey),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Container(
              key: ValueKey('gradient_${widget.backgroundKey}'),
              decoration: BoxDecoration(
                gradient: _getGradient(widget.backgroundKey),
              ),
            ),
    );
  }

  LinearGradient _getGradient(String? key) {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
    );
  }
}

/// Виджет персонажа — загружает спрайт из файлов или показывает плейсхолдер
/// Поддерживает анимации: fade_in, fade_out, slide_in_left, slide_in_right, bounce, shake
class AnimatedCharacterSprite extends StatefulWidget {
  final String characterId;
  final String? spriteImage;
  final String? novelId;
  final String displayLetter;
  final String? animation;

  const AnimatedCharacterSprite({
    super.key,
    required this.characterId,
    this.spriteImage,
    this.novelId,
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
  late Animation<double> _bounceAnimation;
  late Animation<double> _shakeAnimation;
  File? _spriteFile;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _setupAnimations();
    _controller.forward();
    _resolveSprite();
  }

  void _setupAnimations() {
    final anim = widget.animation;

    // Fade
    if (anim == 'fade_out') {
      _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
    } else {
      _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    }

    // Slide
    final Offset slideBegin;
    if (anim == 'slide_in_left') {
      slideBegin = const Offset(-1.0, 0.0);
    } else if (anim == 'slide_in_right') {
      slideBegin = const Offset(1.0, 0.0);
    } else {
      slideBegin = const Offset(0, 0.1);
    }
    _slideAnimation = Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Bounce
    _bounceAnimation = anim == 'bounce'
        ? TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: -20.0), weight: 30),
            TweenSequenceItem(tween: Tween(begin: -20.0, end: 0.0), weight: 20),
            TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 25),
            TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 25),
          ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
        : const AlwaysStoppedAnimation(0.0);

    // Shake
    _shakeAnimation = anim == 'shake'
        ? TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 10),
            TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 20),
            TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 20),
            TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 20),
            TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 30),
          ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
        : const AlwaysStoppedAnimation(0.0);
  }

  @override
  void didUpdateWidget(AnimatedCharacterSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spriteImage != widget.spriteImage) {
      _resolved = false;
      _spriteFile = null;
      _resolveSprite();
    }
  }

  Future<void> _resolveSprite() async {
    if (widget.spriteImage == null || widget.novelId == null) {
      if (mounted) setState(() => _resolved = true);
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final path = '${appDir.path}/novels/${widget.novelId}/${widget.spriteImage}';
    final file = File(path);
    if (await file.exists()) {
      if (mounted) setState(() { _spriteFile = file; _resolved = true; });
      return;
    }

    if (mounted) setState(() => _resolved = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spriteWidget = _resolved && _spriteFile != null
        ? Image.file(_spriteFile!, height: 350, fit: BoxFit.contain)
        : Container(
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
                style: const TextStyle(fontSize: 48, color: Colors.white24, fontWeight: FontWeight.w300),
              ),
            ),
          );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, _bounceAnimation.value),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(opacity: _fadeAnimation, child: child),
          ),
        );
      },
      child: spriteWidget,
    );
  }
}

/// Оверлей визуальных эффектов (shake, flash, fadeToBlack, rain, snow, particles)
class SceneEffectOverlay extends StatefulWidget {
  final EffectType effectType;
  final int duration; // мс
  final double intensity; // 0.0–1.0
  final VoidCallback? onComplete;

  const SceneEffectOverlay({
    super.key,
    required this.effectType,
    this.duration = 500,
    this.intensity = 0.7,
    this.onComplete,
  });

  @override
  State<SceneEffectOverlay> createState() => _SceneEffectOverlayState();
}

class _SceneEffectOverlayState extends State<SceneEffectOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );
    _controller.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.effectType) {
      case EffectType.shake:
        return _buildShake();
      case EffectType.flash:
        return _buildFlash();
      case EffectType.fadeToBlack:
        return _buildFadeToBlack();
      case EffectType.rain:
        return _buildWeather(isSnow: false);
      case EffectType.snow:
        return _buildWeather(isSnow: true);
      case EffectType.particles:
        return _buildParticles();
    }
  }

  Widget _buildShake() {
    final shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10 * widget.intensity), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 10 * widget.intensity, end: -10 * widget.intensity), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -10 * widget.intensity, end: 8 * widget.intensity), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8 * widget.intensity, end: -4 * widget.intensity), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -4 * widget.intensity, end: 0), weight: 30),
    ]).animate(_controller);

    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(shake.value, shake.value * 0.5),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildFlash() {
    final opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: widget.intensity), weight: 30),
      TweenSequenceItem(tween: Tween(begin: widget.intensity, end: 0), weight: 70),
    ]).animate(_controller);

    return AnimatedBuilder(
      animation: opacity,
      builder: (context, _) => IgnorePointer(
        child: Container(color: Colors.white.withValues(alpha: opacity.value)),
      ),
    );
  }

  Widget _buildFadeToBlack() {
    final opacity = Tween<double>(begin: 0, end: widget.intensity).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: opacity,
      builder: (context, _) => IgnorePointer(
        child: Container(color: Colors.black.withValues(alpha: opacity.value)),
      ),
    );
  }

  Widget _buildWeather({required bool isSnow}) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _WeatherPainter(
              progress: _controller.value,
              intensity: widget.intensity,
              isSnow: isSnow,
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticles() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(
              progress: _controller.value,
              intensity: widget.intensity,
            ),
          );
        },
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final double progress;
  final double intensity;
  final bool isSnow;
  final Random _random = Random(42);

  _WeatherPainter({required this.progress, required this.intensity, required this.isSnow});

  @override
  void paint(Canvas canvas, Size size) {
    final count = (intensity * (isSnow ? 80 : 120)).toInt();
    final paint = Paint()..color = Colors.white.withValues(alpha: isSnow ? 0.8 : 0.3);
    paint.strokeWidth = isSnow ? 2 : 1;

    for (int i = 0; i < count; i++) {
      final x = _random.nextDouble() * size.width;
      final speed = 0.5 + _random.nextDouble() * 0.5;
      final y = ((progress * speed * size.height * 3) + _random.nextDouble() * size.height) % size.height;

      if (isSnow) {
        final radius = 1.5 + _random.nextDouble() * 2;
        canvas.drawCircle(Offset(x + sin(progress * 6 + i) * 10, y), radius, paint);
      } else {
        final length = 8.0 + _random.nextDouble() * 12;
        canvas.drawLine(Offset(x, y), Offset(x - 2, y + length), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) => old.progress != progress;
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final double intensity;
  final Random _random = Random(42);

  _ParticlePainter({required this.progress, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final count = (intensity * 40).toInt();
    final colors = [Colors.amber, Colors.pinkAccent, Colors.orangeAccent, Colors.white70];

    for (int i = 0; i < count; i++) {
      final x = _random.nextDouble() * size.width;
      final baseY = _random.nextDouble() * size.height;
      final y = baseY - progress * size.height * 0.5 * (0.5 + _random.nextDouble());
      final radius = 1.5 + _random.nextDouble() * 2.5;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: (1 - progress).clamp(0, 1))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x + sin(progress * 4 + i) * 15, y % size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.progress != progress;
}
