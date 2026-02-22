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
  final Color? customFrameColor;
  final Color? customBgColor;
  final bool centered;
  final String speakerSide; // 'left', 'right', 'center'

  const DialogueOverlay({
    super.key,
    this.speakerName,
    this.speakerColor,
    required this.text,
    required this.onTap,
    this.onComplete,
    this.frameTheme = DialogueFrameTheme.ornate,
    this.customFrameColor,
    this.customBgColor,
    this.centered = false,
    this.speakerSide = 'center',
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
            if (widget.centered) const Spacer(),
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
                  customFrameColor: widget.customFrameColor,
                  customBgColor: widget.customBgColor,
                  speakerSide: widget.speakerSide,
                ),
              ),
            ),
            if (widget.centered)
              const Spacer()
            else
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Modular theme system — 20 genre-specific frame styles
// ═══════════════════════════════════════════════════════

/// Corner ornament drawing style
enum _CornerType { lBracket, stepped, swirl, pointed, petal, clip, gear, rope, shield, lotus, acanthus, heart, knot, leaf, thorn, none }

/// Center ornament drawing style
enum _CenterType { diamond, square, star4, cross, moon, gearSmall, compass, ankh, shell, heartSmall, rune, sun, thornStar, petalSmall, none }

/// Color palette for a theme
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

  static _FrameColors forTheme(DialogueFrameTheme theme, {Color? customFrame, Color? customBg}) {
    final base = _palettes[theme]!;
    if (customFrame == null && customBg == null) return base;
    return _FrameColors(
      primary: customFrame ?? base.primary,
      secondary: customFrame?.withValues(alpha: 0.8) ?? base.secondary,
      light: customFrame?.withValues(alpha: 0.6) ?? base.light,
      background: customBg ?? base.background,
      nameGradient1: customFrame ?? base.nameGradient1,
      nameGradient2: customFrame?.withValues(alpha: 0.7) ?? base.nameGradient2,
    );
  }

  static const _palettes = <DialogueFrameTheme, _FrameColors>{
    DialogueFrameTheme.ornate: _FrameColors(
      primary: Color(0xFFB8860B), secondary: Color(0xFFDAA520), light: Color(0xFFE8C872),
      background: Color(0xFF1A1410), nameGradient1: Color(0xFFB8860B), nameGradient2: Color(0xFFDAA520)),
    DialogueFrameTheme.artDeco: _FrameColors(
      primary: Color(0xFF8B7355), secondary: Color(0xFFC4A265), light: Color(0xFFD4B896),
      background: Color(0xFF0F1B2D), nameGradient1: Color(0xFF1A2A4A), nameGradient2: Color(0xFF2A3A5A)),
    DialogueFrameTheme.modern: _FrameColors(
      primary: Color(0xFF6C63FF), secondary: Color(0xFF8B83FF), light: Color(0xFFB0ABFF),
      background: Color(0xFF1A1A2E), nameGradient1: Color(0xFF6C63FF), nameGradient2: Color(0xFF8B83FF)),
    DialogueFrameTheme.glassmorphism: _FrameColors(
      primary: Color(0x80FFFFFF), secondary: Color(0x60FFFFFF), light: Color(0x40FFFFFF),
      background: Color(0x30FFFFFF), nameGradient1: Color(0x50FFFFFF), nameGradient2: Color(0x30FFFFFF)),
    DialogueFrameTheme.fantasy: _FrameColors(
      primary: Color(0xFF7B2D8E), secondary: Color(0xFFA855F7), light: Color(0xFFD8B4FE),
      background: Color(0xFF140A1F), nameGradient1: Color(0xFF7B2D8E), nameGradient2: Color(0xFFA855F7)),
    DialogueFrameTheme.victorian: _FrameColors(
      primary: Color(0xFF8B6914), secondary: Color(0xFFC9A84C), light: Color(0xFFDEC07C),
      background: Color(0xFF1E150E), nameGradient1: Color(0xFF8B6914), nameGradient2: Color(0xFFC9A84C)),
    DialogueFrameTheme.gothic: _FrameColors(
      primary: Color(0xFF8B1A1A), secondary: Color(0xFFC62828), light: Color(0xFFE57373),
      background: Color(0xFF0D0808), nameGradient1: Color(0xFF8B1A1A), nameGradient2: Color(0xFFC62828)),
    DialogueFrameTheme.noir: _FrameColors(
      primary: Color(0xFF707070), secondary: Color(0xFFA0A0A0), light: Color(0xFFC0C0C0),
      background: Color(0xFF0F0F0F), nameGradient1: Color(0xFF404040), nameGradient2: Color(0xFF606060)),
    DialogueFrameTheme.sakura: _FrameColors(
      primary: Color(0xFFD4618C), secondary: Color(0xFFF06292), light: Color(0xFFF8BBD0),
      background: Color(0xFF1A0E14), nameGradient1: Color(0xFFD4618C), nameGradient2: Color(0xFFF06292)),
    DialogueFrameTheme.celestial: _FrameColors(
      primary: Color(0xFF5C6BC0), secondary: Color(0xFF7986CB), light: Color(0xFFC5CAE9),
      background: Color(0xFF0A0E1A), nameGradient1: Color(0xFF3F51B5), nameGradient2: Color(0xFF5C6BC0)),
    DialogueFrameTheme.cyberpunk: _FrameColors(
      primary: Color(0xFF00BCD4), secondary: Color(0xFFE91E63), light: Color(0xFF80DEEA),
      background: Color(0xFF0A0A14), nameGradient1: Color(0xFF00BCD4), nameGradient2: Color(0xFFE91E63)),
    DialogueFrameTheme.steampunk: _FrameColors(
      primary: Color(0xFFB87333), secondary: Color(0xFFCD853F), light: Color(0xFFDEB887),
      background: Color(0xFF1A1008), nameGradient1: Color(0xFFB87333), nameGradient2: Color(0xFFCD853F)),
    DialogueFrameTheme.pirate: _FrameColors(
      primary: Color(0xFF8B6914), secondary: Color(0xFFA0785A), light: Color(0xFFC4A882),
      background: Color(0xFF14100A), nameGradient1: Color(0xFF6B4F0A), nameGradient2: Color(0xFF8B6914)),
    DialogueFrameTheme.medieval: _FrameColors(
      primary: Color(0xFF6B5B3C), secondary: Color(0xFF9C8B6C), light: Color(0xFFC4B99A),
      background: Color(0xFF12100A), nameGradient1: Color(0xFF5B4B2C), nameGradient2: Color(0xFF6B5B3C)),
    DialogueFrameTheme.egyptian: _FrameColors(
      primary: Color(0xFFC5A028), secondary: Color(0xFF1565C0), light: Color(0xFFFFD54F),
      background: Color(0xFF0D0A05), nameGradient1: Color(0xFFC5A028), nameGradient2: Color(0xFF1565C0)),
    DialogueFrameTheme.baroque: _FrameColors(
      primary: Color(0xFFB8860B), secondary: Color(0xFFD4AF37), light: Color(0xFFF0E68C),
      background: Color(0xFF18120A), nameGradient1: Color(0xFFB8860B), nameGradient2: Color(0xFFD4AF37)),
    DialogueFrameTheme.romantic: _FrameColors(
      primary: Color(0xFFD81B60), secondary: Color(0xFFEC407A), light: Color(0xFFF8BBD0),
      background: Color(0xFF1A0A10), nameGradient1: Color(0xFFD81B60), nameGradient2: Color(0xFFEC407A)),
    DialogueFrameTheme.nordic: _FrameColors(
      primary: Color(0xFF4FC3F7), secondary: Color(0xFF81D4FA), light: Color(0xFFB3E5FC),
      background: Color(0xFF0A0E14), nameGradient1: Color(0xFF0288D1), nameGradient2: Color(0xFF4FC3F7)),
    DialogueFrameTheme.tropical: _FrameColors(
      primary: Color(0xFF00897B), secondary: Color(0xFF26A69A), light: Color(0xFF80CBC4),
      background: Color(0xFF0A1410), nameGradient1: Color(0xFF00897B), nameGradient2: Color(0xFF26A69A)),
    DialogueFrameTheme.bloodMoon: _FrameColors(
      primary: Color(0xFFB71C1C), secondary: Color(0xFFD32F2F), light: Color(0xFFE57373),
      background: Color(0xFF0D0505), nameGradient1: Color(0xFF7F0000), nameGradient2: Color(0xFFB71C1C)),
  };
}

