import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Полноэкранный пропускаемый экран «Ранее…» (recap главы, спека 1.8).
/// Показывается один раз за прохождение перед первой сценой главы.
class RecapOverlay extends StatelessWidget {
  final String chapterTitle;
  final String recapText;
  final VoidCallback onDismiss;

  const RecapOverlay({
    super.key,
    required this.chapterTitle,
    required this.recapText,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_edu, color: AppTheme.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Ранее…',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  chapterTitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      recapText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Продолжить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
