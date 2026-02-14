import 'package:flutter/material.dart';
import '../models/scene.dart';

/// Кнопки выбора
class ChoiceButtons extends StatelessWidget {
  final List<Choice> choices;
  final void Function(Choice choice) onChoiceSelected;

  const ChoiceButtons({
    super.key,
    required this.choices,
    required this.onChoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
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
        children: choices.map((choice) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChoiceButton(
              choice: choice,
              onTap: () => onChoiceSelected(choice),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChoiceButton extends StatefulWidget {
  final Choice choice;
  final VoidCallback onTap;

  const _ChoiceButton({required this.choice, required this.onTap});

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
            gradient: LinearGradient(
              colors: isPremium
                  ? [const Color(0xFF9C27B0), const Color(0xFFE91E63)]
                  : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPremium
                  ? const Color(0xFFE91E63)
                  : Colors.white24,
              width: 1,
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
                  widget.choice.text,
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
