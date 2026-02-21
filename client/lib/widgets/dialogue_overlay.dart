import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/settings_service.dart';

/// Стиль диалога как в Romance Club — декоративная рамка с орнаментом,
/// имя в фигурной вкладке, текст по центру-низу экрана
class DialogueOverlay extends ConsumerStatefulWidget {
  final String? speakerName;
  final Color? speakerColor;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onComplete;

  const DialogueOverlay({
    super.key,
    this.speakerName,
    this.speakerColor,
    required this.text,
    required this.onTap,
    this.onComplete,
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
                child: _OrnateDialogueFrame(
                  speakerName: widget.speakerName,
                  speakerColor: accentColor,
                  isNarration: isNarration,
                  displayedText: _displayedText,
                  isComplete: _isComplete,
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

/// Декоративная рамка диалога в стиле Romance Club
class _OrnateDialogueFrame extends StatelessWidget {
  final String? speakerName;
  final Color speakerColor;
  final bool isNarration;
  final String displayedText;
  final bool isComplete;

  const _OrnateDialogueFrame({
    this.speakerName,
    required this.speakerColor,
    required this.isNarration,
    required this.displayedText,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    // Цвета рамки — тёплые золотистые тона
    const frameColor1 = Color(0xFFB8860B); // dark goldenrod
    const frameColor2 = Color(0xFFDAA520); // goldenrod
    const frameColorLight = Color(0xFFE8C872); // light gold
    const frameBg = Color(0xFF1A1410); // тёмно-коричневый фон

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Вкладка с именем / точками
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [frameColor1, frameColor2, frameColor1],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            border: Border.all(color: frameColorLight, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: frameColor1.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: isNarration
              ? const Text(
                  '· · ·',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                    letterSpacing: 3,
                  ),
                )
              : Text(
                  speakerName ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
        ),

        // Основной текстовый бокс с орнаментом
        CustomPaint(
          painter: _OrnateFramePainter(
            frameColor: frameColor1,
            frameColorLight: frameColorLight,
            backgroundColor: frameBg.withValues(alpha: 0.88),
          ),
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