/// Visual specification for each theme — drives the universal painter
class _ThemeSpec {
  final double radius;
  final double borderWidth;
  final int borderCount;
  final _CornerType cornerType;
  final _CenterType centerType;
  final bool hasSideDecor;
  final bool topAccentStripe;
  final double nameTabRadius;

  const _ThemeSpec({
    this.radius = 4,
    this.borderWidth = 2.0,
    this.borderCount = 2,
    this.cornerType = _CornerType.lBracket,
    this.centerType = _CenterType.diamond,
    this.hasSideDecor = false,
    this.topAccentStripe = false,
    this.nameTabRadius = 14,
  });

  static _ThemeSpec forTheme(DialogueFrameTheme t) => _specs[t]!;

  static const _specs = <DialogueFrameTheme, _ThemeSpec>{
    // Classic gold L-brackets + diamonds
    DialogueFrameTheme.ornate: _ThemeSpec(
      cornerType: _CornerType.lBracket, centerType: _CenterType.diamond, hasSideDecor: true),
    // 1920s geometric stepped corners
    DialogueFrameTheme.artDeco: _ThemeSpec(
      cornerType: _CornerType.stepped, centerType: _CenterType.square, borderCount: 3, nameTabRadius: 2),
    // Clean minimalist — accent stripe only
    DialogueFrameTheme.modern: _ThemeSpec(
      radius: 8, borderCount: 1, cornerType: _CornerType.none, centerType: _CenterType.none, topAccentStripe: true),
    // Frosted glass — handled by separate painter
    DialogueFrameTheme.glassmorphism: _ThemeSpec(
      radius: 16, borderCount: 1, cornerType: _CornerType.none, centerType: _CenterType.none, nameTabRadius: 12),
    // Purple mystical swirls + stars
    DialogueFrameTheme.fantasy: _ThemeSpec(
      radius: 6, cornerType: _CornerType.swirl, centerType: _CenterType.star4, hasSideDecor: true),
    // Warm brown filigree double-swirl
    DialogueFrameTheme.victorian: _ThemeSpec(
      cornerType: _CornerType.acanthus, centerType: _CenterType.diamond, hasSideDecor: true, borderCount: 3),
    // Dark pointed arches + cross
    DialogueFrameTheme.gothic: _ThemeSpec(
      cornerType: _CornerType.pointed, centerType: _CenterType.cross, nameTabRadius: 6),
    // Minimal silver, no ornaments
    DialogueFrameTheme.noir: _ThemeSpec(
      borderCount: 1, borderWidth: 1.0, cornerType: _CornerType.none, centerType: _CenterType.none, nameTabRadius: 2),
    // Pink petals + cherry blossom
    DialogueFrameTheme.sakura: _ThemeSpec(
      radius: 8, cornerType: _CornerType.petal, centerType: _CenterType.petalSmall),
    // Silver moon + stars
    DialogueFrameTheme.celestial: _ThemeSpec(
      radius: 6, cornerType: _CornerType.swirl, centerType: _CenterType.moon, hasSideDecor: true),
    // Neon clipped corners + glitch
    DialogueFrameTheme.cyberpunk: _ThemeSpec(
      cornerType: _CornerType.clip, centerType: _CenterType.none, nameTabRadius: 2, borderWidth: 1.5),
    // Copper gears + rivets
    DialogueFrameTheme.steampunk: _ThemeSpec(
      cornerType: _CornerType.gear, centerType: _CenterType.gearSmall, hasSideDecor: true, nameTabRadius: 4),
    // Rope corners + compass
    DialogueFrameTheme.pirate: _ThemeSpec(
      cornerType: _CornerType.rope, centerType: _CenterType.compass, nameTabRadius: 4),
    // Shield brackets + cross
    DialogueFrameTheme.medieval: _ThemeSpec(
      cornerType: _CornerType.shield, centerType: _CenterType.cross, nameTabRadius: 4, borderCount: 3),
    // Lotus + ankh
    DialogueFrameTheme.egyptian: _ThemeSpec(
      cornerType: _CornerType.lotus, centerType: _CenterType.ankh, borderCount: 3),
    // Acanthus scrollwork + shell
    DialogueFrameTheme.baroque: _ThemeSpec(
      cornerType: _CornerType.acanthus, centerType: _CenterType.shell, hasSideDecor: true, borderCount: 3),
    // Heart corners + lace
    DialogueFrameTheme.romantic: _ThemeSpec(
      radius: 10, cornerType: _CornerType.heart, centerType: _CenterType.heartSmall),
    // Ice knot + rune
    DialogueFrameTheme.nordic: _ThemeSpec(
      cornerType: _CornerType.knot, centerType: _CenterType.rune),
    // Leaf + wave
    DialogueFrameTheme.tropical: _ThemeSpec(
      radius: 8, cornerType: _CornerType.leaf, centerType: _CenterType.sun),
    // Thorns + crescent
    DialogueFrameTheme.bloodMoon: _ThemeSpec(
      cornerType: _CornerType.thorn, centerType: _CenterType.thornStar, hasSideDecor: true),
  };
}

