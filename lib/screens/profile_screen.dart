import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_profile_service.dart';
import '../services/currency_service.dart';
import 'gallery_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final currency = ref.watch(currencyServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Аватар и имя
          Center(
            child: Column(
              children: [
                _AvatarWidget(
                  index: profile.avatarIndex,
                  onTap: () => _showAvatarPicker(context, ref),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _editName(context, ref, profile.displayName),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 16, color: Colors.white38),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Валюта
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D1854), Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CurrencyChip(
                  icon: '💎',
                  label: 'Алмазы',
                  value: currency.diamonds,
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                _CurrencyChip(
                  icon: '⚡',
                  label: 'Билеты',
                  value: currency.tickets,
                  maxValue: CurrencyService.maxTickets,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Статистика
          _SectionTitle('Статистика'),
          _StatGrid(
            stats: [
              _Stat('Новелл начато', '${profile.totalNovelsStarted}',
                  Icons.menu_book),
              _Stat('Новелл пройдено', '${profile.totalNovelsCompleted}',
                  Icons.check_circle_outline),
              _Stat('Глав прочитано', '${profile.totalChaptersRead}',
                  Icons.auto_stories),
              _Stat('Выборов сделано', '${profile.totalChoicesMade}',
                  Icons.touch_app),
            ],
          ),
          const SizedBox(height: 24),

          // Достижения
          _SectionTitle('Достижения'),
          if (profile.achievements.isEmpty)
            const _EmptyPlaceholder(
              icon: Icons.emoji_events_outlined,
              text: 'Пока нет достижений.\nИграй, чтобы открывать новые!',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.achievements.map((a) {
                final info = _achievementInfo(a);
                return _AchievementBadge(
                  icon: info.icon,
                  label: info.label,
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          // Галерея CG
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GalleryScreen()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionTitle('Галерея'),
                const Icon(Icons.chevron_right,
                    color: Colors.white38, size: 20),
              ],
            ),
          ),
          if (profile.unlockedCGs.isEmpty)
            const _EmptyPlaceholder(
              icon: Icons.photo_library_outlined,
              text: 'Галерея пуста.\nРазблокируй CG-арты в историях!',
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: profile.unlockedCGs.length,
                itemBuilder: (_, i) {
                  final cgId = profile.unlockedCGs.elementAt(i);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 160,
                        color: const Color(0xFF16213E),
                        child: Center(
                          child: Text(
                            cgId,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выбери аватар',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(8, (i) {
                  return GestureDetector(
                    onTap: () {
                      ref.read(userProfileProvider.notifier).setAvatar(i);
                      Navigator.pop(ctx);
                    },
                    child: _AvatarWidget(index: i, size: 56),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _editName(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Имя', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: 'Введи имя',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE91E63)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(userProfileProvider.notifier).setDisplayName(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить',
                style: TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

  _AchievementData _achievementInfo(String id) {
    return _achievements[id] ??
        _AchievementData(Icons.star, id);
  }
}

// --- Данные достижений ---
class _AchievementData {
  final IconData icon;
  final String label;
  const _AchievementData(this.icon, this.label);
}

const _achievements = <String, _AchievementData>{
  'first_story': _AchievementData(Icons.auto_stories, 'Первая история'),
  'first_choice': _AchievementData(Icons.touch_app, 'Первый выбор'),
  'five_chapters': _AchievementData(Icons.menu_book, '5 глав'),
  'first_love': _AchievementData(Icons.favorite, 'Первая любовь'),
  'completionist': _AchievementData(Icons.emoji_events, 'Прохождение'),
  'collector': _AchievementData(Icons.collections, 'Коллекционер'),
  'brave_heart': _AchievementData(Icons.shield, 'Храброе сердце'),
  'mystery_solver': _AchievementData(Icons.search, 'Детектив'),
};

// --- Виджеты ---

class _AvatarWidget extends StatelessWidget {
  final int index;
  final double size;
  final VoidCallback? onTap;

  const _AvatarWidget({required this.index, this.size = 80, this.onTap});

  static const _gradients = [
    [Color(0xFFE91E63), Color(0xFF9C27B0)],
    [Color(0xFF2196F3), Color(0xFF00BCD4)],
    [Color(0xFFFF5722), Color(0xFFFF9800)],
    [Color(0xFF4CAF50), Color(0xFF8BC34A)],
    [Color(0xFF673AB7), Color(0xFF3F51B5)],
    [Color(0xFFE91E63), Color(0xFFFF5722)],
    [Color(0xFF009688), Color(0xFF4CAF50)],
    [Color(0xFF795548), Color(0xFFFF8A65)],
  ];

  static const _emojis = ['🌸', '🌊', '🔥', '🌿', '🔮', '🌹', '🐚', '🍂'];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _emojis[index % _emojis.length],
            style: TextStyle(fontSize: size * 0.4),
          ),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String icon;
  final String label;
  final int value;
  final int? maxValue;

  const _CurrencyChip({
    required this.icon,
    required this.label,
    required this.value,
    this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          maxValue != null ? '$value/$maxValue' : '$value',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE91E63),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<_Stat> stats;
  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(s.icon, color: Colors.white24, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(s.label,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
}

class _AchievementBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AchievementBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE91E63)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyPlaceholder({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white12),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
