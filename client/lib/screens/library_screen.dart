import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/novel_loader.dart';
import '../services/currency_service.dart';
import '../services/save_service.dart';
import '../services/iap_service.dart';
import '../models/novel.dart';
import '../widgets/novel_card.dart';
import '../widgets/novel_cover_image.dart';
import '../widgets/daily_reward_dialog.dart';
import 'novel_detail_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _currentTab = 0;
  bool _dailyChecked = false;

  @override
  Widget build(BuildContext context) {
    // Показываем daily reward popup при первом открытии
    if (!_dailyChecked) {
      _dailyChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDailyRewardDialog(context, ref);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _HomeTab(),
          _CatalogTab(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          backgroundColor: const Color(0xFF0F0F1E),
          selectedItemColor: const Color(0xFFE91E63),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Главная'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_stories_rounded), label: 'Каталог'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Профиль'),
          ],
        ),
      ),
    );
  }
}

// ─── Вкладка «Главная» ──────────────────────────────────────────────────────
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyServiceProvider);

    return SafeArea(
      child: FutureBuilder<List<NovelMeta>>(
        future: ref.read(novelLoaderProvider).loadAllNovels(),
        builder: (context, snapshot) {
          final novels = snapshot.data ?? [];
          ref.watch(saveServiceProvider); // подписка на изменения сохранений
          final saveService = ref.read(saveServiceProvider.notifier);
          final continuePlaying = novels.where((n) => saveService.hasSave(n.id)).toList();

          return CustomScrollView(
            slivers: [
              // ── Верхняя панель: валюта + настройки ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      // Валюта с кнопками "+"
                      _CurrencyBadgeTappable(
                        icon: '💎',
                        value: currency.diamonds,
                        onPlusTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ShopScreen()),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _TicketBadgeWithTimer(
                        currency: currency,
                        onPlusTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ShopScreen()),
                        ),
                        onCheckRefill: () => ref.read(currencyServiceProvider.notifier).checkRefill(),
                      ),
                      // Настройки
                      IconButton(
                        icon: const Icon(Icons.settings_rounded, color: Colors.white30, size: 22),
                        padding: const EdgeInsets.only(left: 4),
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Баннер-карусель ──
              if (novels.isNotEmpty)
                SliverToBoxAdapter(
                  child: _FeaturedBanner(novels: novels),
                ),

              // ── Промо-баннер (стартовый набор / спецпредложение) ──
              SliverToBoxAdapter(
                child: _PromoBanner(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  ),
                ),
              ),

              // ── Продолжить чтение ──
              if (continuePlaying.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Продолжить чтение', icon: Icons.bookmark_rounded),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: continuePlaying.length,
                      itemBuilder: (context, index) => _ContinueCard(
                        novel: continuePlaying[index],
                        onTap: () => _openNovel(context, continuePlaying[index]),
                      ),
                    ),
                  ),
                ),
              ],

              // ── Все истории ──
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Все истории', icon: Icons.auto_stories_rounded),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
                  ),
                )
              else if (novels.isEmpty)
                const SliverToBoxAdapter(
                  child: _EmptyState(),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: novels.length,
                      itemBuilder: (context, index) => _LargeNovelCard(
                        novel: novels[index],
                        onTap: () => _openNovel(context, novels[index]),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  void _openNovel(BuildContext context, NovelMeta novel) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: novel)),
    );
  }
}

// ─── Вкладка «Каталог» (полный список) ──────────────────────────────────────
class _CatalogTab extends ConsumerWidget {
  const _CatalogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Каталог',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _FullNovelList(),
          ),
        ],
      ),
    );
  }
}

class _FullNovelList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<NovelMeta>>(
      future: ref.read(novelLoaderProvider).loadAllNovels(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final novels = snapshot.data ?? [];
        if (novels.isEmpty) {
          return const SliverToBoxAdapter(child: _EmptyState());
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => NovelCard(
              novel: novels[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: novels[index])),
              ),
            ),
            childCount: novels.length,
          ),
        );
      },
    );
  }
}

// ─── Бейдж валюты с кнопкой "+" ──────────────────────────────────────────────
class _CurrencyBadgeTappable extends StatelessWidget {
  final String icon;
  final int value;
  final VoidCallback onPlusTap;

