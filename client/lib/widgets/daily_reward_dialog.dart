import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/daily_reward_service.dart';
import '../services/currency_service.dart';

/// Показывает popup ежедневной награды, если ещё не собрана сегодня.
/// Вызывается из LibraryScreen при первой загрузке.
void showDailyRewardDialog(BuildContext context, WidgetRef ref) {
  final daily = ref.read(dailyRewardProvider.notifier);
  if (!daily.shouldShowReward) return;

  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (ctx, a1, a2, child) {
      return Transform.scale(
        scale: Curves.elasticOut.transform(a1.value),
        child: Opacity(opacity: a1.value, child: child),
      );
    },
    pageBuilder: (ctx, _, _) => _DailyRewardDialog(ref: ref),
  );
}

class _DailyRewardDialog extends StatelessWidget {
  final WidgetRef ref;
  const _DailyRewardDialog({required this.ref});

  @override
  Widget build(BuildContext context) {
    final dailyState = ref.read(dailyRewardProvider);
    final currentDay = dailyState.currentStreak % dailyRewards.length;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D1854), Color(0xFF1A1A2E)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE91E63).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              const Text(
                '🎁 Ежедневная награда',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'День ${currentDay + 1} из ${dailyRewards.length}',
                style: const TextStyle(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 20),

              // 7 дней в строку
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(dailyRewards.length, (i) {
                    final reward = dailyRewards[i];
                    final isCurrent = i == currentDay;
                    final isPast = i < currentDay;

                    return Padding(
                      padding: EdgeInsets.only(
                          right: i < dailyRewards.length - 1 ? 6 : 0),
                      child: _DayCell(
                        day: i + 1,
                        label: reward.label,
                        isCurrent: isCurrent,
                        isPast: isPast,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка собрать
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final rewards =
                        ref.read(dailyRewardProvider.notifier).claimReward();
                    final currency =
                        ref.read(currencyServiceProvider.notifier);
                    if (rewards.containsKey('diamonds')) {
                      currency.addDiamonds(rewards['diamonds']!);
                    }
                    if (rewards.containsKey('tickets')) {
                      currency.addTickets(rewards['tickets']!);
                    }
                    Navigator.of(context).pop();

                    final parts = <String>[];
                    if (rewards.containsKey('diamonds')) {
                      parts.add('+${rewards['diamonds']} 💎');
                    }
                    if (rewards.containsKey('tickets')) {
                      parts.add('+${rewards['tickets']} ⚡');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Получено: ${parts.join(' ')}'),
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor:
                        const Color(0xFFE91E63).withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'Забрать награду!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

class _DayCell extends StatelessWidget {
  final int day;
  final String label;
  final bool isCurrent;
  final bool isPast;

  const _DayCell({
    required this.day,
    required this.label,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isCurrent
                ? const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)])
                : null,
            color: isPast
                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                : isCurrent
                    ? null
                    : const Color(0xFF16213E),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFFE91E63)
                  : isPast
                      ? const Color(0xFF4CAF50)
                      : Colors.white12,
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Center(
            child: isPast
                ? const Icon(Icons.check, size: 16, color: Color(0xFF4CAF50))
                : Text(
                    label.split(' ').last,
                    style: const TextStyle(fontSize: 14),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Д$day',
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? Colors.white : Colors.white38,
          ),
        ),
      ],
    );
  }
}
