import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
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
    pageBuilder: (ctx, _, _) => const _DailyRewardDialog(),
  );
}

class _DailyRewardDialog extends ConsumerStatefulWidget {
  const _DailyRewardDialog();

  @override
  ConsumerState<_DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends ConsumerState<_DailyRewardDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Единый источник каталога и дня — сервис, иначе показанная награда
    // расходится с начисляемой.
    final daily = ref.read(dailyRewardProvider.notifier);
    final rewards = daily.rewards;
    final currentDay = (daily.todayDayNumber - 1) % rewards.length;
    final todayReward = rewards[currentDay];

    final rewardText = todayReward.diamonds > 0
        ? '+${todayReward.diamonds} 💎'
        : '+${todayReward.tickets} ⚡';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sparkle decoration
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.gold, size: 20),
                  SizedBox(width: 8),
                  Icon(Icons.auto_awesome, color: AppTheme.primary, size: 28),
                  SizedBox(width: 8),
                  Icon(Icons.auto_awesome, color: AppTheme.gold, size: 20),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              const Text(
                '🎁 Ежедневная награда',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'День ${currentDay + 1} из ${rewards.length}',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),

              // 7-day calendar row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(rewards.length, (i) {
                    final reward = rewards[i];
                    final isCurrent = i == currentDay;
                    final isPast = i < currentDay;
                    final shortLabel = reward.diamonds > 0
                        ? '${reward.diamonds}💎'
                        : '${reward.tickets}⚡';

                    return Padding(
                      padding: EdgeInsets.only(
                        right: i < rewards.length - 1 ? 6 : 0,
                      ),
                      child: _DayCell(
                        day: i + 1,
                        shortLabel: shortLabel,
                        isCurrent: isCurrent,
                        isPast: isPast,
                        pulse: _pulse,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Large reward text with pink gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                ).createShader(bounds),
                child: Text(
                  '✨ $rewardText',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Claim button — pink gradient, full width, 20px radius
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final rewards = ref
                          .read(dailyRewardProvider.notifier)
                          .claimReward();
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
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Забрать награду! 🎉',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Footer hint
              Text(
                'Заходи завтра за следующей наградой!',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
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
  final String shortLabel;
  final bool isCurrent;
  final bool isPast;
  final Animation<double> pulse;

  const _DayCell({
    required this.day,
    required this.shortLabel,
    required this.isCurrent,
    required this.isPast,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle (48px)
        if (isCurrent)
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary
                          .withValues(alpha: 0.3 + pulse.value * 0.4),
                      blurRadius: 8 + pulse.value * 8,
                      spreadRadius: pulse.value * 3,
                    ),
                  ],
                ),
                // Inner circle for border effect
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF16213E),
                  ),
                  child: Center(
                    child: Text(
                      shortLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          )
        else
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPast
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: Border.all(
                color: isPast ? AppTheme.success : Colors.white24,
                width: isPast ? 2 : 1,
              ),
            ),
            child: Center(
              child: isPast
                  ? const Text('✅', style: TextStyle(fontSize: 18))
                  : const Text(
                      '?',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        const SizedBox(height: 4),
        // Label below circle
        if (isPast)
          Text(
            shortLabel,
            style: const TextStyle(fontSize: 9, color: Colors.white38),
          )
        else if (isCurrent)
          const Text(
            'Сегодня!',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          )
        else
          Text(
            'Д$day',
            style: const TextStyle(fontSize: 9, color: Colors.white24),
          ),
      ],
    );
  }
}