  const _CurrencyBadgeTappable({
    required this.icon,
    required this.value,
    required this.onPlusTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text('$value',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onPlusTap,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                ),
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Бейдж билетов с таймером и "+" ─────────────────────────────────────────
class _TicketBadgeWithTimer extends StatefulWidget {
  final CurrencyState currency;
  final VoidCallback onPlusTap;
  final VoidCallback onCheckRefill;

  const _TicketBadgeWithTimer({
    required this.currency,
    required this.onPlusTap,
    required this.onCheckRefill,
  });

  @override
  State<_TicketBadgeWithTimer> createState() => _TicketBadgeWithTimerState();
}

class _TicketBadgeWithTimerState extends State<_TicketBadgeWithTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        widget.onCheckRefill();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isFull = widget.currency.tickets >= CurrencyService.defaultMaxTickets;

    // Рассчитываем таймер
    String? timerText;
    if (!isFull) {
      final lastRefill = widget.currency.lastTicketRefill ?? DateTime.now();
      final next = lastRefill
          .add(Duration(minutes: CurrencyService.defaultTicketRefillMinutes));
      final remaining = next.difference(DateTime.now());
      if (remaining.isNegative) {
        timerText = '00:00';
      } else {
        timerText = _formatDuration(remaining);
      }
    }

    return Container(
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4, right: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '${widget.currency.tickets}/${CurrencyService.defaultMaxTickets}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
          if (timerText != null) ...[
            const SizedBox(width: 4),
            Text(
              timerText,
              style: const TextStyle(fontSize: 10, color: Color(0xFF00BCD4)),
            ),
          ],
          const SizedBox(width: 2),
          GestureDetector(
            onTap: widget.onPlusTap,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00838F), Color(0xFF00BCD4)],
                ),
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Промо-баннер спецпредложения ────────────────────────────────────────────
class _PromoBanner extends ConsumerWidget {
  final VoidCallback onTap;
  const _PromoBanner({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iap = ref.watch(iapServiceProvider);
    // Скрываем если стартовый бандл уже куплен
    if (iap.starterBundlePurchased) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Стартовый набор',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '500💎 + 5⚡ — выгода x10!',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '\$0.99',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Баннер-карусель ─────────────────────────────────────────────────────────
class _FeaturedBanner extends StatefulWidget {
  final List<NovelMeta> novels;

  const _FeaturedBanner({required this.novels});

  @override
  State<_FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<_FeaturedBanner> {
  final _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featured = widget.novels.take(3).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: featured.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final novel = featured[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: novel)),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _bannerColor(index),
                        _bannerColor(index).withValues(alpha: 0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _bannerColor(index).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Декоративные элементы
                      Positioned(
                        right: -20, top: -20,
                        child: Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      // Контент
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                novel.tags.isNotEmpty ? novel.tags.first : 'Новелла',
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              novel.title,
                              style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              novel.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Индикаторы
        if (featured.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(featured.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _currentPage == i ? const Color(0xFFE91E63) : Colors.white24,
              ),
            )),
          ),
      ],
    );
  }

  Color _bannerColor(int index) {
    const colors = [
      Color(0xFF6A1B9A), // фиолетовый
      Color(0xFF1565C0), // синий
      Color(0xFFC62828), // красный
    ];
    return colors[index % colors.length];
  }
}

// ─── Секция «Продолжить» — горизонтальная карточка ───────────────────────────
class _ContinueCard extends StatelessWidget {
  final NovelMeta novel;
  final VoidCallback onTap;

  const _ContinueCard({required this.novel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E3A), Color(0xFF16213E)],
          ),
          border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Обложка
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE91E63).withValues(alpha: 0.3),
                      const Color(0xFF9C27B0).withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: NovelCoverImage(
                    novelId: novel.id,
                    coverImage: novel.coverImage,
                    coverUrl: novel.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: Center(
                        child: Text(
                          novel.title[0],
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w200, color: Colors.white24),
                        ),
                      ),
                  ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    novel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  // Кнопка продолжить
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Продолжить', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Большая карточка новеллы (горизонтальная прокрутка) ─────────────────────
class _LargeNovelCard extends StatelessWidget {
  final NovelMeta novel;
  final VoidCallback onTap;

  const _LargeNovelCard({required this.novel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Обложка
            Container(
              height: 220,
              width: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2D1854),
                    const Color(0xFFE91E63).withValues(alpha: 0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NovelCoverImage(
                        novelId: novel.id,
                        coverImage: novel.coverImage,
                        coverUrl: novel.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: Center(
                            child: Text(
                              novel.title[0],
                              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w200, color: Colors.white24),
                            ),
                          ),
                      ),
                    // Градиент снизу
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                          ),
                        ),
                      ),
                    ),
                    // Тег
                    if (novel.tags.isNotEmpty)
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            novel.tags.first,
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    // Количество глав
                    Positioned(
                      bottom: 10, left: 10,
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('${novel.totalChapters} глав', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Название
            Text(
              novel.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              novel.author,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Заголовок секции ────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFE91E63)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─── Пустое состояние ────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.auto_stories, size: 80, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('Пока нет новелл', style: TextStyle(fontSize: 18, color: Colors.white38)),
            const SizedBox(height: 8),
            Text('Скоро здесь появятся истории', style: TextStyle(fontSize: 14, color: Colors.white24)),
          ],
        ),
      ),
    );
  }
}
