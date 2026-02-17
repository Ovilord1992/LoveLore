import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/locale_service.dart';
import '../services/user_profile_service.dart';
import '../services/currency_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/ad_service.dart';
import '../services/remote_config_service.dart';
import 'gallery_screen.dart';
import 'auth_screen.dart';
import 'shop_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final currency = ref.watch(currencyServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(ref.tr('profile')),
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
                  label: ref.tr('diamonds'),
                  value: currency.diamonds,
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                _CurrencyChip(
                  icon: '⚡',
                  label: ref.tr('tickets'),
                  value: currency.tickets,
                  maxValue: ref.read(remoteConfigProvider).economy.maxTickets,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Реклама за алмазы
          _WatchAdButton(ref: ref),
          const SizedBox(height: 8),

          // Кнопка магазина
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
              icon: const Icon(Icons.storefront, size: 18),
              label: Text(ref.tr('shop')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE91E63),
                side: const BorderSide(color: Color(0xFFE91E63)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(ref.tr('statistics')),
          _StatGrid(
            stats: [
              _Stat(ref.tr('novels_started'), '${profile.totalNovelsStarted}',
                  Icons.menu_book),
              _Stat(ref.tr('novels_completed'), '${profile.totalNovelsCompleted}',
                  Icons.check_circle_outline),
              _Stat(ref.tr('chapters_read'), '${profile.totalChaptersRead}',
                  Icons.auto_stories),
              _Stat(ref.tr('choices_made'), '${profile.totalChoicesMade}',
                  Icons.touch_app),
            ],
          ),
          const SizedBox(height: 24),

          // Достижения
          _SectionTitle(ref.tr('achievements')),
          if (profile.achievements.isEmpty)
            _EmptyPlaceholder(
              icon: Icons.emoji_events_outlined,
              text: ref.tr('no_achievements'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.achievements.map((a) {
                final icon = _achievementIcons[a] ?? Icons.star;
                final label = ref.tr('ach_$a');
                return _AchievementBadge(
                  icon: icon,
                  label: label,
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
                _SectionTitle(ref.tr('gallery')),
                const Icon(Icons.chevron_right,
                    color: Colors.white38, size: 20),
              ],
            ),
          ),
          if (profile.unlockedCGs.isEmpty)
            _EmptyPlaceholder(
              icon: Icons.photo_library_outlined,
              text: ref.tr('gallery_empty'),
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

          const SizedBox(height: 24),

          // Аккаунт
          _SectionTitle('Аккаунт'),
          _AccountSection(),

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
              Text(ref.tr('choose_avatar'),
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
        title: Text(ref.tr('name'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLength: 20,
          decoration: InputDecoration(
            hintText: ref.tr('enter_name'),
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE91E63)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text(ref.tr('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(userProfileProvider.notifier).setDisplayName(name);
              }
              Navigator.pop(ctx);
            },
            child: Text(ref.tr('save'),
                style: const TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }

}

// --- Иконки достижений ---
const _achievementIcons = <String, IconData>{
  'first_story': Icons.auto_stories,
  'first_choice': Icons.touch_app,
  'five_chapters': Icons.menu_book,
  'first_love': Icons.favorite,
  'completionist': Icons.emoji_events,
  'collector': Icons.collections,
  'brave_heart': Icons.shield,
  'mystery_solver': Icons.search,
  'ten_choices': Icons.checklist,
  'diamond_spender': Icons.diamond,
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

class _WatchAdButton extends StatelessWidget {
  final WidgetRef ref;
  const _WatchAdButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    final adService = ref.read(adServiceProvider);
    adService.preloadAd();

    return GestureDetector(
      onTap: () async {
        if (!adService.canShowAd) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Лимит рекламы на сегодня исчерпан'),
              backgroundColor: Color(0xFF16213E),
            ),
          );
          return;
        }

        final success = await adService.showRewardedAd(
          rewardType: 'diamonds',
          onReward: (_, amount) {
            ref.read(currencyServiceProvider.notifier).addDiamonds(amount);
          },
        );

        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('+${adService.diamondReward} 💎 алмазов!'),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
          } else if (!adService.isAdReady) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Реклама загружается, попробуйте позже'),
                backgroundColor: Color(0xFF16213E),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00838F), Color(0xFF00BCD4)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '${ref.tr('watch_ad')} → +${adService.diamondReward} 💎',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${adService.adsRemainingToday}/${adService.maxAdsPerDay}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authServiceProvider);

    if (!authState.isLoggedIn) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white24, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Войдите, чтобы сохранять\nпрогресс на сервере',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Войти / Регистрация'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done, color: Color(0xFF4CAF50), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.email ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Text(
                      'Прогресс синхронизируется',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final syncService = ref.read(syncServiceProvider);
                    await syncService.pushAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Данные синхронизированы ☁️')),
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_upload, size: 16),
                  label: const Text('Синхронизировать'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF16213E),
                      title: const Text('Выйти?', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'Локальные данные останутся на устройстве.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(ref.tr('cancel'), style: const TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    ref.read(authServiceProvider.notifier).logout();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Выйти'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
