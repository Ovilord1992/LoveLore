// Экспорт данных и удаление аккаунта (спека 4.7, требования сторов/GDPR).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'analytics_service.dart';
import 'auth_service.dart';
import 'economy_service.dart';
import 'http_client.dart';

/// Провайдер сервиса аккаунта
final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(ref);
});

/// Ошибка операций с аккаунтом (человекочитаемое сообщение для UI)
class AccountServiceException implements Exception {
  final String message;
  const AccountServiceException(this.message);
  @override
  String toString() => message;
}

class AccountService {
  final Ref _ref;

  AccountService(this._ref);

  /// «Скачать мои данные»: GET /v1/auth/export → JSON-файл в Documents.
  /// Возвращает путь к сохранённому файлу.
  Future<String> exportData() async {
    final http.Response response;
    try {
      final client = _ref.read(httpClientProvider);
      response = await client.get('/auth/export');
    } on ApiUnauthorizedException {
      throw const AccountServiceException(
          'Войдите в аккаунт, чтобы скачать данные');
    } catch (e) {
      debugPrint('[Account] export failed: $e');
      throw const AccountServiceException('Нет соединения. Попробуйте позже');
    }

    if (response.statusCode != 200) {
      throw AccountServiceException(
          'Не удалось скачать данные (код ${response.statusCode})');
    }

    // Проверяем, что сервер вернул валидный JSON, и сохраняем его читаемо
    String pretty;
    try {
      final decoded = jsonDecode(response.body);
      pretty = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      throw const AccountServiceException('Сервер вернул некорректные данные');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/amoria_export_$ts.json');
      await file.writeAsString(pretty);
      return file.path;
    } catch (e) {
      debugPrint('[Account] export write failed: $e');
      throw const AccountServiceException('Не удалось сохранить файл');
    }
  }

  /// «Удалить аккаунт»: DELETE /v1/auth/account → полный локальный wipe
  /// (токены, профиль, валюта, очереди). Возвращает true при успехе.
  Future<bool> deleteAccount() async {
    try {
      final client = _ref.read(httpClientProvider);
      final response = await client.delete('/auth/account');
      if (response.statusCode != 200) {
        debugPrint('[Account] delete status ${response.statusCode}');
        return false;
      }
    } on ApiUnauthorizedException {
      return false;
    } catch (e) {
      debugPrint('[Account] delete failed: $e');
      return false;
    }

    await _wipeLocalData();
    return true;
  }

  /// Полный локальный wipe после удаления аккаунта:
  /// очереди (экономика, аналитика), профиль, валюта, затем токены и
  /// in-memory состояние сервисов (через AuthService.logout — он же
  /// сбрасывает StateNotifier'ы и VIP/IAP-ключи).
  Future<void> _wipeLocalData() async {
    for (final boxName in [
      EconomyService.boxName,
      AnalyticsService.boxName,
      'user_profile',
      'currency',
    ]) {
      try {
        await Hive.box<String>(boxName).clear();
      } catch (e) {
        debugPrint('[Account] wipe "$boxName" failed: $e');
      }
    }
    // logout: удаляет токены/vip/iap-ключи из app_settings, отзывает refresh
    // (best-effort — на сервере он уже отозван) и сбрасывает in-memory
    // состояние currency/vip/profile.
    try {
      await _ref.read(authServiceProvider.notifier).logout();
    } catch (e) {
      debugPrint('[Account] logout after delete failed: $e');
    }
  }
}
