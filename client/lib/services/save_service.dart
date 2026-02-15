import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_state.dart';

final saveServiceProvider = StateNotifierProvider<SaveService, int>((ref) => SaveService());

/// Сервис сохранения/загрузки прогресса
/// State (int) — счётчик изменений для реактивности
class SaveService extends StateNotifier<int> {
  static const _boxName = 'game_saves';

  SaveService() : super(0);

  Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  /// Сохранить состояние игры
  Future<void> saveGame(GameState gameState) async {
    final box = Hive.box<String>(_boxName);
    final json = jsonEncode(gameState.toJson());
    await box.put(gameState.novelId, json);
    state++; // уведомить подписчиков
  }

  /// Загрузить сохранение для новеллы
  GameState? loadGame(String novelId) {
    final box = Hive.box<String>(_boxName);
    final json = box.get(novelId);
    if (json == null) return null;
    return GameState.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Удалить сохранение
  Future<void> deleteSave(String novelId) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(novelId);
    state++; // уведомить подписчиков
  }

  /// Проверить, есть ли сохранение
  bool hasSave(String novelId) {
    final box = Hive.box<String>(_boxName);
    return box.containsKey(novelId);
  }

  /// Получить список всех сохранённых новелл
  List<String> getSavedNovelIds() {
    final box = Hive.box<String>(_boxName);
    return box.keys.cast<String>().toList();
  }
}
