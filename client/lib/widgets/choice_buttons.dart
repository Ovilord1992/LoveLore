import 'package:flutter/material.dart';
import '../models/scene.dart';

/// Цвета для темизированных кнопок выбора
class _ChoiceThemeColors {
  final Color borderColor;
  final Color bgColor;
  final Color premiumBorderColor;
  final List<Color> premiumGradient;

  const _ChoiceThemeColors({
    required this.borderColor,
    required this.bgColor,
    required this.premiumBorderColor,
    required this.premiumGradient,
  });

  static _ChoiceThemeColors forTheme(DialogueFrameTheme theme, {Color? customFrame, Color? customBg}) {
    final base = _baseForTheme(theme);
    if (customFrame == null && customBg == null) return base;
    return _ChoiceThemeColors(
      borderColor: customFrame?.withValues(alpha: 0.5) ?? base.borderColor,
      bgColor: customBg?.withValues(alpha: 0.85) ?? base.bgColor,
      premiumBorderColor: customFrame ?? base.premiumBorderColor,
      premiumGradient: customFrame != null
          ? [customFrame.withValues(alpha: 0.4), customFrame.withValues(alpha: 0.2)]
          : base.premiumGradient,
    );
  }

  static _ChoiceThemeColors _baseForTheme(DialogueFrameTheme theme) {
    switch (theme) {
      case DialogueFrameTheme.ornate:
        return const _ChoiceThemeColors(borderColor: Color(0x80B8860B), bgColor: Color(0xDD1A1410),
          premiumBorderColor: Color(0xFFDAA520), premiumGradient: [Color(0x66B8860B), Color(0x33DAA520)]);
      case DialogueFrameTheme.artDeco:
        return const _ChoiceThemeColors(borderColor: Color(0x808B7355), bgColor: Color(0xDD0F1B2D),
          premiumBorderColor: Color(0xFFC4A265), premiumGradient: [Color(0x668B7355), Color(0x33C4A265)]);
      case DialogueFrameTheme.modern:
        return const _ChoiceThemeColors(borderColor: Color(0x806C63FF), bgColor: Color(0xDD1A1A2E),
          premiumBorderColor: Color(0xFF8B83FF), premiumGradient: [Color(0x666C63FF), Color(0x338B83FF)]);
      case DialogueFrameTheme.glassmorphism:
        return const _ChoiceThemeColors(borderColor: Color(0x40FFFFFF), bgColor: Color(0x30FFFFFF),
          premiumBorderColor: Color(0x80FFFFFF), premiumGradient: [Color(0x40FFFFFF), Color(0x20FFFFFF)]);
      case DialogueFrameTheme.fantasy:
        return const _ChoiceThemeColors(borderColor: Color(0x807B2D8E), bgColor: Color(0xDD140A1F),
          premiumBorderColor: Color(0xFFA855F7), premiumGradient: [Color(0x667B2D8E), Color(0x33A855F7)]);
      case DialogueFrameTheme.victorian:
        return const _ChoiceThemeColors(borderColor: Color(0x808B6914), bgColor: Color(0xDD1E150E),
          premiumBorderColor: Color(0xFFC9A84C), premiumGradient: [Color(0x668B6914), Color(0x33C9A84C)]);
      case DialogueFrameTheme.gothic:
        return const _ChoiceThemeColors(borderColor: Color(0x808B1A1A), bgColor: Color(0xDD0D0808),
          premiumBorderColor: Color(0xFFC62828), premiumGradient: [Color(0x668B1A1A), Color(0x33C62828)]);
      case DialogueFrameTheme.noir:
        return const _ChoiceThemeColors(borderColor: Color(0x80707070), bgColor: Color(0xDD0F0F0F),
          premiumBorderColor: Color(0xFFA0A0A0), premiumGradient: [Color(0x66707070), Color(0x33A0A0A0)]);
      case DialogueFrameTheme.sakura:
        return const _ChoiceThemeColors(borderColor: Color(0x80D4618C), bgColor: Color(0xDD1A0E14),
          premiumBorderColor: Color(0xFFF06292), premiumGradient: [Color(0x66D4618C), Color(0x33F06292)]);
      case DialogueFrameTheme.celestial:
        return const _ChoiceThemeColors(borderColor: Color(0x805C6BC0), bgColor: Color(0xDD0A0E1A),
          premiumBorderColor: Color(0xFF7986CB), premiumGradient: [Color(0x665C6BC0), Color(0x337986CB)]);
      case DialogueFrameTheme.cyberpunk:
        return const _ChoiceThemeColors(borderColor: Color(0x8000BCD4), bgColor: Color(0xDD0A0A14),
          premiumBorderColor: Color(0xFFE91E63), premiumGradient: [Color(0x6600BCD4), Color(0x33E91E63)]);
      case DialogueFrameTheme.steampunk:
        return const _ChoiceThemeColors(borderColor: Color(0x80B87333), bgColor: Color(0xDD1A1008),
          premiumBorderColor: Color(0xFFCD853F), premiumGradient: [Color(0x66B87333), Color(0x33CD853F)]);
      case DialogueFrameTheme.pirate:
        return const _ChoiceThemeColors(borderColor: Color(0x808B6914), bgColor: Color(0xDD14100A),
          premiumBorderColor: Color(0xFFA0785A), premiumGradient: [Color(0x668B6914), Color(0x33A0785A)]);
      case DialogueFrameTheme.medieval:
        return const _ChoiceThemeColors(borderColor: Color(0x806B5B3C), bgColor: Color(0xDD12100A),
          premiumBorderColor: Color(0xFF9C8B6C), premiumGradient: [Color(0x666B5B3C), Color(0x339C8B6C)]);
      case DialogueFrameTheme.egyptian:
        return const _ChoiceThemeColors(borderColor: Color(0x80C5A028), bgColor: Color(0xDD0D0A05),
          premiumBorderColor: Color(0xFFFFD54F), premiumGradient: [Color(0x66C5A028), Color(0x33FFD54F)]);
      case DialogueFrameTheme.baroque:
        return const _ChoiceThemeColors(borderColor: Color(0x80B8860B), bgColor: Color(0xDD18120A),
          premiumBorderColor: Color(0xFFD4AF37), premiumGradient: [Color(0x66B8860B), Color(0x33D4AF37)]);
      case DialogueFrameTheme.romantic:
        return const _ChoiceThemeColors(borderColor: Color(0x80D81B60), bgColor: Color(0xDD1A0A10),
          premiumBorderColor: Color(0xFFEC407A), premiumGradient: [Color(0x66D81B60), Color(0x33EC407A)]);
      case DialogueFrameTheme.nordic:
        return const _ChoiceThemeColors(borderColor: Color(0x804FC3F7), bgColor: Color(0xDD0A0E14),
          premiumBorderColor: Color(0xFF81D4FA), premiumGradient: [Color(0x664FC3F7), Color(0x3381D4FA)]);
      case DialogueFrameTheme.tropical:
        return const _ChoiceThemeColors(borderColor: Color(0x8000897B), bgColor: Color(0xDD0A1410),
          premiumBorderColor: Color(0xFF26A69A), premiumGradient: [Color(0x6600897B), Color(0x3326A69A)]);
      case DialogueFrameTheme.bloodMoon:
        return const _ChoiceThemeColors(borderColor: Color(0x80B71C1C), bgColor: Color(0xDD0D0505),
          premiumBorderColor: Color(0xFFD32F2F), premiumGradient: [Color(0x66B71C1C), Color(0x33D32F2F)]);
    }
  }
}

