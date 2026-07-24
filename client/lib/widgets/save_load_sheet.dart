import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../engine/scene_engine.dart';
import '../models/game_state.dart';
import '../services/save_service.dart';

/// Bottom sheet «Сохранить / Загрузить»: автосейв (только загрузка)
/// + 3 ручных слота (`<novelId>#slot<N>`), время и глава.
void showSaveLoadSheet(BuildContext context, WidgetRef ref, String novelId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceDark,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SaveLoadSheet(novelId: novelId),
  );
}

class _SaveLoadSheet extends ConsumerWidget {
  final String novelId;

  const _SaveLoadSheet({required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(saveServiceProvider); // реактивность при изменении сейвов
    final saves = ref.read(saveServiceProvider.notifier);
    final autoSave = saves.loadGame(novelId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.save, color: AppTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Сохранить / Загрузить',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SlotTile(
              title: 'Автосохранение',
              save: autoSave,
              canSave: false,
              onLoad: autoSave == null
                  ? null
                  : () => _load(context, ref, autoSave),
            ),
            const Divider(color: Colors.white10),
            for (var slot = 1; slot <= SaveService.manualSlotCount; slot++)
              _buildSlot(context, ref, saves, slot),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(
    BuildContext context,
    WidgetRef ref,
    SaveService saves,
    int slot,
  ) {
    final save = saves.loadSlot(novelId, slot);
    return _SlotTile(
      title: 'Слот $slot',
      save: save,
      canSave: true,
      onSave: () async {
        final current = ref.read(sceneEngineProvider);
        if (current == null) return;
        await saves.saveToSlot(current, slot);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Сохранено в слот $slot'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppTheme.surfaceDark,
            ),
          );
        }
      },
      onLoad: save == null ? null : () => _load(context, ref, save),
    );
  }

  Future<void> _load(
    BuildContext context,
    WidgetRef ref,
    GameState save,
  ) async {
    final engine = ref.read(sceneEngineProvider.notifier);
    final ok = await engine.restoreFromState(save);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось загрузить сохранение'),
          backgroundColor: AppTheme.surfaceDark,
        ),
      );
    }
  }
}

class _SlotTile extends StatelessWidget {
  final String title;
  final GameState? save;
  final bool canSave;
  final VoidCallback? onSave;
  final VoidCallback? onLoad;

  const _SlotTile({
    required this.title,
    required this.save,
    required this.canSave,
    this.onSave,
    this.onLoad,
  });

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = save;
    final subtitle = s == null
        ? 'Пусто'
        : '${_chapterLabel(s.currentChapterId)} · ${_fmtTime(s.lastPlayed)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            s == null ? Icons.bookmark_border : Icons.bookmark,
            color: s == null ? Colors.white24 : AppTheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canSave)
            TextButton(
              onPressed: onSave,
              child: const Text(
                'Сохранить',
                style: TextStyle(color: AppTheme.cyan, fontSize: 13),
              ),
            ),
          TextButton(
            onPressed: onLoad,
            child: Text(
              'Загрузить',
              style: TextStyle(
                color: onLoad == null ? Colors.white24 : AppTheme.primary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _chapterLabel(String chapterId) {
    final match = RegExp(r'(\d+)$').firstMatch(chapterId);
    return match != null ? 'Глава ${match.group(1)}' : chapterId;
  }
}
