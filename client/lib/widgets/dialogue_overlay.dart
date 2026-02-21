import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/settings_service.dart';

/// Overlay-стиль диалога (как в Romance Club) — текст по центру экрана
/// поверх полупрозрачного затемнения
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
      duration: const Duration(milliseconds: 300),
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

    return GestureDetector(
      onTap: () {
        if (!_isComplete) {
          _skipToEnd();
        } else {
          widget.onTap();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.45),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Имя говорящего
                  if (!isNarration) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: (widget.speakerColor ?? AppTheme.primary)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (widget.speakerColor ?? AppTheme.primary)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        widget.speakerName!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.speakerColor ?? AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Текст
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                            height: 1.6,
                            fontStyle:
                                isNarration ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        if (_isComplete) ...[
                          const SizedBox(height: 12),
                          _PulsingTriangle(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingTriangle extends StatefulWidget {
  @override
  State<_PulsingTriangle> createState() => _PulsingTriangleState();
}

class _PulsingTriangleState extends State<_PulsingTriangle>
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
      builder: (_, __) => Opacity(
        opacity: 0.3 + 0.5 * _controller.value,
        child: Transform.translate(
          offset: Offset(0, 2 * _controller.value),
          child: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white54,
            size: 20,
          ),
        ),
      ),
    );
  }
}