/// Кнопки выбора с опциональным таймером и темизацией под стиль рамки
class ChoiceButtons extends StatefulWidget {
  final List<Choice> choices;
  final void Function(Choice choice) onChoiceSelected;
  final int? timeLimit; // секунды
  final int? defaultChoiceIndex;
  final String Function(String)? translateText;
  final DialogueFrameTheme frameTheme;
  final Color? customFrameColor;
  final Color? customBgColor;

  const ChoiceButtons({
    super.key,
    required this.choices,
    required this.onChoiceSelected,
    this.timeLimit,
    this.defaultChoiceIndex,
    this.translateText,
    this.frameTheme = DialogueFrameTheme.ornate,
    this.customFrameColor,
    this.customBgColor,
  });

  @override
  State<ChoiceButtons> createState() => _ChoiceButtonsState();
}

class _ChoiceButtonsState extends State<ChoiceButtons>
    with SingleTickerProviderStateMixin {
  AnimationController? _timerController;

  @override
  void initState() {
    super.initState();
    if (widget.timeLimit != null && widget.timeLimit! > 0) {
      _timerController = AnimationController(
        duration: Duration(seconds: widget.timeLimit!),
        vsync: this,
      );
      _timerController!.forward().then((_) {
        if (mounted) {
          final idx = (widget.defaultChoiceIndex ?? 0).clamp(0, widget.choices.length - 1);
          widget.onChoiceSelected(widget.choices[idx]);
        }
      });
    }
  }

  @override
  void dispose() {
    _timerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = _ChoiceThemeColors.forTheme(
      widget.frameTheme,
      customFrame: widget.customFrameColor,
      customBg: widget.customBgColor,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Таймер
          if (_timerController != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AnimatedBuilder(
                animation: _timerController!,
                builder: (context, _) {
                  final remaining = ((1 - _timerController!.value) * widget.timeLimit!).ceil();
                  return SizedBox(
                    width: 48, height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1 - _timerController!.value,
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(
                            _timerController!.value > 0.7
                                ? Colors.red
                                : themeColors.premiumBorderColor,
                          ),
                          backgroundColor: Colors.white12,
                        ),
                        Text(
                          '$remaining',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ...widget.choices.map((choice) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChoiceButton(
                choice: choice,
                translateText: widget.translateText,
                themeColors: themeColors,
                frameTheme: widget.frameTheme,
                onTap: () {
                  _timerController?.stop();
                  widget.onChoiceSelected(choice);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatefulWidget {
  final Choice choice;
  final VoidCallback onTap;
  final String Function(String)? translateText;
  final _ChoiceThemeColors themeColors;
  final DialogueFrameTheme frameTheme;

  const _ChoiceButton({
    required this.choice,
    required this.onTap,
    this.translateText,
    required this.themeColors,
    required this.frameTheme,
  });

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = widget.choice.premium;
    final tc = widget.themeColors;

    // Border radius depends on theme
    final radius = switch (widget.frameTheme) {
      DialogueFrameTheme.artDeco || DialogueFrameTheme.noir || DialogueFrameTheme.cyberpunk => BorderRadius.circular(2),
      DialogueFrameTheme.glassmorphism => BorderRadius.circular(16),
      DialogueFrameTheme.modern || DialogueFrameTheme.sakura || DialogueFrameTheme.tropical => BorderRadius.circular(8),
      DialogueFrameTheme.romantic => BorderRadius.circular(14),
      DialogueFrameTheme.steampunk || DialogueFrameTheme.pirate || DialogueFrameTheme.medieval => BorderRadius.circular(4),
      _ => BorderRadius.circular(12),
    };

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: isPremium
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: tc.premiumGradient,
                  )
                : null,
            color: isPremium ? null : tc.bgColor,
            borderRadius: radius,
            border: Border.all(
              color: isPremium ? tc.premiumBorderColor : tc.borderColor,
              width: isPremium ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (isPremium) ...[
                const Icon(Icons.diamond, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${widget.choice.cost}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  widget.translateText != null
                      ? widget.translateText!(widget.choice.text)
                      : widget.choice.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
