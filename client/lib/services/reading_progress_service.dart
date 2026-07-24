import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Провайдер прогресса чтения (для fast-forward по прочитанному)
final readingProgressProvider = Provider<ReadingProgressService>((ref) {
  return ReadingProgressService();
});

/// Хранит множество прочитанных событий per novel: `sceneId:eventIndex`.
/// Бокс `reading_progress` открывается в main.dart до runApp.
class ReadingProgressService {
  static const boxName = 'reading_progress';

  /// Кап записей на новеллу — защита от неограниченного роста бокса.
  static const int maxEntriesPerNovel = 20000;

  final Map<String, Set<String>> _cache = {};
  // Дебаунс-грязные новеллы, чтобы не писать в Hive на каждое событие
  final Set<String> _dirty = {};

  Set<String> _load(String novelId) {
    final cached = _cache[novelId];
    if (cached != null) return cached;
    var set = <String>{};
    try {
      final box = Hive.box<String>(boxName);
      final raw = box.get(novelId);
      if (raw != null && raw.isNotEmpty) {
        set = Set<String>.from(jsonDecode(raw) as List);
      }
    } catch (_) {}
    _cache[novelId] = set;
    return set;
  }

  static String entryKey(String sceneId, int eventIndex) =>
      '$sceneId:$eventIndex';

  /// Отметить событие прочитанным
  void markRead(String novelId, String sceneId, int eventIndex) {
    final set = _load(novelId);
    final key = entryKey(sceneId, eventIndex);
    if (set.contains(key)) return;
    if (set.length >= maxEntriesPerNovel) return;
    set.add(key);
    _dirty.add(novelId);
    _persist(novelId);
  }

  /// Прочитано ли событие
  bool isRead(String novelId, String sceneId, int eventIndex) {
    return _load(novelId).contains(entryKey(sceneId, eventIndex));
  }

  /// Сбросить прогресс чтения новеллы (не используется UI, для полноты API)
  void reset(String novelId) {
    _cache[novelId] = <String>{};
    _dirty.add(novelId);
    _persist(novelId);
  }

  void _persist(String novelId) {
    if (!_dirty.contains(novelId)) return;
    _dirty.remove(novelId);
    try {
      final box = Hive.box<String>(boxName);
      box.put(novelId, jsonEncode(_cache[novelId]!.toList()));
    } catch (_) {}
  }
}
