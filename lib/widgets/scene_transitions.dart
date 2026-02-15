import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
  File? _spriteFile;
  bool _resolved = false;

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
    _resolveSprite();
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
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _resolved && _spriteFile != null
            ? Image.file(
                _spriteFile!,
                height: 350,
                fit: BoxFit.contain,
              )
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
