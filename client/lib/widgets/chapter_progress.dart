import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Индикатор прогресса по главе — показывает сколько сцен пройдено
class ChapterProgressIndicator extends StatelessWidget {
  final int currentSceneIndex;
  final int totalScenes;
  final String? chapterTitle;

  const ChapterProgressIndicator({
    super.key,
    required this.currentSceneIndex,
    required this.totalScenes,
    this.chapterTitle,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        totalScenes > 0 ? (currentSceneIndex / totalScenes).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chapterTitle != null) ...[
            Text(
              chapterTitle!,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Шкала прогресса
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (_, val, _) {
                  return LinearProgressIndicator(
                    value: val,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.primary),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Текст прогресса
          Text(
            '$currentSceneIndex/$totalScenes',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
