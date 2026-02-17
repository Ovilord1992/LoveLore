import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'api_config.dart';

final novelLoaderProvider = Provider<NovelLoader>((ref) => NovelLoader());

/// Загрузчик новелл — из assets (встроенные) и из файловой системы (скачанные)
class NovelLoader {
  /// Загрузить метаданные новеллы
  Future<NovelMeta> loadNovelMeta(String novelId) async {
    final json = await _loadJson(novelId, 'meta.json');
    return NovelMeta.fromJson(json);
  }

  /// Загрузить список персонажей
  Future<List<Character>> loadCharacters(String novelId) async {
    final json = await _loadJson(novelId, 'characters.json');
    final list = json['characters'] as List;
    return list
        .map((c) => Character.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Загрузить начальные переменные
  Future<Map<String, dynamic>> loadInitialVariables(String novelId) async {
    try {
      final json = await _loadJson(novelId, 'variables.json');
      return Map<String, dynamic>.from(json);
    } catch (_) {
      return {};
    }
  }

  /// Загрузить главу
  Future<Chapter?> loadChapter(String novelId, String chapterId) async {
    try {
      final json = await _loadJson(novelId, 'chapters/$chapterId.json');
      return Chapter.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Загрузить список всех доступных новелл (встроенные + скачанные)
  Future<List<NovelMeta>> loadAllNovels() async {
    final novels = <NovelMeta>[];

    // 1. Встроенные новеллы из assets
    try {
      final manifestJson = await _loadAssetJson('assets/novels/manifest.json');
      final novelIds = List<String>.from(manifestJson['novels'] as List);
      for (final id in novelIds) {
        try {
          novels.add(await loadNovelMeta(id));
        } catch (_) {}
      }
    } catch (_) {}

    // 2. Скачанные новеллы из файловой системы
    try {
      final downloadedDir = await _getDownloadedNovelsDir();
      if (await downloadedDir.exists()) {
        final dirs = downloadedDir.listSync().whereType<Directory>();
        for (final dir in dirs) {
          try {
            final metaFile = File('${dir.path}/meta.json');
            if (await metaFile.exists()) {
              final json = jsonDecode(await metaFile.readAsString())
                  as Map<String, dynamic>;
              final meta = NovelMeta.fromJson(json);
              // Не добавляем дубликаты
              if (!novels.any((n) => n.id == meta.id)) {
                novels.add(meta);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 3. Каталог с сервера (новеллы, которых нет локально)
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/novels'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['novels'] as List;
        for (final j in list) {
          final map = Map<String, dynamic>.from(j as Map<String, dynamic>);
          // Сервер отдаёт chaptersCount, модель ожидает totalChapters
          if (map.containsKey('chaptersCount') && !map.containsKey('totalChapters')) {
            map['totalChapters'] = map['chaptersCount'];
          }
          final meta = NovelMeta.fromJson(map);
          if (!novels.any((n) => n.id == meta.id)) {
            novels.add(meta);
          }
        }
      }
    } catch (_) {}

    return novels;
  }

  /// Путь к ассету новеллы (assets или скачанный файл)
  Future<String> getAssetPath(String novelId, String assetName) async {
    // Сначала проверяем скачанные
    final downloadedDir = await _getDownloadedNovelsDir();
    final downloadedFile = File('${downloadedDir.path}/$novelId/assets/$assetName');
    if (await downloadedFile.exists()) {
      return downloadedFile.path;
    }
    // Иначе — встроенный asset
    return 'assets/novels/$novelId/assets/$assetName';
  }

  /// Проверить, скачана ли новелла
  Future<bool> isDownloaded(String novelId) async {
    final dir = await _getDownloadedNovelsDir();
    final novelDir = Directory('${dir.path}/$novelId');
    if (!novelDir.existsSync()) return false;
    // Проверяем что meta.json реально есть
    final metaFile = File('${novelDir.path}/meta.json');
    return metaFile.existsSync();
  }

  /// Проверить, есть ли новелла во встроенных assets (manifest)
  Future<bool> isBuiltInNovel(String novelId) async {
    try {
      final manifestJson = await _loadAssetJson('assets/novels/manifest.json');
      final novelIds = List<String>.from(manifestJson['novels'] as List);
      return novelIds.contains(novelId);
    } catch (_) {
      return false;
    }
  }

  /// Удалить скачанную новеллу
  Future<void> deleteDownloaded(String novelId) async {
    final dir = await _getDownloadedNovelsDir();
    final novelDir = Directory('${dir.path}/$novelId');
    if (await novelDir.exists()) {
      await novelDir.delete(recursive: true);
    }
  }

  /// Загрузить перевод книги
  Future<NovelTranslation?> loadTranslation(String novelId, String language) async {
    try {
      final json = await _loadJson(novelId, 'translations/$language.json');
      return NovelTranslation.fromJson(json);
    } catch (_) {
      // Попробовать загрузить с сервера
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/novels/$novelId/translations/$language'),
          headers: {'Content-Type': 'application/json'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return NovelTranslation.fromJson(data);
        }
      } catch (_) {}
      return null;
    }
  }

  /// Загрузить список доступных языков книги
  Future<List<String>> loadAvailableLanguages(String novelId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/novels/$novelId/languages'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<String>.from(data['availableLanguages'] as List);
      }
    } catch (_) {}
    // Fallback: проверяем локальные файлы
    try {
      final dir = await _getDownloadedNovelsDir();
      final translationsDir = Directory('${dir.path}/$novelId/translations');
      if (await translationsDir.exists()) {
        final files = translationsDir.listSync().whereType<File>();
        return files
            .map((f) => f.path.split('/').last.replaceAll('.json', ''))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Загрузить JSON — сначала ищет в скачанных, потом в assets
  Future<Map<String, dynamic>> _loadJson(
      String novelId, String fileName) async {
    // Проверяем скачанные новеллы
    try {
      final dir = await _getDownloadedNovelsDir();
      final file = File('${dir.path}/$novelId/$fileName');
      if (await file.exists()) {
        final data = await file.readAsString();
        return jsonDecode(data) as Map<String, dynamic>;
      }
    } catch (_) {}

    // Fallback: встроенные assets
    return _loadAssetJson('assets/novels/$novelId/$fileName');
  }

  Future<Map<String, dynamic>> _loadAssetJson(String path) async {
    final data = await rootBundle.loadString(path);
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<Directory> _getDownloadedNovelsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/novels');
  }
}
