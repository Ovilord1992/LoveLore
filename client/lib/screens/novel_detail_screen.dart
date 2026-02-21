import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/locale_service.dart';
import '../models/novel.dart';
import '../services/save_service.dart';
import '../services/novel_loader.dart';
import '../services/novel_api_service.dart';
import '../widgets/novel_cover_image.dart';
import 'game_screen.dart';

class NovelDetailScreen extends ConsumerStatefulWidget {
  final NovelMeta novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  bool _isAvailableLocally = true;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final loader = ref.read(novelLoaderProvider);
    // Проверяем скачанные файлы
    final downloaded = await loader.isDownloaded(widget.novel.id);
    if (downloaded) {
      setState(() { _isAvailableLocally = true; _checking = false; });
      return;
    }
    // Проверяем встроенные assets (manifest)
    final isBuiltIn = await loader.isBuiltInNovel(widget.novel.id);
    setState(() { _isAvailableLocally = isBuiltIn; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(saveServiceProvider); // реактивность при изменении сохранений
    final saveService = ref.read(saveServiceProvider.notifier);
    final hasSave = saveService.hasSave(widget.novel.id);
    final novel = widget.novel;
    final downloadState = ref.watch(downloadStateProvider(novel.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Обложка
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Обложка или плейсхолдер
                  NovelCoverImage(
                    novelId: novel.id,
                    coverImage: novel.coverImage,
                    coverUrl: novel.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2D1854),
                            AppTheme.primary,
                            AppTheme.secondary,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          novel.displayTitle[0],
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w200,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Градиентное затемнение снизу
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Theme.of(context).scaffoldBackgroundColor],
                        stops: const [0.5, 1.0],
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
                    novel.displayTitle,
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
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        novel.author,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.primary,
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
                          color: AppTheme.surfaceColor(context),
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
                    novel.displayDescription,
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
                        label: novel.releasedChapters > 0
                            ? '${novel.releasedChapters}/${novel.totalChapters} ${ref.tr('chapters_count')}'
                            : '${novel.totalChapters} ${ref.tr('chapters_count')}',
                      ),
                      const SizedBox(width: 12),
                      if (hasSave)
                        _InfoChip(
                          icon: Icons.bookmark,
                          label: ref.tr('has_save'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Кнопки
                  if (_checking)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: downloadState.status == DownloadStatus.downloading
                              ? null
                              : () => _handlePlay(context, hasSave),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        child: downloadState.status == DownloadStatus.downloading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                                    value: downloadState.progress > 0 ? downloadState.progress : null,
                                    strokeWidth: 2, color: Colors.white)),
                                  const SizedBox(width: 12),
                                  Text('Загрузка ${(downloadState.progress * 100).toInt()}%',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                ],
                              )
                            : Text(
                                hasSave ? ref.tr('continue_reading') : ref.tr('start_story'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
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
                          child: Text(ref.tr('start_over'),
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
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

  Future<void> _handlePlay(BuildContext context, bool hasSave) async {
    if (!_isAvailableLocally) {
      // Скачиваем и ждём завершения
      await ref.read(downloadStateProvider(widget.novel.id).notifier).download();
      final state = ref.read(downloadStateProvider(widget.novel.id));
      if (state.status != DownloadStatus.completed) return;
      setState(() => _isAvailableLocally = true);
    }
    if (context.mounted) _startGame(context, hasSave);
  }

  void _startGame(BuildContext context, bool hasSave) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => GameScreen(novelId: widget.novel.id),
        transitionsBuilder: (_, animation, _, child) {
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
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(ref.tr('start_over_confirm'),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          ref.tr('progress_will_be_lost'),
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel'),
                style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(saveServiceProvider.notifier).deleteSave(widget.novel.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, _, _) => GameScreen(novelId: widget.novel.id, forceNew: true),
                    transitionsBuilder: (_, animation, _, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              }
            },
            child: Text(ref.tr('start_over'),
                style: const TextStyle(color: AppTheme.primary)),
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
