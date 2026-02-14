import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

final novelLoaderProvider = Provider<NovelLoader>((ref) => NovelLoader());

/// Загрузчик новелл из assets
class NovelLoader {
  /// Загрузить метаданные новеллы
  Future<NovelMeta> loadNovelMeta(String novelId) async {
    final json = await _loadJson('assets/novels/$novelId/meta.json');
    return NovelMeta.fromJson(json);
  }

  /// Загрузить список персонажей
  Future<List<Character>> loadCharacters(String novelId) async {
    final json = await _loadJson('assets/novels/$novelId/characters.json');
    final list = json['characters'] as List;
    return list.map((c) => Character.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Загрузить начальные переменные
  Future<Map<String, dynamic>> loadInitialVariables(String novelId) async {
    try {
      final json = await _loadJson('assets/novels/$novelId/variables.json');
      return Map<String, dynamic>.from(json);
    } catch (_) {
      return {};
    }
  }

  /// Загрузить главу
  Future<Chapter?> loadChapter(String novelId, String chapterId) async {
    try {
      final json =
          await _loadJson('assets/novels/$novelId/chapters/$chapterId.json');
      return Chapter.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Загрузить список всех доступных новелл
  Future<List<NovelMeta>> loadAllNovels() async {
    // Читаем манифест со списком новелл
    try {
      final manifestJson = await _loadJson('assets/novels/manifest.json');
      final novelIds = List<String>.from(manifestJson['novels'] as List);
      final novels = <NovelMeta>[];
      for (final id in novelIds) {
        try {
          novels.add(await loadNovelMeta(id));
        } catch (_) {}
      }
      return novels;
    } catch (_) {
      return [];
    }
  }

  /// Путь к ассету новеллы
  String getAssetPath(String novelId, String assetName) {
    return 'assets/novels/$novelId/assets/$assetName';
  }

  Future<Map<String, dynamic>> _loadJson(String path) async {
    final data = await rootBundle.loadString(path);
    return jsonDecode(data) as Map<String, dynamic>;
  }
}
