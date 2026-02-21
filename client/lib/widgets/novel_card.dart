import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../models/novel.dart';
import 'novel_cover_image.dart';

// ═══════════════════════════════════════════════════════════════════
// 1. NovelCard — Standard vertical card for 2-column catalog grids
// ═══════════════════════════════════════════════════════════════════

class NovelCard extends StatefulWidget {
  final NovelMeta novel;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final double? progress;

  const NovelCard({
    super.key,
    required this.novel,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.progress,
  });

  @override
  State<NovelCard> createState() => _NovelCardState();
}

class _NovelCardState extends State<NovelCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _scaleCtrl.reverse();
  void _onTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _onTapCancel() => _scaleCtrl.forward();

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  Widget? _buildBadge() {
    final tags = widget.novel.tags.map((t) => t.toLowerCase()).toSet();
    if (tags.contains('new')) {
      return _Badge(label: 'NEW', color: AppTheme.success);
    }
    if (tags.contains('hot')) {
      return _Badge(label: '🔥 HOT', color: AppTheme.warning);
    }
    if (tags.contains('vip')) {
      return _Badge(label: '👑 VIP', color: AppTheme.gold);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final badge = _buildBadge();

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _handleTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover
                    Container(
                      color: AppTheme.surfaceDark,
                      child: NovelCoverImage(
                        novelId: widget.novel.id,
                        coverImage: widget.novel.coverImage,
                        coverUrl: widget.novel.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: const Center(
                          child: Icon(Icons.auto_stories,
                              size: 48, color: Colors.white24),
                        ),
                      ),
                    ),

                    // Bottom gradient overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),

                    // Title + Author on gradient
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.novel.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.novel.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badge top-right
                    if (badge != null)
                      Positioned(top: 8, right: 8, child: badge),

                    // Favorite heart top-left
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        onTap: widget.onFavoriteToggle,
                        child: Icon(
                          widget.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color:
                              widget.isFavorite ? Colors.red : Colors.white70,
                          size: 22,
                        ),
                      ),
                    ),

                    // Star rating bottom-left (above gradient text)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: _StarRating(),
                    ),

                    // Progress bar at very bottom
                    if (widget.progress != null && widget.progress! > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: widget.progress!.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. ContinueReadingCard — Horizontal scroll "Continue Reading"
// ═══════════════════════════════════════════════════════════════════

class ContinueReadingCard extends StatelessWidget {
  final NovelMeta novel;
  final double progress;
  final VoidCallback? onTap;

  const ContinueReadingCard({
    super.key,
    required this.novel,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover image
              Container(
                color: AppTheme.surfaceDark,
                child: NovelCoverImage(
                  novelId: novel.id,
                  coverImage: novel.coverImage,
                  coverUrl: novel.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: const Center(
                    child: Icon(Icons.auto_stories,
                        size: 40, color: Colors.white24),
                  ),
                ),
              ),

              // Bottom gradient + title
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    novel.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Progress bar at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.black26,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. NovelListCard — Full-width horizontal card for list view
// ═══════════════════════════════════════════════════════════════════

class NovelListCard extends StatelessWidget {
  final NovelMeta novel;
  final VoidCallback? onTap;

  const NovelListCard({
    super.key,
    required this.novel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Cover thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 110,
                child: Container(
                  color: AppTheme.bgDark,
                  child: NovelCoverImage(
                    novelId: novel.id,
                    coverImage: novel.coverImage,
                    coverUrl: novel.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: const Center(
                      child: Icon(Icons.auto_stories,
                          size: 28, color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info column
            Expanded(
              child: SizedBox(
                height: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      novel.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Genre tag chips
                    if (novel.tags.isNotEmpty)
                      SizedBox(
                        height: 24,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: novel.tags.length.clamp(0, 3),
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 6),
                          itemBuilder: (_, i) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              novel.tags[i],
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.primary),
                            ),
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Stats row + read button
                    Row(
                      children: [
                        Text(
                          '⭐ 4.8 · ${novel.releasedChapters} глав',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54),
                        ),
                        const Spacer(),
                        const Text(
                          'Читать →',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '⭐ 4.7',
        style: TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}
