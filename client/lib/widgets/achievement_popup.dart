import 'package:flutter/material.dart';
import '../services/achievement_service.dart';

/// Всплывающее уведомление о новом достижении
class AchievementPopup {
  static void show(BuildContext context, AchievementDef achievement, {String? header}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _AchievementOverlay(
        achievement: achievement,
        header: header ?? 'Achievement unlocked!',
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  /// Показать несколько достижений подряд
  static void showAll(BuildContext context, List<AchievementDef> achievements, {String? header}) {
    for (var i = 0; i < achievements.length; i++) {
      Future.delayed(Duration(milliseconds: i * 2500), () {
        if (context.mounted) {
          show(context, achievements[i], header: header);
        }
      });
    }
  }
}

class _AchievementOverlay extends StatefulWidget {
  final AchievementDef achievement;
  final String header;
  final VoidCallback onDismiss;

  const _AchievementOverlay({
    required this.achievement,
    required this.header,
    required this.onDismiss,
  });

  @override
  State<_AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<_AchievementOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Автоматически скрыть через 2 секунды
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D1854), Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFE91E63).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.emoji_events,
                          color: Color(0xFFE91E63), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.header,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFE91E63),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.achievement.title,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Награда
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '+${widget.achievement.diamondReward}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
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
