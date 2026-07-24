import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/novel_loader.dart';
import '../services/currency_service.dart';
import '../services/save_service.dart';
import '../models/novel.dart';
import '../widgets/novel_card.dart';
import '../widgets/novel_cover_image.dart';
import '../widgets/daily_reward_dialog.dart';
import 'novel_detail_screen.dart';
import '../services/locale_service.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'notification_screen.dart';

// ─── Главный экран с 4 вкладками (V1) ────────────────────────────────────────
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
          ShopScreen(),
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
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: ref.tr('home')),
            BottomNavigationBarItem(icon: const Icon(Icons.search_rounded), label: ref.tr('catalog')),
            BottomNavigationBarItem(icon: const Icon(Icons.shopping_bag_rounded), label: ref.tr('shop')),
            BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: ref.tr('profile')),
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
          ref.watch(saveServiceProvider);
          final saveService = ref.read(saveServiceProvider.notifier);
          // «Продолжить» — учитывает автосейв и ручные слоты
          final continuePlaying =
              novels.where((n) => saveService.hasAnySave(n.id)).toList();

          return CustomScrollView(
            slivers: [
              // ── Верхняя панель ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      // Колокольчик
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationScreen()),
                        ),
                        child: Stack(
                          children: [
                            const Icon(Icons.notifications_rounded, color: Color(0xFFE91E63), size: 26),
                            Positioned(
                              right: 0, top: 0,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE91E63)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Название «Amoria» с градиентом
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                        ).createShader(bounds),
                        child: const Text(
                          'Amoria',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      // Валюта
                      _CurrencyPill(icon: '💎', value: '${currency.diamonds}'),
                      const SizedBox(width: 6),
                      _CurrencyPill(icon: '⚡', value: '${currency.tickets}'),
                    ],
                  ),
                ),
              ),

              // ── Баннер-карусель ──
              if (novels.isNotEmpty)
                SliverToBoxAdapter(child: _FeaturedBanner(novels: novels)),

              // ── Продолжить чтение ──
              if (continuePlaying.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(title: ref.tr('continue_reading'), icon: Icons.bookmark_rounded),
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

              // ── Рекомендации ──
              if (novels.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(title: ref.tr('recommendations'), icon: Icons.auto_awesome_rounded),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: (novels.length > 6 ? 6 : novels.length),
                      itemBuilder: (context, index) {
                        final shuffled = List<NovelMeta>.from(novels)..shuffle();
                        final novel = shuffled[index];
                        return _NovelVerticalCard(
                          novel: novel,
                          onTap: () => _openNovel(context, novel),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // ── Тренды ──
              if (novels.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(title: ref.tr('trending'), icon: Icons.local_fire_department_rounded),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: List.generate(
                        novels.length > 5 ? 5 : novels.length,
                        (i) => _TrendingItem(
                          rank: i + 1,
                          novel: novels[i],
                          onTap: () => _openNovel(context, novels[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

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

// ─── Вкладка «Каталог» ──────────────────────────────────────────────────────
class _CatalogTab extends ConsumerStatefulWidget {
  const _CatalogTab();

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  String _searchQuery = '';
  String _selectedGenre = 'all';
  String _sortBy = 'popular';
  bool _gridView = true;

  static const _genres = [
    'all', 'romance', 'fantasy', 'drama', 'detective', 'mystic', 'comedy',
  ];
  static const _genreIcons = ['', '💕', '✨', '🎭', '🔍', '🌙', '😂'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<NovelMeta>>(
        future: ref.read(novelLoaderProvider).loadAllNovels(),
        builder: (context, snapshot) {
          final allNovels = snapshot.data ?? [];
          final filtered = _filterNovels(allNovels);

          return CustomScrollView(
            slivers: [
              // Заголовок
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(ref.tr('catalog'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              // Поиск
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search, color: Colors.white38, size: 20),
                        hintText: ref.tr('search_placeholder'),
                        hintStyle: const TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              // Жанры
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _genres.length,
                    itemBuilder: (context, i) {
                      final isActive = _selectedGenre == _genres[i];
                      final label = i == 0
                          ? ref.tr('all')
                          : '${_genreIcons[i]} ${ref.tr(_genres[i])}';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGenre = _genres[i]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFE91E63) : const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(label,
                              style: TextStyle(
                                fontSize: 13,
                                color: isActive ? Colors.white : Colors.white54,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              )),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Сортировка + переключатель вида
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Text('${ref.tr('sort_by')}:', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _sortBy,
                        dropdownColor: const Color(0xFF16213E),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        underline: const SizedBox.shrink(),
                        iconEnabledColor: Colors.white38,
                        items: [
                          DropdownMenuItem(value: 'popular', child: Text(ref.tr('popular'))),
                          DropdownMenuItem(value: 'newest', child: Text(ref.tr('newest'))),
                          DropdownMenuItem(value: 'by_rating', child: Text(ref.tr('by_rating'))),
                        ],
                        onChanged: (v) => setState(() => _sortBy = v ?? 'popular'),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _gridView = true),
                        child: Icon(Icons.grid_view_rounded,
                          size: 22, color: _gridView ? const Color(0xFFE91E63) : Colors.white24),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _gridView = false),
                        child: Icon(Icons.view_list_rounded,
                          size: 22, color: !_gridView ? const Color(0xFFE91E63) : Colors.white24),
                      ),
                    ],
                  ),
                ),
              ),
              // Контент
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFE91E63))),
                  ),
                )
              else if (filtered.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else if (_gridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => NovelCard(
                        novel: filtered[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: filtered[i])),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _NovelListCard(
                        novel: filtered[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: filtered[i])),
                        ),
                      ),
                      childCount: filtered.length,
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

  List<NovelMeta> _filterNovels(List<NovelMeta> novels) {
    var result = novels.toList();
    if (_selectedGenre != 'all') {
      result = result.where((n) =>
        n.tags.any((t) => t.toLowerCase().contains(_selectedGenre))).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((n) =>
        n.displayTitle.toLowerCase().contains(q) ||
        n.author.toLowerCase().contains(q)).toList();
    }
    return result;
  }
}

// ─── Компоненты ──────────────────────────────────────────────────────────────

class _CurrencyPill extends StatelessWidget {
  final String icon;
  final String value;
  const _CurrencyPill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

// ─── Баннер-карусель с автопрокруткой ────────────────────────────────────────
class _FeaturedBanner extends StatefulWidget {
  final List<NovelMeta> novels;
  const _FeaturedBanner({required this.novels});

  @override
  State<_FeaturedBanner> createState() => _FeaturedBannerState();
}

class _FeaturedBannerState extends State<_FeaturedBanner> {
  final _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % widget.novels.take(3).length;
      _pageController.animateToPage(next,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featured = widget.novels.take(3).toList();

    return Column(
      children: [
        SizedBox(
          height: 220,
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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NovelCoverImage(
                        novelId: novel.id,
                        coverImage: novel.coverImage,
                        coverUrl: novel.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              _bannerColor(index),
                              _bannerColor(index).withValues(alpha: 0.6),
                            ]),
                          ),
                        ),
                      ),
                      // Градиент снизу
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16, left: 16, right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Новая глава!',
                                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 6),
                            Text(novel.displayTitle,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
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
    const colors = [Color(0xFF6A1B9A), Color(0xFF1565C0), Color(0xFFC62828)];
    return colors[index % colors.length];
  }
}

// ─── Секция «Продолжить» — карточка ─────────────────────────────────────────
class _ContinueCard extends ConsumerWidget {
  final NovelMeta novel;
  final VoidCallback onTap;
  const _ContinueCard({required this.novel, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFF1E1E3A), Color(0xFF16213E)]),
          border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: NovelCoverImage(
                  novelId: novel.id,
                  coverImage: novel.coverImage,
                  coverUrl: novel.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: Center(
                    child: Text(novel.displayTitle[0],
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w200, color: Colors.white24)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(novel.displayTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(ref.tr('continue_reading'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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

// ─── Вертикальная карточка новеллы (рекомендации) ────────────────────────────
class _NovelVerticalCard extends ConsumerWidget {
  final NovelMeta novel;
  final VoidCallback onTap;
  const _NovelVerticalCard({required this.novel, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 210,
              width: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NovelCoverImage(
                      novelId: novel.id,
                      coverImage: novel.coverImage,
                      coverUrl: novel.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: const Color(0xFF2D1854),
                        child: Center(child: Text(novel.displayTitle[0],
                          style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w200, color: Colors.white24))),
                      ),
                    ),
                    if (novel.tags.isNotEmpty)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(novel.tags.first,
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(novel.displayTitle,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 2),
            Text(novel.author,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

// ─── Тренды — строка с номером ──────────────────────────────────────────────
class _TrendingItem extends StatelessWidget {
  final int rank;
  final NovelMeta novel;
  final VoidCallback onTap;
  const _TrendingItem({required this.rank, required this.novel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Text('#$rank',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 50, height: 65,
                child: NovelCoverImage(
                  novelId: novel.id,
                  coverImage: novel.coverImage,
                  coverUrl: novel.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: Container(color: const Color(0xFF2D1854)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(novel.displayTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  if (novel.tags.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(novel.tags.first,
                        style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

// ─── Карточка для списочного вида каталога ───────────────────────────────────
class _NovelListCard extends StatelessWidget {
  final NovelMeta novel;
  final VoidCallback onTap;
  const _NovelListCard({required this.novel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60, height: 80,
                child: NovelCoverImage(
                  novelId: novel.id,
                  coverImage: novel.coverImage,
                  coverUrl: novel.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: Container(color: const Color(0xFF2D1854)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(novel.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                      // v2.1 (спека 4.9): бейдж черновика (тест-режим админа)
                      if (!novel.isPublished) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('✏ Черновик',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(novel.author,
                    style: const TextStyle(fontSize: 13, color: Colors.white38)),
                  const SizedBox(height: 6),
                  if (novel.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: novel.tags.take(2).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(t, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      )).toList(),
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
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

// ─── Пустое состояние ────────────────────────────────────────────────────────
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.auto_stories, size: 80, color: Colors.white12),
            const SizedBox(height: 16),
            Text(ref.tr('no_novels'), style: const TextStyle(fontSize: 18, color: Colors.white38)),
            const SizedBox(height: 8),
            const Text('Скоро здесь появятся истории', style: TextStyle(fontSize: 14, color: Colors.white24)),
          ],
        ),
      ),
    );
  }
}
