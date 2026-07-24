import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/locale_service.dart';
import '../services/user_profile_service.dart';
import '../services/currency_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/ad_service.dart';
import '../services/remote_config_service.dart';
import '../services/settings_service.dart';
import '../services/save_service.dart';
import '../services/novel_loader.dart';
import '../services/achievement_service.dart';
import '../models/novel.dart';
import 'auth_screen.dart';
import 'shop_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final currency = ref.watch(currencyServiceProvider);

    // Calculate level from stats
    final totalXp = profile.totalNovelsCompleted * 100 +
        profile.totalChaptersRead * 20 +
        profile.totalChoicesMade * 5;
    final level = totalXp ~/ 500 + 1;
    final xpInLevel = totalXp % 500;
    const xpPerLevel = 500;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(ref.tr('profile')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ═══ Header with gradient ═══
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D1854), Color(0xFF16213E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                _AvatarWidget(
                  index: profile.avatarIndex,
                  size: 96,
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
                const SizedBox(height: 8),
                Text(
                  '🌸 Книголюб · Уровень $level',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE91E63),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpInLevel / xpPerLevel,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE91E63),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$xpInLevel / $xpPerLevel XP',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),

          // ═══ Content with padding ═══
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                // ═══ Статистика (emoji) ═══
                _SectionTitle(ref.tr('statistics')),
                _StatGrid(
                  stats: [
                    _Stat('📚', ref.tr('novels_completed'), '${profile.totalNovelsCompleted}'),
                    _Stat('📖', ref.tr('chapters_read'), '${profile.totalChaptersRead}'),
                    _Stat('💕', ref.tr('choices_made'), '${profile.totalChoicesMade}'),
                    _Stat('🏆', ref.tr('achievements'), '${profile.achievements.length}'),
                  ],
                ),
                const SizedBox(height: 24),

                // ═══ Избранное ═══
                const _SectionTitle('❤️ Избранное'),
                const _EmptyPlaceholder(
                  icon: Icons.favorite_border,
                  text: 'Пока пусто',
                ),
                const SizedBox(height: 24),

                // ═══ История чтения ═══
                const _SectionTitle('📊 История чтения'),
                const _ReadingHistorySection(),
                const SizedBox(height: 24),

                // ═══ Достижения ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(ref.tr('achievements'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: _AchievementList(),
                ),
                const SizedBox(height: 24),

                // ═══ Галерея CG ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      const Text('🖼', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Text('Галерея CG', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Spacer(),
                      Text('8/24 →', style: TextStyle(fontSize: 13, color: Color(0xFFE91E63))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: List.generate(8, (i) {
                      final locked = i >= 3;
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(12),
                          border: !locked && i == 2 ? Border.all(color: Color(0xFFE91E63), width: 1.5) : null,
                        ),
                        child: locked
                          ? Center(child: Icon(Icons.lock, color: Colors.white24, size: 20))
                          : Stack(
                              children: [
                                Center(child: Icon(Icons.image, color: Colors.white24, size: 24)),
                                if (i == 2)
                                  Positioned(top: 4, right: 4, child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: Color(0xFFE91E63), borderRadius: BorderRadius.circular(4)),
                                    child: Text('NEW', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                  )),
                              ],
                            ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // ═══ Тема ═══
                const _SectionTitle('🎨 Тема'),
                const _ThemeModeToggle(),
                const SizedBox(height: 24),

                // Настройки ⚙️
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.white38),
                  title: Text(ref.tr('settings'), style: Theme.of(context).textTheme.titleMedium),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const SizedBox(height: 24),

                // ═══ Аккаунт ═══
                _SectionTitle('Аккаунт'),
                _AccountSection(),

                const SizedBox(height: 40),
              ],
            ),
          ),
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

// --- Достижения ---

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

class _Stat {
  final String emoji;
  final String label;
  final String value;
  const _Stat(this.emoji, this.label, this.value);
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
      childAspectRatio: 2.0,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(s.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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

class _AchievementList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementService = ref.read(achievementServiceProvider);
    final profile = ref.watch(userProfileProvider);
    final achievements = achievementService.allAchievements;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final a = achievements[index];
        final completed = profile.achievements.contains(a.id);
        final progress = achievementService.getProgress(a.id);
        final isHidden = a.hidden && !completed;
        final label = isHidden ? '???' : ref.tr(a.titleKey);
        final progressStr = isHidden ? '' : '${progress.current}/${progress.required}';
        return _AchievementBadge(
          achievement: a,
          completed: completed,
          label: label,
          progress: progressStr,
        );
      },
    );
  }
}

Color _rarityColor(AchievementRarity rarity) {
  switch (rarity) {
    case AchievementRarity.common:
      return Colors.blueGrey;
    case AchievementRarity.rare:
      return const Color(0xFF9C27B0);
    case AchievementRarity.epic:
      return const Color(0xFFFFD700);
    case AchievementRarity.legendary:
      return const Color(0xFFFF6B00);
  }
}

