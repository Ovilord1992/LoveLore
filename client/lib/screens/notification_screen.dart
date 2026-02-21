import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/locale_service.dart';
import '../app/theme.dart';

class _NotificationItem {
  final String emoji;
  final Color circleColor;
  final String title;
  final String subtitle;
  final String time;
  bool isUnread;

  _NotificationItem({
    required this.emoji,
    required this.circleColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
  });
}

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  late final List<_NotificationItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = [
      _NotificationItem(
        emoji: '📖',
        circleColor: AppTheme.primary,
        title: 'Новая глава: Тени Петербурга',
        subtitle: 'Глава 5 «Маскарад» теперь доступна!',
        time: '2 часа назад',
        isUnread: true,
      ),
      _NotificationItem(
        emoji: '🎁',
        circleColor: AppTheme.success,
        title: 'Ежедневная награда',
        subtitle: 'Заберите 5💎 за 5-й день подряд!',
        time: '5 часов назад',
        isUnread: true,
      ),
      _NotificationItem(
        emoji: '🏆',
        circleColor: Colors.amber,
        title: 'Достижение разблокировано!',
        subtitle: 'Вы получили бейдж «Книголюб»',
        time: 'Вчера',
        isUnread: false,
      ),
      _NotificationItem(
        emoji: '🛍',
        circleColor: Colors.purple,
        title: 'Спецпредложение',
        subtitle: 'Стартовый набор 100💎 за \$0.99 — осталось 12 часов',
        time: 'Вчера',
        isUnread: false,
      ),
    ];
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isUnread = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('🔔 ${ref.tr('notifications')}',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Прочитать все',
                style: TextStyle(color: AppTheme.primary, fontSize: 13)),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildCard(_notifications[i]),
            ),
    );
  }

  Widget _buildCard(_NotificationItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: item.isUnread
            ? const Border(
                left: BorderSide(color: AppTheme.primary, width: 3))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.circleColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(item.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(item.subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 3),
                Text(item.time,
                    style:
                        const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          if (item.isUnread)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(ref.tr('no_notifications'),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(ref.tr('notifications_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}
