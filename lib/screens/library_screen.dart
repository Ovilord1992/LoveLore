import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/novel_loader.dart';
import '../models/novel.dart';
import '../widgets/novel_card.dart';
import 'novel_detail_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Заголовок
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amoria',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..shader = const LinearGradient(
                                colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                              ).createShader(
                                  const Rect.fromLTWH(0, 0, 150, 40)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Твои истории',
                          style: TextStyle(fontSize: 16, color: Colors.white54),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline,
                              color: Colors.white38),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings,
                              color: Colors.white38),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Список новелл
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: _NovelList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelList extends ConsumerWidget {
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
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.auto_stories,
                        size: 80, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      'Пока нет новелл',
                      style: TextStyle(fontSize: 18, color: Colors.white54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Добавьте новеллы в assets/novels/',
                      style: TextStyle(fontSize: 14, color: Colors.white30),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => NovelCard(
              novel: novels[index],
              onTap: () => _openNovel(context, novels[index]),
            ),
            childCount: novels.length,
          ),
        );
      },
    );
  }

  void _openNovel(BuildContext context, NovelMeta novel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
    );
  }
}