class _AchievementBadge extends StatelessWidget {
  final AchievementDef achievement;
  final bool completed;
  final String label;
  final String progress;
  const _AchievementBadge({required this.achievement, required this.completed, required this.label, required this.progress});

  @override
  Widget build(BuildContext context) {
    final rColor = _rarityColor(achievement.rarity);
    final isHidden = achievement.hidden && !completed;
    final displayIcon = isHidden ? Icons.lock : achievement.icon;
    final isLegendary = achievement.rarity == AchievementRarity.legendary;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56, height: 56,
                child: CircularProgressIndicator(
                  value: _parseProgress(progress),
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(completed ? Colors.green : rColor),
                  strokeWidth: 3,
                ),
              ),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? Colors.green.withValues(alpha: 0.2) : const Color(0xFF16213E),
                  boxShadow: [
                    BoxShadow(
                      color: rColor.withValues(alpha: isLegendary ? 0.5 : 0.3),
                      blurRadius: isLegendary ? 12 : 8,
                    ),
                  ],
                ),
                child: Center(child: Icon(displayIcon, color: completed ? Colors.green : Colors.white54, size: 22)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          if (progress.isNotEmpty)
            Text(progress, style: const TextStyle(fontSize: 10, color: Colors.white24)),
        ],
      ),
    );
  }

  double _parseProgress(String progress) {
    if (progress.isEmpty) return 0;
    final parts = progress.split('/');
    if (parts.length == 2) {
      final current = int.tryParse(parts[0]) ?? 0;
      final total = int.tryParse(parts[1]) ?? 1;
      return current / total;
    }
    return 0;
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

    // Реклама выключена (release без AdUnit ID в конфиге) — прячем кнопку
    if (!adService.adsEnabled) return const SizedBox.shrink();

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
            ref
                .read(currencyServiceProvider.notifier)
                .addDiamonds(amount, reason: 'ad_reward');
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

// ═══ Reading history section ═══

class _ReadingHistorySection extends ConsumerStatefulWidget {
  const _ReadingHistorySection();

  @override
  ConsumerState<_ReadingHistorySection> createState() =>
      _ReadingHistorySectionState();
}

class _ReadingHistorySectionState extends ConsumerState<_ReadingHistorySection> {
  late final Future<List<NovelMeta>> _novelsFuture;

  @override
  void initState() {
    super.initState();
    _novelsFuture = ref.read(novelLoaderProvider).loadAllNovels();
  }

  @override
  Widget build(BuildContext context) {
    final saveService = ref.read(saveServiceProvider.notifier);
    final savedIds = saveService.getSavedNovelIds();

    if (savedIds.isEmpty) {
      return const _EmptyPlaceholder(
        icon: Icons.history,
        text: 'Начните читать новеллы!',
      );
    }

    return FutureBuilder<List<NovelMeta>>(
      future: _novelsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE91E63),
                strokeWidth: 2,
              ),
            ),
          );
        }

        final novels = snapshot.data!;
        final startedNovels =
            novels.where((n) => savedIds.contains(n.id)).toList();

        if (startedNovels.isEmpty) {
          return const _EmptyPlaceholder(
            icon: Icons.history,
            text: 'Начните читать новеллы!',
          );
        }

        return Column(
          children: startedNovels.map((novel) {
            final gameState = saveService.loadGame(novel.id);
            double progress = 0.0;
            if (novel.chaptersCount > 0) {
              progress =
                  (gameState?.history.length ?? 0) / (novel.chaptersCount * 5);
              if (progress > 1.0) progress = 1.0;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 64,
                      color: const Color(0xFF2D1854),
                      child: const Center(
                        child: Text('📖', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          novel.displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white12,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE91E63),
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ═══ Theme mode toggle ═══

class _ThemeModeToggle extends ConsumerWidget {
  const _ThemeModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(settingsServiceProvider).themeMode;

    return Row(
      children: [
        Expanded(
          child: _ThemeCard(
            emoji: '🌙',
            label: 'Тёмная',
            selected: currentMode == 2,
            onTap: () =>
                ref.read(settingsServiceProvider.notifier).setThemeMode(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ThemeCard(
            emoji: '☀️',
            label: 'Светлая',
            selected: currentMode == 1,
            onTap: () =>
                ref.read(settingsServiceProvider.notifier).setThemeMode(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ThemeCard(
            emoji: '📱',
            label: 'Системная',
            selected: currentMode == 0,
            onTap: () =>
                ref.read(settingsServiceProvider.notifier).setThemeMode(0),
          ),
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFE91E63) : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? const Color(0xFFE91E63) : Colors.white54,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ Account section ═══

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
