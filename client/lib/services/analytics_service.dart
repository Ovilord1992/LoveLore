import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'http_client.dart';

/// Провайдер сервиса аналитики (спека 2.3)
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final service = AnalyticsService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Батч-отправка событий в POST /v1/analytics/events.
///
/// Очередь — Hive-бокс `analytics_queue`; deviceId (uuid) — в app_settings.
/// Флаш: каждые ~30 секунд / при 20+ событиях / при сворачивании приложения.
/// Словарь имён: session_start, novel_start, chapter_start, chapter_complete,
/// choice_made, ad_reward, iap_success, ending_reached, novel_download.
class AnalyticsService {
  static const boxName = 'analytics_queue';
  static const _settingsBox = 'app_settings';
  static const _deviceIdKey = 'device_id';

  static const int flushThreshold = 20;
  static const Duration flushInterval = Duration(seconds: 30);

  /// Кап очереди офлайн
  static const int maxQueueLength = 500;

  final Ref _ref;
  Timer? _timer;
  Future<void>? _flushInFlight;
  int _seq = 0; // монотонный суффикс ключей — сохраняет порядок событий

  AnalyticsService(this._ref) {
    _timer = Timer.periodic(flushInterval, (_) {
      // ignore: discarded_futures
      flush();
    });
  }

  Box<String> get _box => Hive.box<String>(boxName);

  /// Стабильный анонимный идентификатор устройства
  String get deviceId {
    try {
      final box = Hive.box<String>(_settingsBox);
      final existing = box.get(_deviceIdKey);
      if (existing != null && existing.isNotEmpty) return existing;
      final id = const Uuid().v4();
      box.put(_deviceIdKey, id);
      return id;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Записать событие в очередь
  void log(String name, [Map<String, dynamic>? params]) {
    try {
      final box = _box;
      if (box.length >= maxQueueLength) {
        final oldest = box.keys.cast<String>().firstOrNull;
        if (oldest != null) box.delete(oldest);
      }
      final key =
          '${DateTime.now().millisecondsSinceEpoch}_${_seq++}';
      box.put(
        key,
        jsonEncode({
          'name': name,
          if (params != null && params.isNotEmpty) 'params': params,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      if (box.length >= flushThreshold) {
        // ignore: discarded_futures
        flush();
      }
    } catch (e) {
      debugPrint('[Analytics] log failed: $e');
    }
  }

  /// Отправить очередь (single-flight)
  Future<void> flush() {
    final inFlight = _flushInFlight;
    if (inFlight != null) return inFlight;
    final future = _doFlush().whenComplete(() => _flushInFlight = null);
    _flushInFlight = future;
    return future;
  }

  Future<void> _doFlush() async {
    List<String> keys;
    List<Map<String, dynamic>> events;
    try {
      keys = _box.keys.cast<String>().toList();
      if (keys.isEmpty) return;
      events = keys
          .map((k) {
            try {
              return Map<String, dynamic>.from(
                  jsonDecode(_box.get(k)!) as Map);
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return;
    }
    if (events.isEmpty) return;

    try {
      final client = _ref.read(httpClientProvider);
      final response = await client.post(
        '/analytics/events',
        body: {'deviceId': deviceId, 'events': events},
        optionalAuth: true, // auth опционален по спеке 2.3
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        for (final k in keys) {
          try {
            await _box.delete(k);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[Analytics] flush failed: $e');
    }
  }

  /// Вызывать при сворачивании приложения
  void onAppPaused() {
    // ignore: discarded_futures
    flush();
  }

  void dispose() {
    _timer?.cancel();
  }
}
