import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../services/locale_service.dart';
import '../models/novel.dart';
import '../models/character.dart';
import '../services/app_version.dart';
import '../services/save_service.dart';
import '../services/novel_loader.dart';
import '../services/novel_api_service.dart';
import '../services/rating_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/novel_cover_image.dart';
import '../widgets/rating_dialog.dart';
import 'game_screen.dart';
import 'wardrobe_screen.dart';

class NovelDetailScreen extends ConsumerStatefulWidget {
  final NovelMeta novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  bool _isAvailableLocally = true;
  bool _checking = true;
  List<Character> _characters = [];
  List<ChapterInfo> _chapterInfos = [];
  RatingSummary? _ratingSummary;
  List<NovelReview> _reviews = [];

  @override
  void initState() {
    super.initState();
    _checkAvailability();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final loader = ref.read(novelLoaderProvider);
    try {
      final chars = await loader.loadCharacters(widget.novel.id);
      if (mounted) setState(() => _characters = chars);
    } catch (_) {}
    try {
      final api = ref.read(novelApiServiceProvider);
      final chapters = await api.fetchChaptersList(widget.novel.id);
      if (mounted && chapters != null) setState(() => _chapterInfos = chapters);
    } catch (_) {}
    // Рейтинг и отзывы (волна 3): сеть недоступна → секции просто скрыты
    try {
      final rating = ref.read(ratingServiceProvider);
      final summary = await rating.fetchSummary(widget.novel.id);
      if (mounted && summary != null) {
        setState(() => _ratingSummary = summary);
      }
      final reviews = await rating.fetchReviews(widget.novel.id);
      if (mounted && reviews.isNotEmpty) {
        setState(() => _reviews = reviews);
      }
    } catch (_) {}
  }

  Future<void> _openRatingDialog() async {
    final summary = await showRatingDialog(context, ref, widget.novel.id);
    if (summary != null && mounted) {
      setState(() => _ratingSummary = summary);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Спасибо за оценку!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
    // «Продолжить» учитывает автосейв И ручные слоты (самый свежий из всех)
    final hasSave = saveService.hasAnySave(widget.novel.id);
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
                      // v2.1 (спека 4.9): бейдж черновика (тест-режим админа)
                      if (!novel.isPublished) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✏ Черновик',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Рейтинг: средняя оценка + количество + кнопка «Оценить»
                  Row(
                    children: [
                      if (_ratingSummary != null &&
                          _ratingSummary!.ratingCount > 0) ...[
                        const Icon(Icons.star,
                            size: 18, color: AppTheme.gold),
                        const SizedBox(width: 4),
                        Text(
                          _ratingSummary!.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${_ratingSummary!.ratingCount})',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white38),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: _openRatingDialog,
                        icon: const Icon(Icons.star_border, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                          side: const BorderSide(color: AppTheme.gold),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text('Оценить',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // v2.1 (спека 4.1): новелла требует более новую версию
                  if (!novel.isFormatSupported) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warning),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.system_update,
                              size: 18, color: AppTheme.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Требуется обновление приложения',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _infoChip(Icons.menu_book, '${novel.chaptersCount} ${ref.tr('chapters_count')}'),
                        _infoChip(Icons.access_time, '~15 мин/глава'),
                        _infoChip(Icons.calendar_today, 'Обновлено'),
                      ],
                    ),
                  ),

                  // Персонажи
                  if (_characters.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text('Персонажи', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _characters.length,
                        itemBuilder: (context, i) {
                          final char = _characters[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                Container(
                                  width: 64, height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE91E63), width: 2),
                                    color: const Color(0xFF16213E),
                                  ),
                                  child: Center(child: Text(char.name[0], style: const TextStyle(fontSize: 24, color: Colors.white))),
                                ),
                                const SizedBox(height: 4),
                                Text(char.name, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // v2: прогресс концовок «N из M» (спека 1.3)
                  if (novel.endings.isNotEmpty)
                    _buildEndingsSection(novel),

                  // v2: гардероб (если у персонажей есть аутфиты)
                  if (_characters.any((c) => c.outfits.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WardrobeScreen(
                                novelId: novel.id,
                                characters: _characters,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.checkroom, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        label: Text(ref.tr('wardrobe')),
                      ),
                    ),

                  // Главы
                  if (_chapterInfos.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(ref.tr('chapters'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    ...List.generate(_chapterInfos.length, (i) {
                      final ch = _chapterInfos[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text('${i + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                        title: Text(ch.title, style: const TextStyle(color: Colors.white)),
                        trailing: Icon(ch.isReleased ? Icons.lock_open : Icons.lock, color: ch.isReleased ? Colors.green : Colors.white24, size: 20),
                      );
                    }),
                  ],

                  // Отзывы (волна 3, чеклист 4)
                  if (_reviews.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: Text('Отзывы',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    ..._reviews.map(_buildReviewCard),
                  ],

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
    // v2.1 (спека 4.1): вход в несовместимую новеллу заблокирован
    if (!widget.novel.isFormatSupported) {
      _showUpdateRequiredDialog(context);
      return;
    }
    if (!_isAvailableLocally) {
      // Скачиваем и ждём завершения
      await ref.read(downloadStateProvider(widget.novel.id).notifier).download();
      final state = ref.read(downloadStateProvider(widget.novel.id));
      if (state.status != DownloadStatus.completed) return;
      setState(() => _isAvailableLocally = true);
    }
    if (context.mounted) _startGame(context, hasSave);
  }

  /// v2.1 (спека 4.1): диалог «Обновите приложение»
  void _showUpdateRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: const Text('Обновите приложение',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Эта история создана для новой версии Amoria.\n'
          'Обновите приложение, чтобы начать чтение.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
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

  /// v2: секция концовок с прогрессом; скрытые до открытия — «???»
  Widget _buildEndingsSection(NovelMeta novel) {
    final profile = ref.watch(userProfileProvider);
    final unlocked = profile.endingsForNovel(novel.id);
    final count =
        novel.endings.where((e) => unlocked.contains(e.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'Концовки: $count из ${novel.endings.length}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: novel.endings.map((ending) {
            final isUnlocked = unlocked.contains(ending.id);
            final title = isUnlocked || !ending.hidden
                ? (ending.title.isNotEmpty ? ending.title : ending.id)
                : '???';
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUnlocked ? AppTheme.primary : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked ? Icons.emoji_events : Icons.lock,
                    size: 14,
                    color: isUnlocked ? AppTheme.primary : Colors.white24,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isUnlocked ? Colors.white : Colors.white38,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Карточка отзыва: имя автора, дата, текст
  Widget _buildReviewCard(NovelReview review) {
    final date = review.createdAt;
    final dateText = date != null
        ? '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.${date.year}'
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  review.authorName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (dateText.isNotEmpty)
                Text(dateText,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
                fontSize: 13, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE91E63)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
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
              await ref
                  .read(saveServiceProvider.notifier)
                  .deleteAllSaves(widget.novel.id);
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
