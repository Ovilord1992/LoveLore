import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../engine/scene_engine.dart';
import '../models/novel.dart';
import 'relationship_bar.dart';

/// Маппинг icon из meta.statsDisplay (спека 1.9) на Material-иконки
IconData statIcon(String? icon) {
  return switch (icon) {
    'heart' => Icons.favorite,
    'star' => Icons.star,
    'flame' => Icons.local_fire_department,
    'diamond' => Icons.diamond,
    'moon' => Icons.nightlight_round,
    'sun' => Icons.wb_sunny,
    'leaf' => Icons.eco,
    _ => Icons.favorite,
  };
}

/// Emoji для toast-уведомления (компактнее иконки в строке текста)
String statEmoji(String? icon) {
  return switch (icon) {
    'heart' => '♥',
    'star' => '★',
    'flame' => '🔥',
    'diamond' => '💎',
    'moon' => '🌙',
    'sun' => '☀',
    'leaf' => '🍃',
    _ => '♥',
  };
}

Color _parseHex(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    var cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    return Color(int.parse(cleaned, radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Bottom sheet с панелью статов (прогресс-бары по meta.statsDisplay)
void showStatsPanel(
  BuildContext context, {
  required List<StatDisplayConfig> stats,
  required Map<String, dynamic> variables,
  required String Function(String) translate,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Отношения',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...stats.map((stat) {
              final raw = variables[stat.variable];
              final value = raw is num ? raw : num.tryParse('$raw') ?? 0;
              final color = _parseHex(stat.color, AppTheme.primary);
              final label = stat.label.isNotEmpty
                  ? translate(stat.label)
                  : stat.variable;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(statIcon(stat.icon), color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RelationshipBar(
                        characterName: label,
                        variableKey: stat.variable,
                        value: value,
                        maxValue: stat.max,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

/// Оверлей коротких toast-уведомлений об изменении статов («+1 ♥ Мия»).
/// Слушает [statChangesProvider] и показывает всплывашки сверху экрана.
class StatToastHost extends ConsumerStatefulWidget {
  const StatToastHost({super.key});

  @override
  ConsumerState<StatToastHost> createState() => _StatToastHostState();
}

class _StatToastHostState extends ConsumerState<StatToastHost> {
  final List<_ToastItem> _visible = [];
  int _seq = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen<List<StatChangeNotice>>(statChangesProvider, (prev, next) {
      if (next.isEmpty) return;
      for (final change in next) {
        final item = _ToastItem(id: _seq++, notice: change);
        setState(() => _visible.add(item));
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) {
            setState(() => _visible.removeWhere((t) => t.id == item.id));
          }
        });
      }
      // Сбрасываем провайдер, чтобы не показать повторно на rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(statChangesProvider.notifier).state = const [];
      });
    });

    if (_visible.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Column(
          children: _visible.map((item) {
            final n = item.notice;
            final color = _parseHex(n.color, AppTheme.primary);
            final sign = n.delta > 0 ? '+' : '';
            return TweenAnimationBuilder<double>(
              key: ValueKey(item.id),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 250),
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -8),
                  child: child,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '$sign${_fmt(n.delta)} ${statEmoji(n.icon)} ${n.label}',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

class _ToastItem {
  final int id;
  final StatChangeNotice notice;
  _ToastItem({required this.id, required this.notice});
}
