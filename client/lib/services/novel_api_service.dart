import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/novel.dart';
import 'api_config.dart';

/// Таймаут для обычных GET-запросов (каталог, главы, переводы).
const Duration _kRequestTimeout = Duration(seconds: 10);

/// Таймаут для скачивания крупных ZIP-архивов.
const Duration _kDownloadTimeout = Duration(seconds: 60);

/// Статус загрузки
enum DownloadStatus { idle, downloading, completed, error }

class DownloadState {
  final DownloadStatus status;
  final double progress; // 0.0 - 1.0
  final String? error;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.progress = 0,
    this.error,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
  }) =>
      DownloadState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: error ?? this.error,
      );
}

/// Провайдер для каталога новелл с сервера
final novelCatalogProvider =
    FutureProvider<List<NovelMeta>>((ref) async {
  final service = ref.read(novelApiServiceProvider);
  return service.fetchCatalog();
});

/// Провайдер состояния загрузки для каждой новеллы
final downloadStateProvider = StateNotifierProvider.family<
    DownloadNotifier, DownloadState, String>((ref, novelId) {
  return DownloadNotifier(ref, novelId);
});

final novelApiServiceProvider =
    Provider<NovelApiService>((ref) => NovelApiService());

/// Сервис для работы с API каталога новелл
class NovelApiService {
  static const _baseUrl = ApiConfig.baseUrl;

  /// Получить каталог доступных новелл
  Future<List<NovelMeta>> fetchCatalog() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/novels'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['novels'] as List;
        final novels = list
            .map((j) => NovelMeta.fromJson(j as Map<String, dynamic>))
            .toList();
        print('[NovelAPI] Catalog loaded: ${novels.length} novels');
        return novels;
      }
      print('[NovelAPI] Catalog fetch failed: status ${response.statusCode}');
      return [];
    } catch (e) {
      print('[NovelAPI] Catalog fetch error: $e');
      return [];
    }
  }

  /// Получить список глав новеллы
  Future<List<ChapterInfo>> fetchChaptersList(String novelId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/novels/$novelId/chapters'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['chapters'] as List;
        return list
            .map((j) => ChapterInfo.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Скачать JSON одной главы с сервера
  Future<bool> downloadChapter(String novelId, int chapterNumber) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/novels/$novelId/chapters/$chapterNumber/download'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode != 200) return false;

      final appDir = await getApplicationDocumentsDirectory();
      final chapterFile = File(
        '${appDir.path}/novels/$novelId/chapters/chapter_$chapterNumber.json',
      );
      await chapterFile.create(recursive: true);
      await chapterFile.writeAsString(response.body);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Скачать контент-пак новеллы (ZIP).
  ///
  /// На плохой сети делаем до 3 попыток (исходная + 2 retry) при
  /// `TimeoutException` или `SocketException`. На таймаут всей операции
  /// (включая стриминг тела) — `_kDownloadTimeout`.
  Future<String?> downloadNovelPack(
    String novelId, {
    void Function(double progress)? onProgress,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final request = http.Request(
          'GET',
          Uri.parse('$_baseUrl/novels/$novelId/download'),
        );
        final streamedResponse = await request.send().timeout(_kDownloadTimeout);

        if (streamedResponse.statusCode != 200) return null;

        final contentLength = streamedResponse.contentLength ?? 0;
        final appDir = await getApplicationDocumentsDirectory();
        final tempFile = File('${appDir.path}/temp_$novelId.zip');
        final sink = tempFile.openWrite();

        int received = 0;
        try {
          await streamedResponse.stream
              .forEach((chunk) {
                sink.add(chunk);
                received += chunk.length;
                if (contentLength > 0) {
                  onProgress?.call(received / contentLength);
                }
              })
              .timeout(_kDownloadTimeout);
        } finally {
          await sink.close();
        }
        return tempFile.path;
      } on TimeoutException catch (e) {
        print('[NovelAPI] Download timeout (attempt ${attempt + 1}/3): $e');
        if (attempt == 2) rethrow;
      } on SocketException catch (e) {
        print('[NovelAPI] Download socket error (attempt ${attempt + 1}/3): $e');
        if (attempt == 2) rethrow;
      } catch (e) {
        print('[NovelAPI] Download error: $e');
        return null;
      }
    }
    return null;
  }

  /// Распаковать контент-пак в папку новелл
  Future<bool> extractNovelPack(String zipPath, String novelId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final novelDir = Directory('${appDir.path}/novels/$novelId');
      await novelDir.create(recursive: true);

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Определяем общий префикс (если файлы внутри подпапки)
      String prefix = '';
      final metaEntry = archive.files.firstWhere(
        (f) => f.name.endsWith('meta.json'),
        orElse: () => archive.files.first,
      );
      if (metaEntry.name.contains('/')) {
        prefix = metaEntry.name.substring(0, metaEntry.name.lastIndexOf('/') + 1);
      }

      for (final file in archive) {
        // Убираем общий префикс из пути
        String name = file.name;
        if (prefix.isNotEmpty && name.startsWith(prefix)) {
          name = name.substring(prefix.length);
        }
        if (name.isEmpty) continue;

        final filePath = '${novelDir.path}/$name';
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }

      // Удалить временный файл
      await File(zipPath).delete();

      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Нотификатор состояния загрузки конкретной новеллы
class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref _ref;
  final String _novelId;

  DownloadNotifier(this._ref, this._novelId)
      : super(const DownloadState());

  /// Начать загрузку новеллы
  Future<void> download() async {
    state = state.copyWith(
      status: DownloadStatus.downloading,
      progress: 0,
    );

    final api = _ref.read(novelApiServiceProvider);

    // 1. Скачиваем ZIP
    final zipPath = await api.downloadNovelPack(
      _novelId,
      onProgress: (p) {
        state = state.copyWith(progress: p * 0.8); // 80% — загрузка
      },
    );

    if (zipPath == null) {
      state = state.copyWith(
        status: DownloadStatus.error,
        error: 'Ошибка загрузки',
      );
      return;
    }

    // 2. Распаковываем
    state = state.copyWith(progress: 0.9); // 90% — распаковка
    final success = await api.extractNovelPack(zipPath, _novelId);

    if (success) {
      state = state.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      );
    } else {
      state = state.copyWith(
        status: DownloadStatus.error,
        error: 'Ошибка распаковки',
      );
    }
  }
}