/// Декоративная рамка диалога — с разными темами
class _ThemedDialogueFrame extends StatelessWidget {
  final String? speakerName;
  final Color speakerColor;
  final bool isNarration;
  final String displayedText;
  final bool isComplete;
  final DialogueFrameTheme frameTheme;
  final Color? customFrameColor;
  final Color? customBgColor;
  final String speakerSide;

  const _ThemedDialogueFrame({
    this.speakerName,
    required this.speakerColor,
    required this.isNarration,
    required this.displayedText,
    required this.isComplete,
    required this.frameTheme,
    this.customFrameColor,
    this.customBgColor,
    this.speakerSide = 'center',
  });

  @override
  Widget build(BuildContext context) {
    final colors = _FrameColors.forTheme(frameTheme,
        customFrame: customFrameColor, customBg: customBgColor);
    final spec = _ThemeSpec.forTheme(frameTheme);

    // Name tab alignment based on speaker position
    final nameAlignment = isNarration
        ? CrossAxisAlignment.center
        : speakerSide == 'right'
            ? CrossAxisAlignment.end
            : speakerSide == 'left'
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: nameAlignment,
      children: [
        _buildNameTab(colors, spec),
        CustomPaint(
          painter: frameTheme == DialogueFrameTheme.glassmorphism
              ? _GlassmorphismFramePainter(
                  backgroundColor: colors.background,
                  borderColor: colors.primary,
                  isNarration: isNarration,
                  speakerSide: speakerSide)
              : _UniversalFramePainter(
                  colors: colors,
                  spec: spec,
                  isNarration: isNarration,
                  speakerSide: speakerSide),
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

  Widget _buildNameTab(_FrameColors colors, _ThemeSpec spec) {
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(spec.nameTabRadius),
    );

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
}

// ═══════════════════════════════════════════════════════
// Universal frame painter — renders any theme from spec
// ═══════════════════════════════════════════════════════
class _UniversalFramePainter extends CustomPainter {
  final _FrameColors colors;
  final _ThemeSpec spec;
  final bool isNarration;
  final String speakerSide;

  _UniversalFramePainter({
    required this.colors,
    required this.spec,
    this.isNarration = false,
    this.speakerSide = 'center',
  });

  /// Frame path with smooth speech-bubble tail on the bottom edge
  Path _buildFramePath(Size size) {
    final r = spec.radius;

    if (isNarration) {
      return Path()..addRRect(RRect.fromRectAndCorners(
        Offset.zero & size,
        bottomLeft: Radius.circular(r),
        bottomRight: Radius.circular(r),
      ));
    }

    // Tail on TOP edge, on the OPPOSITE side of the speaker
    const tailW = 24.0; // base width
    const tailH = 14.0; // how far up it extends
    const curveMag = 5.0; // how much the tip curves toward the speaker

    // Tail position (opposite side of speaker)
    double tailCX;
    double curveBias; // horizontal offset of the tip toward the speaker
    if (speakerSide == 'left') {
      tailCX = size.width * 0.75; // tail on right
      curveBias = -curveMag; // tip curves left (toward speaker)
    } else if (speakerSide == 'right') {
      tailCX = size.width * 0.25; // tail on left
      curveBias = curveMag; // tip curves right (toward speaker)
    } else {
      tailCX = size.width * 0.5;
      curveBias = 0;
    }
    tailCX = tailCX.clamp(tailW / 2 + 2, size.width - tailW / 2 - 2);

    final path = Path();

    // Top edge with tail (left to right)
    path.moveTo(0, 0);
    path.lineTo(tailCX - tailW / 2, 0);
    // Smooth curved tail pointing up, leaning toward speaker
    path.quadraticBezierTo(
      tailCX - tailW * 0.12 + curveBias * 0.5, -tailH * 0.55,
      tailCX + curveBias, -tailH,
    );
    path.quadraticBezierTo(
      tailCX + tailW * 0.12 + curveBias * 0.5, -tailH * 0.55,
      tailCX + tailW / 2, 0,
    );
    path.lineTo(size.width, 0);

    // Right side
    path.lineTo(size.width, size.height - r);

    // Bottom-right corner
    path.arcToPoint(Offset(size.width - r, size.height), radius: Radius.circular(r));
    path.lineTo(r, size.height);
    // Bottom-left corner
    path.arcToPoint(Offset(0, size.height - r), radius: Radius.circular(r));

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = spec.radius;
    final framePath = _buildFramePath(size);

    // 1. Background
    canvas.drawPath(
      framePath,
      Paint()..color = colors.background.withValues(alpha: 0.9),
    );

    // 2. Outer border (gradient)
    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.light, colors.primary, colors.light, colors.primary, colors.light],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = spec.borderWidth;
    canvas.drawPath(framePath, outerPaint);

    // 3. Inner border(s)
    if (spec.borderCount >= 2) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(6), Radius.circular(r)),
        Paint()
          ..color = colors.primary.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    if (spec.borderCount >= 3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(9), Radius.circular(r)),
        Paint()
          ..color = colors.primary.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    // 4. Top accent stripe (modern)
    if (spec.topAccentStripe) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, 3),
          topLeft: Radius.circular(r), topRight: Radius.circular(r)),
        Paint()
          ..shader = LinearGradient(colors: [colors.primary, colors.light, colors.primary]).createShader(rect),
      );
    }

    // 5. Corner ornaments
    if (spec.cornerType != _CornerType.none) {
      _drawCorner(canvas, size, 0, 0, 1, 1);
      _drawCorner(canvas, size, size.width, 0, -1, 1);
      _drawCorner(canvas, size, 0, size.height, 1, -1);
      _drawCorner(canvas, size, size.width, size.height, -1, -1);
    }

    // 6. Center ornaments
    if (spec.centerType != _CenterType.none) {
      _drawCenterOrnament(canvas, size.width / 2, 6);
      _drawCenterOrnament(canvas, size.width / 2, size.height - 6);
    }

    // 7. Side decorations
    if (spec.hasSideDecor) {
      _drawSideDecor(canvas, size, isLeft: true);
      _drawSideDecor(canvas, size, isLeft: false);
    }
  }

  // ── Corner ornament dispatchers ──

  void _drawCorner(Canvas canvas, Size size, double x, double y, double dx, double dy) {
    switch (spec.cornerType) {
      case _CornerType.lBracket: _drawLBracket(canvas, x, y, dx, dy);
      case _CornerType.stepped: _drawStepped(canvas, x, y, dx, dy);
      case _CornerType.swirl: _drawSwirl(canvas, x, y, dx, dy);
      case _CornerType.pointed: _drawPointed(canvas, x, y, dx, dy);
      case _CornerType.petal: _drawPetal(canvas, x, y, dx, dy);
      case _CornerType.clip: _drawClip(canvas, x, y, dx, dy);
      case _CornerType.gear: _drawGear(canvas, x, y, dx, dy);
      case _CornerType.rope: _drawRope(canvas, x, y, dx, dy);
      case _CornerType.shield: _drawShield(canvas, x, y, dx, dy);
      case _CornerType.lotus: _drawLotus(canvas, x, y, dx, dy);
      case _CornerType.acanthus: _drawAcanthus(canvas, x, y, dx, dy);
      case _CornerType.heart: _drawHeart(canvas, x, y, dx, dy);
      case _CornerType.knot: _drawKnot(canvas, x, y, dx, dy);
      case _CornerType.leaf: _drawLeaf(canvas, x, y, dx, dy);
      case _CornerType.thorn: _drawThorn(canvas, x, y, dx, dy);
      case _CornerType.none: break;
    }
  }

  Paint get _cp => Paint()..color = colors.light..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
  Paint get _cf => Paint()..color = colors.light..style = PaintingStyle.fill;
  Paint get _cp2 => Paint()..color = colors.light.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 0.8..strokeCap = StrokeCap.round;

  // Gold classic — L-bracket + diamond
  void _drawLBracket(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*18)..lineTo(x+dx*4, y+dy*4)..lineTo(x+dx*18, y+dy*4), _cp);
    final cx = x+dx*11, cy = y+dy*11;
    c.drawPath(Path()..moveTo(cx, cy-3.5)..lineTo(cx+3.5, cy)..lineTo(cx, cy+3.5)..lineTo(cx-3.5, cy)..close(), _cf);
    // Small extra swirl
    c.drawPath(Path()..moveTo(x+dx*18, y+dy*8)..quadraticBezierTo(x+dx*22, y+dy*8, x+dx*22, y+dy*12), _cp2);
  }

  // Art Deco — stepped geometric + square
  void _drawStepped(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*3, y+dy*22)..lineTo(x+dx*3, y+dy*8)..lineTo(x+dx*8, y+dy*3)..lineTo(x+dx*22, y+dy*3), _cp);
    c.drawPath(Path()..moveTo(x+dx*6, y+dy*18)..lineTo(x+dx*6, y+dy*11)..lineTo(x+dx*11, y+dy*6)..lineTo(x+dx*18, y+dy*6), _cp2);
    final cx = x+dx*13, cy = y+dy*13;
    c.drawPath(Path()..moveTo(cx, cy-2.5)..lineTo(cx+2.5, cy)..lineTo(cx, cy+2.5)..lineTo(cx-2.5, cy)..close(), _cf);
  }

  // Fantasy / Celestial — bezier swirl + dot
  void _drawSwirl(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*20)..quadraticBezierTo(x+dx*4, y+dy*4, x+dx*14, y+dy*4)..quadraticBezierTo(x+dx*10, y+dy*8, x+dx*7, y+dy*14), _cp);
    c.drawPath(Path()..moveTo(x+dx*14, y+dy*7)..quadraticBezierTo(x+dx*18, y+dy*7, x+dx*18, y+dy*11), _cp2);
    c.drawCircle(Offset(x+dx*7, y+dy*14), 2.0, _cf);
  }

  // Gothic — pointed arch + cross
  void _drawPointed(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*3, y+dy*20)..lineTo(x+dx*3, y+dy*6)..lineTo(x+dx*10, y+dy*3)..lineTo(x+dx*20, y+dy*3), _cp);
    // Pointed spike
    c.drawPath(Path()..moveTo(x+dx*6, y+dy*3)..lineTo(x+dx*8, y+dy*-1)..lineTo(x+dx*10, y+dy*3), _cp2);
    // Small cross
    final cx = x+dx*14, cy = y+dy*10;
    c.drawLine(Offset(cx, cy-3), Offset(cx, cy+3), Paint()..color = colors.light.withValues(alpha: 0.5)..strokeWidth = 1.0);
    c.drawLine(Offset(cx-3, cy), Offset(cx+3, cy), Paint()..color = colors.light.withValues(alpha: 0.5)..strokeWidth = 1.0);
  }

  // Sakura — curved petal
  void _drawPetal(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*16)..quadraticBezierTo(x+dx*4, y+dy*4, x+dx*16, y+dy*4), _cp);
    // Two petal curves
    c.drawPath(Path()..moveTo(x+dx*8, y+dy*8)..quadraticBezierTo(x+dx*14, y+dy*4, x+dx*12, y+dy*10), _cp2);
    c.drawPath(Path()..moveTo(x+dx*8, y+dy*8)..quadraticBezierTo(x+dx*4, y+dy*14, x+dx*10, y+dy*12), _cp2);
    c.drawCircle(Offset(x+dx*8, y+dy*8), 1.5, _cf);
  }

  // Cyberpunk — angled clip
  void _drawClip(Canvas c, double x, double y, double dx, double dy) {
    final p = Paint()..color = colors.primary..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.square;
    c.drawPath(Path()..moveTo(x+dx*3, y+dy*16)..lineTo(x+dx*3, y+dy*3)..lineTo(x+dx*16, y+dy*3), p);
    // Neon glow line
    c.drawLine(Offset(x+dx*3, y+dy*3), Offset(x+dx*10, y+dy*10),
      Paint()..color = colors.secondary.withValues(alpha: 0.3)..strokeWidth = 0.8);
    // Dot
    c.drawCircle(Offset(x+dx*5, y+dy*5), 1.5, Paint()..color = colors.secondary..style = PaintingStyle.fill);
  }

  // Steampunk — gear outline
  void _drawGear(Canvas c, double x, double y, double dx, double dy) {
    final cx = x+dx*10, cy = y+dy*10;
    // Gear circle
    c.drawCircle(Offset(cx, cy), 6.0, Paint()..color = colors.light.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    c.drawCircle(Offset(cx, cy), 2.5, _cf);
    // 6 teeth as short spokes
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      c.drawLine(
        Offset(cx + 5 * math.cos(angle), cy + 5 * math.sin(angle)),
        Offset(cx + 8 * math.cos(angle), cy + 8 * math.sin(angle)),
        Paint()..color = colors.light..strokeWidth = 1.5..strokeCap = StrokeCap.square,
      );
    }
  }

  // Pirate — rope knot curve
  void _drawRope(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*18)..quadraticBezierTo(x+dx*4, y+dy*4, x+dx*18, y+dy*4), _cp);
    // Rope twist
    c.drawPath(Path()..moveTo(x+dx*7, y+dy*7)..quadraticBezierTo(x+dx*12, y+dy*5, x+dx*10, y+dy*10)..quadraticBezierTo(x+dx*8, y+dy*15, x+dx*12, y+dy*12), _cp2);
    c.drawCircle(Offset(x+dx*10, y+dy*10), 1.5, _cf);
  }

  // Medieval — shield bracket
  void _drawShield(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*18)..lineTo(x+dx*4, y+dy*4)..lineTo(x+dx*18, y+dy*4), _cp);
    // Shield shape inside
    c.drawPath(Path()..moveTo(x+dx*8, y+dy*7)..lineTo(x+dx*14, y+dy*7)..lineTo(x+dx*14, y+dy*12)..lineTo(x+dx*11, y+dy*15)..lineTo(x+dx*8, y+dy*12)..close(), _cp2);
    c.drawCircle(Offset(x+dx*11, y+dy*10), 1.2, _cf);
  }

  // Egyptian — lotus/papyrus
  void _drawLotus(Canvas c, double x, double y, double dx, double dy) {
    // 3-petal lotus
    c.drawPath(Path()..moveTo(x+dx*10, y+dy*4)..quadraticBezierTo(x+dx*4, y+dy*8, x+dx*10, y+dy*16), _cp);
    c.drawPath(Path()..moveTo(x+dx*10, y+dy*4)..quadraticBezierTo(x+dx*16, y+dy*8, x+dx*10, y+dy*16), _cp);
    c.drawPath(Path()..moveTo(x+dx*10, y+dy*4)..lineTo(x+dx*10, y+dy*16), _cp2);
    // Center dot
    c.drawCircle(Offset(x+dx*10, y+dy*10), 2.0, _cf);
  }

  // Victorian / Baroque — acanthus scroll
  void _drawAcanthus(Canvas c, double x, double y, double dx, double dy) {
    // Double swirl
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*20)..quadraticBezierTo(x+dx*4, y+dy*4, x+dx*14, y+dy*4)..quadraticBezierTo(x+dx*10, y+dy*8, x+dx*8, y+dy*12), _cp);
    c.drawPath(Path()..moveTo(x+dx*14, y+dy*7)..quadraticBezierTo(x+dx*20, y+dy*4, x+dx*20, y+dy*10), _cp2);
    // Leaf curl
    c.drawPath(Path()..moveTo(x+dx*6, y+dy*14)..quadraticBezierTo(x+dx*3, y+dy*16, x+dx*6, y+dy*18), _cp2);
    c.drawCircle(Offset(x+dx*8, y+dy*12), 1.8, _cf);
  }

  // Romantic — heart shape
  void _drawHeart(Canvas c, double x, double y, double dx, double dy) {
    final cx = x+dx*10, cy = y+dy*10;
    final path = Path()
      ..moveTo(cx, cy+4)
      ..cubicTo(cx-6, cy-2, cx-6, cy-6, cx, cy-3)
      ..cubicTo(cx+6, cy-6, cx+6, cy-2, cx, cy+4);
    c.drawPath(path, Paint()..color = colors.light.withValues(alpha: 0.6)..style = PaintingStyle.fill);
    c.drawPath(path, _cp2);
  }

  // Nordic — interlaced knot
  void _drawKnot(Canvas c, double x, double y, double dx, double dy) {
    // Triangle knot (Valknut-inspired)
    final cx = x+dx*10, cy = y+dy*10;
    c.drawPath(Path()..moveTo(cx, cy-6)..lineTo(cx+5, cy+3)..lineTo(cx-5, cy+3)..close(), _cp);
    c.drawPath(Path()..moveTo(cx, cy+6)..lineTo(cx+5, cy-3)..lineTo(cx-5, cy-3)..close(), _cp2);
    c.drawCircle(Offset(cx, cy), 1.5, _cf);
  }

  // Tropical — leaf/palm curve
  void _drawLeaf(Canvas c, double x, double y, double dx, double dy) {
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*16)..quadraticBezierTo(x+dx*4, y+dy*4, x+dx*16, y+dy*4), _cp);
    // Leaf vein
    c.drawPath(Path()..moveTo(x+dx*6, y+dy*14)..quadraticBezierTo(x+dx*10, y+dy*10, x+dx*14, y+dy*6), _cp2);
    // Smaller leaf
    c.drawPath(Path()..moveTo(x+dx*9, y+dy*9)..quadraticBezierTo(x+dx*14, y+dy*7, x+dx*12, y+dy*12), _cp2);
    c.drawCircle(Offset(x+dx*10, y+dy*10), 1.5, _cf);
  }

  // Blood Moon — thorny spike
  void _drawThorn(Canvas c, double x, double y, double dx, double dy) {
    final p = Paint()..color = colors.light..style = PaintingStyle.stroke..strokeWidth = 1.5;
    // Main lines with spikes
    c.drawPath(Path()..moveTo(x+dx*4, y+dy*20)..lineTo(x+dx*4, y+dy*4)..lineTo(x+dx*20, y+dy*4), p);
    // Thorn spikes along the lines
    for (var i = 8.0; i < 18; i += 4) {
      c.drawLine(Offset(x+dx*4, y+dy*i), Offset(x+dx*7, y+dy*(i-2)),
        Paint()..color = colors.light.withValues(alpha: 0.5)..strokeWidth = 1.0);
      c.drawLine(Offset(x+dx*i, y+dy*4), Offset(x+dx*(i-2), y+dy*7),
        Paint()..color = colors.light.withValues(alpha: 0.5)..strokeWidth = 1.0);
    }
  }

  // ── Center ornament dispatcher ──

  void _drawCenterOrnament(Canvas c, double cx, double cy) {
    switch (spec.centerType) {
      case _CenterType.diamond: _drawDiamond(c, cx, cy);
      case _CenterType.square: _drawSquareOrnament(c, cx, cy);
      case _CenterType.star4: _drawStar4(c, cx, cy);
      case _CenterType.cross: _drawCross(c, cx, cy);
      case _CenterType.moon: _drawMoon(c, cx, cy);
      case _CenterType.gearSmall: _drawGearSmall(c, cx, cy);
      case _CenterType.compass: _drawCompassOrnament(c, cx, cy);
      case _CenterType.ankh: _drawAnkh(c, cx, cy);
      case _CenterType.shell: _drawShellOrnament(c, cx, cy);
      case _CenterType.heartSmall: _drawHeartSmall(c, cx, cy);
      case _CenterType.rune: _drawRuneOrnament(c, cx, cy);
      case _CenterType.sun: _drawSunOrnament(c, cx, cy);
      case _CenterType.thornStar: _drawThornStarOrnament(c, cx, cy);
      case _CenterType.petalSmall: _drawPetalSmall(c, cx, cy);
      case _CenterType.none: break;
    }
    // Flanking lines
    if (spec.centerType != _CenterType.none) {
      final lp = Paint()..color = colors.light.withValues(alpha: 0.4)..strokeWidth = 0.8;
      c.drawLine(Offset(cx - 40, cy), Offset(cx - 8, cy), lp);
      c.drawLine(Offset(cx + 8, cy), Offset(cx + 40, cy), lp);
    }
  }

  void _drawDiamond(Canvas c, double cx, double cy) {
    final d = 3.5;
    c.drawPath(Path()..moveTo(cx, cy-d)..lineTo(cx+d, cy)..lineTo(cx, cy+d)..lineTo(cx-d, cy)..close(),
      Paint()..color = colors.light.withValues(alpha: 0.6)..style = PaintingStyle.fill);
  }

  void _drawSquareOrnament(Canvas c, double cx, double cy) {
    c.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 6),
      Paint()..color = colors.light.withValues(alpha: 0.6)..style = PaintingStyle.fill);
  }

  void _drawStar4(Canvas c, double cx, double cy) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final r = i.isEven ? 4.5 : 1.5;
      final angle = (i * math.pi / 4) - math.pi / 2;
      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    c.drawPath(path, Paint()..color = colors.light.withValues(alpha: 0.7)..style = PaintingStyle.fill);
    c.drawCircle(Offset(cx, cy), 6.0, Paint()..color = colors.light.withValues(alpha: 0.1)..style = PaintingStyle.fill);
  }

  void _drawCross(Canvas c, double cx, double cy) {
    final p = Paint()..color = colors.light.withValues(alpha: 0.6)..strokeWidth = 1.5;
    c.drawLine(Offset(cx, cy - 4), Offset(cx, cy + 4), p);
    c.drawLine(Offset(cx - 3, cy - 1), Offset(cx + 3, cy - 1), p);
  }

  void _drawMoon(Canvas c, double cx, double cy) {
    // Crescent moon
    c.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: 8, height: 8),
      -math.pi * 0.3, math.pi * 1.2, false,
      Paint()..color = colors.light.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Small star beside
    c.drawCircle(Offset(cx + 5, cy - 3), 1.2,
      Paint()..color = colors.light.withValues(alpha: 0.5)..style = PaintingStyle.fill);
  }

  void _drawGearSmall(Canvas c, double cx, double cy) {
    c.drawCircle(Offset(cx, cy), 4.0, Paint()..color = colors.light.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    c.drawCircle(Offset(cx, cy), 1.5, _cf);
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      c.drawLine(Offset(cx + 3.5 * math.cos(angle), cy + 3.5 * math.sin(angle)),
        Offset(cx + 5.5 * math.cos(angle), cy + 5.5 * math.sin(angle)),
        Paint()..color = colors.light..strokeWidth = 1.2..strokeCap = StrokeCap.square);
    }
  }

  void _drawCompassOrnament(Canvas c, double cx, double cy) {
    // 4-direction compass
    final p = Paint()..color = colors.light.withValues(alpha: 0.6)..strokeWidth = 1.0;
    c.drawLine(Offset(cx, cy - 5), Offset(cx, cy + 5), p);
    c.drawLine(Offset(cx - 5, cy), Offset(cx + 5, cy), p);
    c.drawCircle(Offset(cx, cy), 2.0, _cf);
    // Small diamond on top
    c.drawPath(Path()..moveTo(cx, cy-5)..lineTo(cx+1.5, cy-3)..lineTo(cx, cy-1)..lineTo(cx-1.5, cy-3)..close(),
      Paint()..color = colors.light.withValues(alpha: 0.5)..style = PaintingStyle.fill);
  }

  void _drawAnkh(Canvas c, double cx, double cy) {
    // Simplified ankh
    c.drawOval(Rect.fromCenter(center: Offset(cx, cy - 2), width: 6, height: 5),
      Paint()..color = colors.light.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    c.drawLine(Offset(cx, cy + 0.5), Offset(cx, cy + 5), Paint()..color = colors.light.withValues(alpha: 0.6)..strokeWidth = 1.2);
    c.drawLine(Offset(cx - 3, cy + 2), Offset(cx + 3, cy + 2), Paint()..color = colors.light.withValues(alpha: 0.6)..strokeWidth = 1.2);
  }

  void _drawShellOrnament(Canvas c, double cx, double cy) {
    // Fan/shell shape
    for (int i = -2; i <= 2; i++) {
      final angle = i * 0.3;
      c.drawLine(Offset(cx, cy + 3),
        Offset(cx + 6 * math.sin(angle), cy - 4 * math.cos(angle)),
        Paint()..color = colors.light.withValues(alpha: 0.3)..strokeWidth = 0.8);
    }
    c.drawArc(Rect.fromCenter(center: Offset(cx, cy - 1), width: 10, height: 8),
      math.pi, math.pi, false,
      Paint()..color = colors.light.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.0);
  }

  void _drawHeartSmall(Canvas c, double cx, double cy) {
    final path = Path()
      ..moveTo(cx, cy + 3)
      ..cubicTo(cx - 4, cy, cx - 4, cy - 4, cx, cy - 1.5)
      ..cubicTo(cx + 4, cy - 4, cx + 4, cy, cx, cy + 3);
    c.drawPath(path, Paint()..color = colors.light.withValues(alpha: 0.5)..style = PaintingStyle.fill);
  }

  void _drawRuneOrnament(Canvas c, double cx, double cy) {
    // Simple Nordic rune mark
    final p = Paint()..color = colors.light.withValues(alpha: 0.6)..strokeWidth = 1.2;
    c.drawLine(Offset(cx, cy - 5), Offset(cx, cy + 5), p);
    c.drawLine(Offset(cx - 3, cy - 2), Offset(cx, cy + 1), p);
    c.drawLine(Offset(cx + 3, cy - 2), Offset(cx, cy + 1), p);
  }

  void _drawSunOrnament(Canvas c, double cx, double cy) {
    c.drawCircle(Offset(cx, cy), 2.5, _cf);
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      c.drawLine(Offset(cx + 3.5 * math.cos(angle), cy + 3.5 * math.sin(angle)),
        Offset(cx + 5.5 * math.cos(angle), cy + 5.5 * math.sin(angle)),
        Paint()..color = colors.light.withValues(alpha: 0.5)..strokeWidth = 0.8);
    }
  }

  void _drawThornStarOrnament(Canvas c, double cx, double cy) {
    // Spiky asymmetric star
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? 5.0 : 2.0;
      final angle = (i * math.pi / 5) - math.pi / 2;
      final px = cx + r * math.cos(angle);
      final py = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    c.drawPath(path, Paint()..color = colors.light.withValues(alpha: 0.5)..style = PaintingStyle.fill);
  }

  void _drawPetalSmall(Canvas c, double cx, double cy) {
    // 5-petal cherry blossom
    for (int i = 0; i < 5; i++) {
      final angle = (i * math.pi * 2 / 5) - math.pi / 2;
      final px = cx + 4 * math.cos(angle);
      final py = cy + 4 * math.sin(angle);
      c.drawCircle(Offset(px, py), 1.8,
        Paint()..color = colors.light.withValues(alpha: 0.4)..style = PaintingStyle.fill);
    }
    c.drawCircle(Offset(cx, cy), 1.5, Paint()..color = colors.light.withValues(alpha: 0.6)..style = PaintingStyle.fill);
  }

  // ── Side decorations ──

  void _drawSideDecor(Canvas c, Size size, {required bool isLeft}) {
    final x = isLeft ? 9.0 : size.width - 9.0;
    final centerY = size.height / 2;
    final lp = Paint()..color = colors.light.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 0.6;
    final dp = Paint()..color = colors.light.withValues(alpha: 0.3)..style = PaintingStyle.fill;
    c.drawLine(Offset(x, centerY - 20), Offset(x, centerY + 20), lp);
    c.drawCircle(Offset(x, centerY - 22), 1.0, dp);
    c.drawCircle(Offset(x, centerY + 22), 1.0, dp);
    c.drawCircle(Offset(x, centerY), 1.5, dp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// Glassmorphism — special case, frosted glass
// ─────────────────────────────────────────────
class _GlassmorphismFramePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final bool isNarration;
  final String speakerSide;

  _GlassmorphismFramePainter({
    required this.backgroundColor,
    required this.borderColor,
    this.isNarration = false,
    this.speakerSide = 'center',
  });

  Path _buildFramePath(Size size) {
    final r = 16.0;

    if (isNarration) {
      return Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)));
    }

    const tailW = 24.0;
    const tailH = 14.0;
    const curveMag = 5.0;

    double tailCX;
    double curveBias;
    if (speakerSide == 'left') {
      tailCX = size.width * 0.75;
      curveBias = -curveMag;
    } else if (speakerSide == 'right') {
      tailCX = size.width * 0.25;
      curveBias = curveMag;
    } else {
      tailCX = size.width * 0.5;
      curveBias = 0;
    }
    tailCX = tailCX.clamp(r + tailW / 2 + 2, size.width - r - tailW / 2 - 2);

    final path = Path();

    // Top-left corner
    path.moveTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));

    // Top edge with tail (left to right)
    path.lineTo(tailCX - tailW / 2, 0);
    path.quadraticBezierTo(
      tailCX - tailW * 0.12 + curveBias * 0.5, -tailH * 0.55,
      tailCX + curveBias, -tailH,
    );
    path.quadraticBezierTo(
      tailCX + tailW * 0.12 + curveBias * 0.5, -tailH * 0.55,
      tailCX + tailW / 2, 0,
    );
    path.lineTo(size.width - r, 0);

    // Top-right corner
    path.arcToPoint(Offset(size.width, r), radius: Radius.circular(r));
    path.lineTo(size.width, size.height - r);
    path.arcToPoint(Offset(size.width - r, size.height), radius: Radius.circular(r));
    path.lineTo(r, size.height);
    path.arcToPoint(Offset(0, size.height - r), radius: Radius.circular(r));
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final framePath = _buildFramePath(size);
    canvas.drawPath(framePath, Paint()..color = backgroundColor);
    canvas.drawPath(framePath, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 0.8);
    // Highlight (keep as RRect, it's inside the frame)
    final r = 16.0;
    final highlightRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.4),
      topLeft: Radius.circular(r), topRight: Radius.circular(r));
    canvas.drawRRect(highlightRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.0)],
      ).createShader(rect));
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
