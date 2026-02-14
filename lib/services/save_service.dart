import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_state.dart';

final saveServiceProvider = Provider<SaveService>((ref) => SaveService());

/// Сервис сохранения/загрузки прогресса
class SaveService {
  static const _boxName = 'game_saves';

  Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  /// Сохранить состояние игры
  Future<void> saveGame(GameState state) async {
    final box = Hive.box<String>(_boxName);
    final json = jsonEncode(state.toJson());
    await box.put(state.novelId, json);
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
