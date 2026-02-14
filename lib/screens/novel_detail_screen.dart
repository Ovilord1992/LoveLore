import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novel.dart';
import '../services/save_service.dart';
import 'game_screen.dart';

class NovelDetailScreen extends ConsumerWidget {
  final NovelMeta novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveService = ref.read(saveServiceProvider);
    final hasSave = saveService.hasSave(novel.id);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          // Обложка
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Обложка или плейсхолдер
                  novel.coverImage != null
                      ? Image.asset(novel.coverImage!, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2D1854),
                                Color(0xFFE91E63),
                                Color(0xFF9C27B0),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              novel.title[0],
                              style: const TextStyle(
                                fontSize: 80,
                                fontWeight: FontWeight.w200,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                  // Градиентное затемнение снизу
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF1A1A2E)],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Контент
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название
                  Text(
                    novel.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Автор
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: Color(0xFFE91E63)),
                      const SizedBox(width: 6),
                      Text(
                        novel.author,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Теги
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: novel.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white60),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Описание
                  Text(
                    novel.description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Инфо
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.menu_book,
                        label: '${novel.totalChapters} глав',
                      ),
                      const SizedBox(width: 12),
                      if (hasSave)
                        const _InfoChip(
                          icon: Icons.bookmark,
                          label: 'Есть сохранение',
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Кнопки
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _startGame(context, hasSave),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        hasSave ? 'Продолжить' : 'Начать историю',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  if (hasSave) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _startNewGame(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Начать заново',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startGame(BuildContext context, bool hasSave) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GameScreen(novelId: novel.id),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _startNewGame(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Начать заново?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Весь прогресс будет потерян. Вы уверены?',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              ref.read(saveServiceProvider).deleteSave(novel.id);
              Navigator.pop(ctx);
              _startGame(context, false);
            },
            child: const Text('Начать заново',
                style: TextStyle(color: Color(0xFFE91E63))),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.white38)),
      ],
    );
  }
}
