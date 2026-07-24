import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_state.dart';

final saveServiceProvider = StateNotifierProvider<SaveService, int>((ref) => SaveService());

/// Сервис сохранения/загрузки прогресса.
///
/// Ключи в боксе `game_saves`:
/// - `<novelId>` — автосейв (как раньше);
/// - `<novelId>#slot<N>` — ручные слоты 1..[manualSlotCount].
///
/// State (int) — счётчик изменений для реактивности.
class SaveService extends StateNotifier<int> {
  static const _boxName = 'game_saves';

  /// Количество ручных слотов
  static const int manualSlotCount = 3;

  /// Маркер слота в ключе
  static const String slotMarker = '#slot';

  SaveService() : super(0);

  Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  /// Ключ ручного слота
  static String slotKey(String novelId, int slot) =>
      '$novelId$slotMarker$slot';

  /// Сохранить состояние игры (автосейв)
  Future<void> saveGame(GameState gameState) async {
    final box = Hive.box<String>(_boxName);
    final json = jsonEncode(gameState.toJson());
    await box.put(gameState.novelId, json);
    state++; // уведомить подписчиков
  }

  /// Сохранить в ручной слот (1..manualSlotCount)
  Future<void> saveToSlot(GameState gameState, int slot) async {
    final box = Hive.box<String>(_boxName);
    final stamped = gameState.copyWith(lastPlayed: DateTime.now());
    await box.put(slotKey(gameState.novelId, slot), jsonEncode(stamped.toJson()));
    state++;
  }

  /// Загрузить автосейв новеллы
  GameState? loadGame(String novelId) {
    return _decode(Hive.box<String>(_boxName).get(novelId));
  }

  /// Загрузить ручной слот
  GameState? loadSlot(String novelId, int slot) {
    return _decode(Hive.box<String>(_boxName).get(slotKey(novelId, slot)));
  }

  /// Самое свежее сохранение среди автосейва и всех слотов (по lastPlayed).
  /// Используется кнопкой «Продолжить».
  GameState? loadLatest(String novelId) {
    GameState? latest = loadGame(novelId);
    for (var slot = 1; slot <= manualSlotCount; slot++) {
      final candidate = loadSlot(novelId, slot);
      if (candidate == null) continue;
      if (latest == null || candidate.lastPlayed.isAfter(latest.lastPlayed)) {
        latest = candidate;
      }
    }
    return latest;
  }

  /// Удалить автосейв
  Future<void> deleteSave(String novelId) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(novelId);
    state++; // уведомить подписчиков
  }

  /// Удалить ручной слот
  Future<void> deleteSlot(String novelId, int slot) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(slotKey(novelId, slot));
    state++;
  }

  /// Удалить все сохранения новеллы (автосейв + слоты)
  Future<void> deleteAllSaves(String novelId) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(novelId);
    for (var slot = 1; slot <= manualSlotCount; slot++) {
      await box.delete(slotKey(novelId, slot));
    }
    state++;
  }

  /// Есть ли автосейв
  bool hasSave(String novelId) {
    final box = Hive.box<String>(_boxName);
    return box.containsKey(novelId);
  }

  /// Есть ли слот
  bool hasSlot(String novelId, int slot) {
    final box = Hive.box<String>(_boxName);
    return box.containsKey(slotKey(novelId, slot));
  }

  /// Есть ли хоть какое-то сохранение (автосейв или слот)
  bool hasAnySave(String novelId) {
    if (hasSave(novelId)) return true;
    for (var slot = 1; slot <= manualSlotCount; slot++) {
      if (hasSlot(novelId, slot)) return true;
    }
    return false;
  }

  /// Получить список всех новелл с автосейвом (слоты не включаются —
  /// серверная синхронизация оперирует автосейвом per novelId).
  List<String> getSavedNovelIds() {
    final box = Hive.box<String>(_boxName);
    return box.keys
        .cast<String>()
        .where((k) => !k.contains(slotMarker))
        .toList();
  }

  GameState? _decode(String? json) {
    if (json == null) return null;
    try {
      return GameState.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
