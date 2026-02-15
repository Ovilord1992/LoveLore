import 'package:flutter/material.dart';

/// Шкала отношений с персонажем
class RelationshipBar extends StatelessWidget {
  final String characterName;
  final String variableKey;
  final num value;
  final num maxValue;
  final Color color;

  const RelationshipBar({
    super.key,
    required this.characterName,
    required this.variableKey,
    required this.value,
    this.maxValue = 20,
    this.color = const Color(0xFFE91E63),
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / maxValue).clamp(0.0, 1.0).toDouble();

    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Иконка / буква
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                characterName[0],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Имя и шкала
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  characterName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, _) {
                      return LinearProgressIndicator(
                        value: val,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(color),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Числовое значение
          Text(
            '${value.toInt()}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Панель отношений — показывает все отношения сразу
class RelationshipPanel extends StatefulWidget {
  final Map<String, RelationshipInfo> relationships;

  const RelationshipPanel({super.key, required this.relationships});

  @override
  State<RelationshipPanel> createState() => _RelationshipPanelState();
}

class RelationshipInfo {
  final String characterName;
  final num value;
  final Color color;

  const RelationshipInfo({
    required this.characterName,
    required this.value,
    required this.color,
  });
}

class _RelationshipPanelState extends State<RelationshipPanel>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кнопка сворачивания/разворачивания
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFE91E63), size: 16),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.expand_more,
                      color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),

          // Содержимое
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: widget.relationships.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RelationshipBar(
                      characterName: e.value.characterName,
                      variableKey: e.key,
                      value: e.value.value,
                      color: e.value.color,
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
