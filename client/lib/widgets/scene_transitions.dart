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

    final appDir = await getApplicationDocumentsDirectory();
    final base = '${appDir.path}/novels/${widget.novelId}';

    // Ищем по прямому пути и в подпапке backgrounds/
    for (final candidate in [
      '$base/${widget.backgroundKey}',
      '$base/backgrounds/${widget.backgroundKey}',
    ]) {
      final file = File(candidate);
      if (await file.exists()) {
        if (mounted) setState(() { _imageFile = file; _resolved = true; });
        return;
      }
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
  final int spriteDuration; // cross-fade мс

  const AnimatedCharacterSprite({
    super.key,
    required this.characterId,
    this.spriteImage,
    this.novelId,
    required this.displayLetter,
    this.animation,
    this.spriteDuration = 300,
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
  File? _prevSpriteFile;
  bool _resolved = false;
  bool _crossFading = false;

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
      _prevSpriteFile = _spriteFile;
      _resolved = false;
      _spriteFile = null;
      _crossFading = widget.spriteDuration > 0 && _prevSpriteFile != null;
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
    Widget spriteWidget;
    if (_crossFading && _prevSpriteFile != null) {
      spriteWidget = AnimatedCrossFade(
        firstChild: Image.file(_prevSpriteFile!, height: 350, fit: BoxFit.contain),
        secondChild: _resolved && _spriteFile != null
            ? Image.file(_spriteFile!, height: 350, fit: BoxFit.contain)
            : _buildPlaceholder(),
        crossFadeState: _resolved ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: Duration(milliseconds: widget.spriteDuration),
      );
    } else {
      spriteWidget = _resolved && _spriteFile != null
          ? Image.file(_spriteFile!, height: 350, fit: BoxFit.contain)
          : _buildPlaceholder();
    }

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

  Widget _buildPlaceholder() {
    return Container(
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

/// Полноэкранный CG-арт оверлей
class CgOverlay extends StatefulWidget {
  final File? imageFile;
  final CgTransition transition;
  final int duration; // мс
  final VoidCallback onDismiss;

  const CgOverlay({
    super.key,
    required this.imageFile,
    this.transition = CgTransition.fade,
    this.duration = 800,
    required this.onDismiss,
  });

  @override
  State<CgOverlay> createState() => _CgOverlayState();
}

class _CgOverlayState extends State<CgOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.imageFile != null
        ? Image.file(widget.imageFile!, fit: BoxFit.contain, width: double.infinity, height: double.infinity)
        : Container(color: Colors.black, child: const Center(child: Text('CG', style: TextStyle(color: Colors.white54, fontSize: 48))));

    final animated = widget.transition == CgTransition.zoomIn
        ? AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final scale = 0.8 + 0.2 * Curves.easeOut.transform(_controller.value);
              return Transform.scale(
                scale: scale,
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _controller, curve: Curves.easeIn),
                  child: child,
                ),
              );
            },
            child: child,
          )
        : FadeTransition(
            opacity: CurvedAnimation(parent: _controller, curve: Curves.easeIn),
            child: child,
          );

    return GestureDetector(
      onTap: () async {
        await _controller.reverse();
        widget.onDismiss();
      },
      child: Container(
        color: Colors.black87,
        child: animated,
      ),
    );
  }
}

/// Оверлей камеры (zoom + pan) — оборачивает фон
class CameraTransformWidget extends StatefulWidget {
  final double zoom;
  final double panX;
  final double panY;
  final int duration; // мс
  final Widget child;

  const CameraTransformWidget({
    super.key,
    this.zoom = 1.0,
    this.panX = 0.0,
    this.panY = 0.0,
    this.duration = 1000,
    required this.child,
  });

  @override
  State<CameraTransformWidget> createState() => _CameraTransformWidgetState();
}

class _CameraTransformWidgetState extends State<CameraTransformWidget> {
  @override
  Widget build(BuildContext context) {
    final transform = Matrix4.identity();
    transform.storage[12] = widget.panX;
    transform.storage[13] = widget.panY;
    transform.storage[0] = widget.zoom;
    transform.storage[5] = widget.zoom;
    return AnimatedContainer(
      duration: Duration(milliseconds: widget.duration),
      curve: Curves.easeInOut,
      transform: transform,
      transformAlignment: Alignment.center,
      child: widget.child,
    );
  }
}

/// Анимированная эмоция-иконка над персонажем
class EmotionBubble extends StatefulWidget {
  final EmotionType emotionType;
  final VoidCallback? onComplete;

  const EmotionBubble({
    super.key,
    required this.emotionType,
    this.onComplete,
  });

  @override
  State<EmotionBubble> createState() => _EmotionBubbleState();
}

class _EmotionBubbleState extends State<EmotionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _emotionEmojis = {
    EmotionType.heart: '❤️',
    EmotionType.sweatDrop: '💧',
    EmotionType.question: '❓',
    EmotionType.exclamation: '❗',
    EmotionType.anger: '💢',
    EmotionType.sparkle: '✨',
    EmotionType.musicNote: '🎵',
    EmotionType.zzz: '💤',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
    final scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1.3), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_controller);

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: slideAnim,
          child: Transform.scale(
            scale: scaleAnim.value,
            child: Text(
              _emotionEmojis[widget.emotionType] ?? '❓',
              style: const TextStyle(fontSize: 36),
            ),
          ),
        );
      },
    );
  }
}

/// Параллакс фон из нескольких слоёв
class ParallaxBackground extends StatelessWidget {
  final List<BackgroundLayer> layers;
  final String novelId;
  final double scrollOffset;

  const ParallaxBackground({
    super.key,
    required this.layers,
    required this.novelId,
    this.scrollOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.expand();
        final baseDir = '${snapshot.data!.path}/novels/$novelId';
        final sorted = List<BackgroundLayer>.from(layers)
          ..sort((a, b) => a.depth.compareTo(b.depth));
        return Stack(
          fit: StackFit.expand,
          children: sorted.map((layer) {
            final offset = scrollOffset * (1.0 - layer.depth);
            final file = File('$baseDir/${layer.image}');
            return Transform.translate(
              offset: Offset(offset, 0),
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                  : Container(color: Colors.black),
            );
          }).toList(),
        );
      },
    );
  }
}
