import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../models/scene.dart';
import '../services/settings_service.dart';

/// Стиль диалога как в Romance Club — декоративная рамка с орнаментом,
/// имя в фигурной вкладке, текст по центру-низу экрана.
/// Поддерживает разные визуальные темы [DialogueFrameTheme].
class DialogueOverlay extends ConsumerStatefulWidget {
  final String? speakerName;
  final Color? speakerColor;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final DialogueFrameTheme frameTheme;

  const DialogueOverlay({
    super.key,
    this.speakerName,
    this.speakerColor,
    required this.text,
    required this.onTap,
    this.onComplete,
    this.frameTheme = DialogueFrameTheme.ornate,
  });

  @override
  ConsumerState<DialogueOverlay> createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends ConsumerState<DialogueOverlay>
    with SingleTickerProviderStateMixin {
  String _displayedText = '';
  int _charIndex = 0;
  bool _isComplete = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _startTyping();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DialogueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.speakerName != widget.speakerName) {
      _displayedText = '';
      _charIndex = 0;
      _isComplete = false;
      _fadeController.forward(from: 0);
      _startTyping();
    }
  }

  void _startTyping() {
    final settings = ref.read(settingsServiceProvider);
    final charDelay = settings.charDelayMs;

    if (charDelay == 0) {
      setState(() {
        _displayedText = widget.text;
        _charIndex = widget.text.length;
        _isComplete = true;
      });
      widget.onComplete?.call();
      _scheduleAutoPlay();
      return;
    }

    Future.doWhile(() async {
      await Future.delayed(Duration(milliseconds: charDelay));
      if (!mounted) return false;
      if (_charIndex >= widget.text.length) {
        setState(() => _isComplete = true);
        widget.onComplete?.call();
        _scheduleAutoPlay();
        return false;
      }
      setState(() {
        _displayedText = widget.text.substring(0, _charIndex + 1);
        _charIndex++;
      });
      return true;
    });
  }

  void _scheduleAutoPlay() {
    final settings = ref.read(settingsServiceProvider);
    if (!settings.autoPlay) return;

    Future.delayed(Duration(seconds: settings.autoPlayDelay), () {
      if (mounted && _isComplete) {
        widget.onTap();
      }
    });
  }

  void _skipToEnd() {
    setState(() {
      _displayedText = widget.text;
      _charIndex = widget.text.length;
      _isComplete = true;
    });
    widget.onComplete?.call();
    _scheduleAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    final isNarration = widget.speakerName == null;
    final accentColor = widget.speakerColor ?? AppTheme.primary;

    return GestureDetector(
      onTap: () {
        if (!_isComplete) {
          _skipToEnd();
        } else {
          widget.onTap();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            const Spacer(),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ThemedDialogueFrame(
                  speakerName: widget.speakerName,
                  speakerColor: accentColor,
                  isNarration: isNarration,
                  displayedText: _displayedText,
                  isComplete: _isComplete,
                  frameTheme: widget.frameTheme,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }
}

/// Конфигурация цветов для темы рамки
class _FrameColors {
  final Color primary;
  final Color secondary;
  final Color light;
  final Color background;
  final Color nameGradient1;
  final Color nameGradient2;

  const _FrameColors({
    required this.primary,
    required this.secondary,
    required this.light,
    required this.background,
    required this.nameGradient1,
    required this.nameGradient2,
  });

  static _FrameColors forTheme(DialogueFrameTheme theme) {
    switch (theme) {
      case DialogueFrameTheme.ornate:
        return const _FrameColors(
          primary: Color(0xFFB8860B),
          secondary: Color(0xFFDAA520),
          light: Color(0xFFE8C872),
          background: Color(0xFF1A1410),
          nameGradient1: Color(0xFFB8860B),
          nameGradient2: Color(0xFFDAA520),
        );
      case DialogueFrameTheme.artDeco:
        return const _FrameColors(
          primary: Color(0xFF8B7355),
          secondary: Color(0xFFC4A265),
          light: Color(0xFFD4B896),
          background: Color(0xFF0F1B2D),
          nameGradient1: Color(0xFF1A2A4A),
          nameGradient2: Color(0xFF2A3A5A),
        );
      case DialogueFrameTheme.modern:
        return const _FrameColors(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF8B83FF),
          light: Color(0xFFB0ABFF),
          background: Color(0xFF1A1A2E),
          nameGradient1: Color(0xFF6C63FF),
          nameGradient2: Color(0xFF8B83FF),
        );
      case DialogueFrameTheme.glassmorphism:
        return const _FrameColors(
          primary: Color(0x80FFFFFF),
          secondary: Color(0x60FFFFFF),
          light: Color(0x40FFFFFF),
          background: Color(0x30FFFFFF),
          nameGradient1: Color(0x50FFFFFF),
          nameGradient2: Color(0x30FFFFFF),
        );
      case DialogueFrameTheme.fantasy:
        return const _FrameColors(
          primary: Color(0xFF7B2D8E),
          secondary: Color(0xFFA855F7),
          light: Color(0xFFD8B4FE),
          background: Color(0xFF140A1F),
          nameGradient1: Color(0xFF7B2D8E),
          nameGradient2: Color(0xFFA855F7),
        );
    }
  }
}

/// Декоративная рамка диалога — с разными темами
class _ThemedDialogueFrame extends StatelessWidget {
  final String? speakerName;
  final Color speakerColor;
  final bool isNarration;
  final String displayedText;
  final bool isComplete;
  final DialogueFrameTheme frameTheme;

  const _ThemedDialogueFrame({
    this.speakerName,
    required this.speakerColor,
    required this.isNarration,
    required this.displayedText,
    required this.isComplete,
    required this.frameTheme,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _FrameColors.forTheme(frameTheme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Вкладка с именем
        _buildNameTab(colors),

        // Основной текстовый бокс
        CustomPaint(
          painter: _getFramePainter(colors),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isNarration
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  displayedText,
                  textAlign: isNarration ? TextAlign.center : TextAlign.left,
                  style: TextStyle(
                    fontSize: 17,
                    color: isNarration
                        ? Colors.white70
                        : Colors.white.withValues(alpha: 0.92),
                    height: 1.55,
                    fontStyle:
                        isNarration ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (isComplete) ...[
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _PulsingArrow(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameTab(_FrameColors colors) {
    final borderRadius = frameTheme == DialogueFrameTheme.artDeco
        ? const BorderRadius.vertical(top: Radius.circular(2))
        : const BorderRadius.vertical(top: Radius.circular(14));

    Widget nameContent;
    if (isNarration) {
      nameContent = const Text('· · ·',
        style: TextStyle(fontSize: 14, color: Colors.white60, letterSpacing: 3));
    } else {
      nameContent = Text(speakerName ?? '',
        style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
          letterSpacing: 0.5,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
        ));
    }

    if (frameTheme == DialogueFrameTheme.glassmorphism) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: borderRadius,
            border: Border.all(color: colors.primary, width: 0.8),
          ),
          child: nameContent,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.nameGradient1, colors.nameGradient2, colors.nameGradient1],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: colors.light, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 8, offset: const Offset(0, -2),
          ),
        ],
      ),
      child: nameContent,
    );
  }

  CustomPainter _getFramePainter(_FrameColors colors) {
    switch (frameTheme) {
      case DialogueFrameTheme.ornate:
        return _OrnateFramePainter(
          frameColor: colors.primary,
          frameColorLight: colors.light,
          backgroundColor: colors.background.withValues(alpha: 0.88),
        );
      case DialogueFrameTheme.artDeco:
        return _ArtDecoFramePainter(
          frameColor: colors.primary,
          frameColorLight: colors.light,
          backgroundColor: colors.background.withValues(alpha: 0.92),
        );
      case DialogueFrameTheme.modern:
        return _ModernFramePainter(
          frameColor: colors.primary,
          frameColorLight: colors.light,
          backgroundColor: colors.background.withValues(alpha: 0.9),
        );
      case DialogueFrameTheme.glassmorphism:
        return _GlassmorphismFramePainter(
          backgroundColor: colors.background,
          borderColor: colors.primary,
        );
      case DialogueFrameTheme.fantasy:
        return _FantasyFramePainter(
          frameColor: colors.primary,
          frameColorLight: colors.light,
          backgroundColor: colors.background.withValues(alpha: 0.88),
        );
    }
  }
}

/// CustomPainter для декоративной рамки с орнаментальными углами
class _OrnateFramePainter extends CustomPainter {
  final Color frameColor;
  final Color frameColorLight;
  final Color backgroundColor;

  _OrnateFramePainter({
    required this.frameColor,
    required this.frameColorLight,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = 4.0; // corner radius

    // Фон
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndCorners(rect,
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r),
      ),
      bgPaint,
    );

    // Внешняя рамка
    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [frameColorLight, frameColor, frameColorLight],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndCorners(rect,
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r),
      ),
      outerPaint,
    );

    // Внутренняя тонкая рамка (inset)
    final innerRect = rect.deflate(6);
    final innerPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(r)),
      innerPaint,
    );

    // Декоративные углы
    _drawCornerOrnament(canvas, size, 0, 0, 1, 1); // top-left
    _drawCornerOrnament(canvas, size, size.width, 0, -1, 1); // top-right
    _drawCornerOrnament(canvas, size, 0, size.height, 1, -1); // bottom-left
    _drawCornerOrnament(canvas, size, size.width, size.height, -1, -1); // bottom-right

    // Горизонтальные декоративные линии (верх и низ)
    _drawHorizontalOrnament(canvas, size, isTop: true);
    _drawHorizontalOrnament(canvas, size, isTop: false);
  }

  void _drawCornerOrnament(Canvas canvas, Size size, double x, double y, double dx, double dy) {
    final paint = Paint()
      ..color = frameColorLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cornerSize = 16.0;

    // L-образная фигура
    final path = Path();
    path.moveTo(x + dx * 4, y + dy * cornerSize);
    path.lineTo(x + dx * 4, y + dy * 4);
    path.lineTo(x + dx * cornerSize, y + dy * 4);
    canvas.drawPath(path, paint);

    // Маленький ромбик
    final diamondPaint = Paint()
      ..color = frameColorLight
      ..style = PaintingStyle.fill;

    final cx = x + dx * 10;
    final cy = y + dy * 10;
    final ds = 3.0;
    final diamond = Path()
      ..moveTo(cx, cy - ds)
      ..lineTo(cx + ds, cy)
      ..lineTo(cx, cy + ds)
      ..lineTo(cx - ds, cy)
      ..close();
    canvas.drawPath(diamond, diamondPaint);
  }

  void _drawHorizontalOrnament(Canvas canvas, Size size, {required bool isTop}) {
    final y = isTop ? 0.0 : size.height;
    final centerX = size.width / 2;
    final ornamentWidth = 40.0;

    final paint = Paint()
      ..color = frameColorLight.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Маленькие декоративные штрихи по центру
    final dy = isTop ? 6.0 : -6.0;
    canvas.drawLine(
      Offset(centerX - ornamentWidth, y + dy),
      Offset(centerX - 8, y + dy),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + 8, y + dy),
      Offset(centerX + ornamentWidth, y + dy),
      paint,
    );

    // Центральный ромбик
    final dp = Paint()
      ..color = frameColorLight.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final d = 3.0;
    final diamond = Path()
      ..moveTo(centerX, y + dy - d)
      ..lineTo(centerX + d, y + dy)
      ..lineTo(centerX, y + dy + d)
      ..lineTo(centerX - d, y + dy)
      ..close();
    canvas.drawPath(diamond, dp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────
// Art Deco — геометрические угольники, строгие линии
// ─────────────────────────────────────────────────────
class _ArtDecoFramePainter extends CustomPainter {
  final Color frameColor;
  final Color frameColorLight;
  final Color backgroundColor;

  _ArtDecoFramePainter({
    required this.frameColor,
    required this.frameColorLight,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Фон
    canvas.drawRect(rect, Paint()..color = backgroundColor);

    // Внешняя рамка — двойная линия
    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [frameColorLight, frameColor, frameColorLight],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, outerPaint);

    // Внутренняя рамка
    final innerRect = rect.deflate(5);
    canvas.drawRect(innerRect, Paint()
      ..color = frameColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    // Геометрические угловые элементы — скошенные трапеции
    final cornerSize = 20.0;
    final linePaint = Paint()
      ..color = frameColorLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    // Верхний левый — шестиугольный уголок
    _drawDecoCorner(canvas, 0, 0, 1, 1, cornerSize, linePaint);
    _drawDecoCorner(canvas, size.width, 0, -1, 1, cornerSize, linePaint);
    _drawDecoCorner(canvas, 0, size.height, 1, -1, cornerSize, linePaint);
    _drawDecoCorner(canvas, size.width, size.height, -1, -1, cornerSize, linePaint);

    // Горизонтальные декоративные элементы — «ступеньки»
    _drawDecoHLine(canvas, size, isTop: true);
    _drawDecoHLine(canvas, size, isTop: false);
  }

  void _drawDecoCorner(Canvas canvas, double x, double y, double dx, double dy, double s, Paint paint) {
    // Шестиугольный/геометрический уголок
    final path = Path()
      ..moveTo(x + dx * 3, y + dy * s)
      ..lineTo(x + dx * 3, y + dy * 8)
      ..lineTo(x + dx * 8, y + dy * 3)
      ..lineTo(x + dx * s, y + dy * 3);
    canvas.drawPath(path, paint);

    // Ромб внутри угла
    final cx = x + dx * 12;
    final cy = y + dy * 12;
    final d = 2.5;
    final diamond = Path()
      ..moveTo(cx, cy - d)
      ..lineTo(cx + d, cy)
      ..lineTo(cx, cy + d)
      ..lineTo(cx - d, cy)
      ..close();
    canvas.drawPath(diamond, Paint()
      ..color = frameColorLight
      ..style = PaintingStyle.fill);
  }

  void _drawDecoHLine(Canvas canvas, Size size, {required bool isTop}) {
    final y = isTop ? 7.0 : size.height - 7.0;
    final centerX = size.width / 2;
    final paint = Paint()
      ..color = frameColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Три параллельные линии (ступеньки)
    canvas.drawLine(Offset(centerX - 35, y), Offset(centerX - 5, y), paint);
    canvas.drawLine(Offset(centerX + 5, y), Offset(centerX + 35, y), paint);

    // Центральный квадрат
    final sq = 3.0;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(centerX, y), width: sq * 2, height: sq * 2),
      Paint()..color = frameColorLight.withValues(alpha: 0.6)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// Modern — чистые тонкие линии, градиент
// ─────────────────────────────────────────────
class _ModernFramePainter extends CustomPainter {
  final Color frameColor;
  final Color frameColorLight;
  final Color backgroundColor;

  _ModernFramePainter({
    required this.frameColor,
    required this.frameColorLight,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = 8.0;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // Фон с лёгким градиентом
    canvas.drawRRect(rrect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundColor, backgroundColor.withValues(alpha: 0.95)],
      ).createShader(rect));

    // Одна элегантная рамка
    canvas.drawRRect(rrect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [frameColor, frameColorLight, frameColor],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Акцентная полоска сверху
    final accentRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, 3),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(accentRect, Paint()
      ..shader = LinearGradient(
        colors: [frameColor, frameColorLight, frameColor],
      ).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// Glassmorphism — полупрозрачное стекло
// ─────────────────────────────────────────────
class _GlassmorphismFramePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  _GlassmorphismFramePainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = 16.0;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // Полупрозрачный фон
    canvas.drawRRect(rrect, Paint()..color = backgroundColor);

    // Тонкая полупрозрачная рамка
    canvas.drawRRect(rrect, Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    // Блик сверху (имитация стекла)
    final highlightRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(highlightRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// Fantasy — завитки, мистические элементы
// ─────────────────────────────────────────────
class _FantasyFramePainter extends CustomPainter {
  final Color frameColor;
  final Color frameColorLight;
  final Color backgroundColor;

  _FantasyFramePainter({
    required this.frameColor,
    required this.frameColorLight,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = 6.0;

    // Фон
    canvas.drawRRect(
      RRect.fromRectAndCorners(rect,
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r)),
      Paint()..color = backgroundColor,
    );

    // Двойная рамка
    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [frameColorLight, frameColor, frameColorLight],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndCorners(rect,
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r)),
      outerPaint,
    );

    final innerRect = rect.deflate(5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(r)),
      Paint()
        ..color = frameColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Завитки в углах
    _drawSwirlCorner(canvas, 0, 0, 1, 1);
    _drawSwirlCorner(canvas, size.width, 0, -1, 1);
    _drawSwirlCorner(canvas, 0, size.height, 1, -1);
    _drawSwirlCorner(canvas, size.width, size.height, -1, -1);

    // Звёздочки-акценты
    _drawStar(canvas, size.width / 2, 6);
    _drawStar(canvas, size.width / 2, size.height - 6);
  }

  void _drawSwirlCorner(Canvas canvas, double x, double y, double dx, double dy) {
    final paint = Paint()
      ..color = frameColorLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Дуга-завиток
    final path = Path();
    path.moveTo(x + dx * 4, y + dy * 18);
    path.quadraticBezierTo(x + dx * 4, y + dy * 4, x + dx * 12, y + dy * 4);
    path.quadraticBezierTo(x + dx * 8, y + dy * 8, x + dx * 6, y + dy * 12);
    canvas.drawPath(path, paint);

    // Точка на конце завитка
    canvas.drawCircle(
      Offset(x + dx * 6, y + dy * 12),
      2.0,
      Paint()..color = frameColorLight..style = PaintingStyle.fill,
    );
  }

  void _drawStar(Canvas canvas, double cx, double cy) {
    final paint = Paint()
      ..color = frameColorLight.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    const spikes = 4;
    const outerR = 4.0;
    const innerR = 1.5;

    for (int i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / spikes) - math.pi / 2;
      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulsingArrow extends StatefulWidget {
  const _PulsingArrow();

  @override
  State<_PulsingArrow> createState() => _PulsingArrowState();
}

class _PulsingArrowState extends State<_PulsingArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.3 + 0.5 * _controller.value,
        child: Transform.translate(
          offset: Offset(2 * _controller.value, 0),
          child: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white38,
            size: 14,
          ),
        ),
      ),
    );
  }
}
