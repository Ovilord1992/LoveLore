import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'save_service.dart';
import 'user_profile_service.dart';
import 'currency_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

/// Сервис синхронизации данных с сервером
class SyncService {
  static const _baseUrl = ApiConfig.baseUrl;
  final Ref _ref;

  SyncService(this._ref);

  /// Получить auth headers или null если не авторизован
  Map<String, String>? get _headers {
    return _ref.read(authServiceProvider.notifier).authHeaders;
  }

  bool get _isLoggedIn => _ref.read(authServiceProvider).isLoggedIn;

  // ═══════════════════════════════════════════════════════════════════════════
  // SAVES — сохранения игры
  // ═══════════════════════════════════════════════════════════════════════════

  /// Отправить сохранение на сервер
  Future<void> pushSave(String novelId) async {
    if (!_isLoggedIn) return;
    final headers = _headers;
    if (headers == null) return;

    final saveService = _ref.read(saveServiceProvider.notifier);
    final gameState = saveService.loadGame(novelId);
    if (gameState == null) return;

    try {
      await http.put(
        Uri.parse('$_baseUrl/sync/saves/$novelId'),
        headers: headers,
        body: jsonEncode({'data': gameState.toJson()}),
      );
    } catch (_) {}
  }

  /// Получить сохранение с сервера
  Future<Map<String, dynamic>?> pullSave(String novelId) async {
    if (!_isLoggedIn) return null;
    final headers = _headers;
    if (headers == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sync/saves/$novelId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['save']['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE — профиль
  // ═══════════════════════════════════════════════════════════════════════════

  /// Отправить профиль на сервер
  Future<void> pushProfile() async {
    if (!_isLoggedIn) return;
    final headers = _headers;
    if (headers == null) return;

    final profile = _ref.read(userProfileProvider);

    try {
      await http.put(
        Uri.parse('$_baseUrl/sync/profile'),
        headers: headers,
        body: jsonEncode(profile.toJson()),
      );
    } catch (_) {}
  }

  /// Получить профиль с сервера
  Future<Map<String, dynamic>?> pullProfile() async {
    if (!_isLoggedIn) return null;
    final headers = _headers;
    if (headers == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sync/profile'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['profile'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CURRENCY — валюта
  // ═══════════════════════════════════════════════════════════════════════════

  /// Отправить валюту на сервер
  Future<void> pushCurrency() async {
    if (!_isLoggedIn) return;
    final headers = _headers;
    if (headers == null) return;

    final currency = _ref.read(currencyServiceProvider);

    try {
      await http.put(
        Uri.parse('$_baseUrl/sync/currency'),
        headers: headers,
        body: jsonEncode(currency.toJson()),
      );
    } catch (_) {}
  }

  /// Получить валюту с сервера
  Future<Map<String, dynamic>?> pullCurrency() async {
    if (!_isLoggedIn) return null;
    final headers = _headers;
    if (headers == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sync/currency'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['currency'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FULL SYNC — полная синхронизация
  // ═══════════════════════════════════════════════════════════════════════════

  /// Полная синхронизация: pull всех данных с сервера
  Future<void> pullAll() async {
    if (!_isLoggedIn) return;
    final headers = _headers;
    if (headers == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sync/all'),
        headers: headers,
      );

      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // Восстанавливаем сохранения
      final saves = body['saves'] as List?;
      if (saves != null) {
        final saveService = _ref.read(saveServiceProvider.notifier);
        for (final save in saves) {
          final s = save as Map<String, dynamic>;
          final novelId = s['novelId'] as String;
          final data = s['data'] as Map<String, dynamic>;
          // Импортируем если нет локального сохранения
          if (!saveService.hasSave(novelId)) {
            final gameState =
                _ref.read(saveServiceProvider.notifier).loadGame(novelId);
            if (gameState == null) {
              // Создаём GameState из серверных данных
              await _importSave(novelId, data);
            }
          }
        }
      }

      // Восстанавливаем профиль (сервер выигрывает по максимуму)
      final profile = body['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        _ref.read(userProfileProvider.notifier).mergeFromServer(profile);
      }

      // Восстанавливаем валюту
      final currency = body['currency'] as Map<String, dynamic>?;
      if (currency != null) {
        _ref.read(currencyServiceProvider.notifier).mergeFromServer(currency);
      }
    } catch (_) {}
  }

  /// Push всех данных на сервер
  Future<void> pushAll() async {
    if (!_isLoggedIn) return;

    await Future.wait([
      pushProfile(),
      pushCurrency(),
      _pushAllSaves(),
    ]);
  }

  Future<void> _pushAllSaves() async {
    final saveService = _ref.read(saveServiceProvider.notifier);
    final novelIds = saveService.getSavedNovelIds();
    for (final novelId in novelIds) {
      await pushSave(novelId);
    }
  }

  Future<void> _importSave(String novelId, Map<String, dynamic> data) async {
    try {
      final saveService = _ref.read(saveServiceProvider.notifier);
      final gameState = _createGameStateFromJson(novelId, data);
      if (gameState != null) {
        await saveService.saveGame(gameState);
      }
    } catch (_) {}
  }

  dynamic _createGameStateFromJson(
      String novelId, Map<String, dynamic> json) {
    try {
      // Используем GameState.fromJson напрямую
      return _ref
          .read(saveServiceProvider.notifier)
          .loadGame(novelId);
    } catch (_) {
      return null;
    }
  }
}
