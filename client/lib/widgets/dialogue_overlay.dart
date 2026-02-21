import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/settings_service.dart';

/// Стиль диалога как в Romance Club — текст внизу экрана,
/// имя в плашке над текстовым боксом, персонажи полностью видны
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
            // Верхняя прозрачная зона — пропускает нажатия
            const Spacer(),

            // Текстовый блок внизу
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Плашка с именем над боксом
                  if (!isNarration)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        widget.speakerName!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  if (isNarration)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '· · ·',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white38,
                          letterSpacing: 3,
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),

                  // Основной текстовый бокс
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: EdgeInsets.fromLTRB(
                        20, 18, 20, 14 + bottomPadding.clamp(0, 16)),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                        bottom: Radius.circular(4),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: isNarration
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayedText,
                          textAlign:
                              isNarration ? TextAlign.center : TextAlign.left,
                          style: TextStyle(
                            fontSize: 17,
                            color: isNarration
                                ? Colors.white70
                                : Colors.white.withValues(alpha: 0.92),
                            height: 1.55,
                            fontStyle: isNarration
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        if (_isComplete) ...[
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: _PulsingArrow(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
