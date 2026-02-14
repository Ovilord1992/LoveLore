import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/novel.dart';

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
  // TODO: заменить на реальный URL сервера
  static const _baseUrl = 'https://api.amoria.app/v1';

  /// Получить каталог доступных новелл
  Future<List<NovelMeta>> fetchCatalog() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/novels'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['novels'] as List;
        return list
            .map((j) => NovelMeta.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Скачать контент-пак новеллы (ZIP)
  Future<String?> downloadNovelPack(
    String novelId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final request = http.Request(
        'GET',
        Uri.parse('$_baseUrl/novels/$novelId/download'),
      );
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) return null;

      final contentLength = streamedResponse.contentLength ?? 0;
      final appDir = await getApplicationDocumentsDirectory();
      final tempFile = File('${appDir.path}/temp_$novelId.zip');
      final sink = tempFile.openWrite();

      int received = 0;
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(received / contentLength);
        }
      }
      await sink.close();
      return tempFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Распаковать контент-пак в папку новелл
  Future<bool> extractNovelPack(String zipPath, String novelId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final novelDir = Directory('${appDir.path}/novels/$novelId');
      await novelDir.create(recursive: true);

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filePath = '${novelDir.path}/${file.name}';
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
