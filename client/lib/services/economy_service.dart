import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'currency_service.dart';
import 'http_client.dart';

/// Провайдер экономического сервиса (очередь транзакций, спека 2.2)
final economyServiceProvider = Provider<EconomyService>((ref) {
  return EconomyService(ref);
});

/// Офлайн-очередь операций с валютой + флаш в POST /v1/economy/transactions.
///
/// Каждая мутация валюты применяется локально мгновенно (CurrencyService)
/// и кладётся сюда с uuid-ключом (идемпотентность на сервере).
/// Ответные `balances` авторитетны — локальный баланс приводится к ним.
/// Отклонённые (rejected) операции удаляются из очереди.
class EconomyService {
  static const boxName = 'economy_queue';

  /// Кап очереди для неавторизованных пользователей
  static const int maxQueueLength = 500;

  static const _legacySyncFlagKey = 'legacy_sync_done';
  static const _settingsBox = 'app_settings';

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  Timer? _flushDebounce;
  Future<void>? _flushInFlight;

  EconomyService(this._ref);

  bool get _isLoggedIn => _ref.read(authServiceProvider).isLoggedIn;

  Box<String> get _box => Hive.box<String>(boxName);

  /// Количество операций в очереди
  int get pendingCount {
    try {
      return _box.length;
    } catch (_) {
      return 0;
    }
  }

  /// Положить операцию в очередь. [currency]: `diamonds` | `tickets`.
  /// Reason/refId — по таблице спеки 2.2.
  void enqueue({
    required String currency,
    required int delta,
    required String reason,
    String? refId,
  }) {
    if (delta == 0) return;
    try {
      final box = _box;
      // Кап: не даём очереди расти бесконечно без логина —
      // выбрасываем самые старые записи.
      while (box.length >= maxQueueLength) {
        final oldest = box.keys.cast<String>().firstOrNull;
        if (oldest == null) break;
        box.delete(oldest);
      }
      final key = _uuid.v4();
      box.put(
        key,
        jsonEncode({
          'key': key,
          'currency': currency,
          'delta': delta,
          'reason': reason,
          'refId': ?refId,
          'clientTs': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('[Economy] enqueue failed: $e');
    }
    _scheduleFlush();
  }

  /// Хук после логина: отдать накопленную очередь
  void onLogin() {
    // ignore: discarded_futures
    flush();
  }

  /// Дебаунс-флаш после enqueue (только при активной сессии)
  void _scheduleFlush() {
    if (!_isLoggedIn) return;
    _flushDebounce?.cancel();
    _flushDebounce = Timer(const Duration(seconds: 3), () {
      // ignore: discarded_futures
      flush();
    });
  }

  /// Отправить очередь батчем. Single-flight: параллельные вызовы ждут один
  /// и тот же Future (двойная отправка ключей не критична — идемпотентность,
  /// но и не нужна).
  Future<void> flush() {
    final inFlight = _flushInFlight;
    if (inFlight != null) return inFlight;
    final future = _doFlush().whenComplete(() => _flushInFlight = null);
    _flushInFlight = future;
    return future;
  }

  Future<void> _doFlush() async {
    if (!_isLoggedIn) return;
    List<Map<String, dynamic>> transactions;
    try {
      transactions = _box.values
          .map((raw) {
            try {
              return Map<String, dynamic>.from(jsonDecode(raw) as Map);
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (_) {
      return;
    }
    if (transactions.isEmpty) {
      // Очередь пуста, но legacy_sync мог ещё не выполняться (первый логин
      // без локальных операций) — сверим балансы через пуш пустого батча
      // не делаем: без транзакций серверные балансы получит pullAll.
      return;
    }

    // Запоминаем локальные алмазы ДО применения серверных балансов —
    // нужно для одноразового legacy_sync.
    final localDiamondsBefore =
        _ref.read(currencyServiceProvider).diamonds;

    final applied = await _postBatch(transactions);
    if (applied == null) return; // сеть/сервер — попробуем позже

    // Одноразовый legacy_sync: если локальных алмазов больше серверных —
    // мигрируем разницу (сервер ограничит economy.legacySyncCap).
    if (!_legacySyncDone && applied.balances != null) {
      _setLegacySyncDone();
      final serverDiamonds = applied.balances!['diamonds'];
      if (serverDiamonds is num &&
          localDiamondsBefore > serverDiamonds.toInt()) {
        final delta = localDiamondsBefore - serverDiamonds.toInt();
        final key = _uuid.v4();
        try {
          _box.put(
            key,
            jsonEncode({
              'key': key,
              'currency': 'diamonds',
              'delta': delta,
              'reason': 'legacy_sync',
              'clientTs': DateTime.now().millisecondsSinceEpoch,
            }),
          );
        } catch (_) {}
        final legacyBatch = [
          {
            'key': key,
            'currency': 'diamonds',
            'delta': delta,
            'reason': 'legacy_sync',
            'clientTs': DateTime.now().millisecondsSinceEpoch,
          }
        ];
        final legacyResult = await _postBatch(legacyBatch);
        if (legacyResult?.balances != null) {
          _applyBalances(legacyResult!.balances!);
          return;
        }
      }
    }

    if (applied.balances != null) {
      _applyBalances(applied.balances!);
    }
  }

  /// Отправить батч; удалить из очереди applied/rejected; вернуть результат
  /// или null при транзиентной ошибке.
  Future<_FlushResult?> _postBatch(
      List<Map<String, dynamic>> transactions) async {
    try {
      final client = _ref.read(httpClientProvider);
      final response = await client.post(
        '/economy/transactions',
        body: {'transactions': transactions},
      );
      if (response.statusCode != 200) {
        debugPrint('[Economy] flush status ${response.statusCode}');
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List? ?? [];
      for (final r in results) {
        final m = r as Map<String, dynamic>;
        final key = m['key'] as String?;
        final status = m['status'] as String?;
        if (key == null) continue;
        // applied — подтверждено; rejected — удаляем (сервер отказал).
        if (status == 'applied' || status == 'rejected') {
          try {
            await _box.delete(key);
          } catch (_) {}
        }
        if (status == 'rejected') {
          debugPrint('[Economy] tx $key rejected: ${m['error']}');
        }
      }
      final balances = body['balances'];
      return _FlushResult(
        balances: balances is Map<String, dynamic> ? balances : null,
      );
    } on ApiUnauthorizedException {
      return null; // разлогинены — очередь остаётся до следующего логина
    } catch (e) {
      debugPrint('[Economy] flush failed: $e');
      return null;
    }
  }

  void _applyBalances(Map<String, dynamic> balances) {
    final diamonds = balances['diamonds'];
    final tickets = balances['tickets'];
    _ref.read(currencyServiceProvider.notifier).setBalance(
          diamonds: diamonds is num ? diamonds.toInt() : null,
          tickets: tickets is num ? tickets.toInt() : null,
        );
  }

  bool get _legacySyncDone {
    try {
      return Hive.box<String>(_settingsBox).get(_legacySyncFlagKey) == 'true';
    } catch (_) {
      return true; // не рискуем дублировать миграцию при недоступном боксе
    }
  }

  void _setLegacySyncDone() {
    try {
      Hive.box<String>(_settingsBox).put(_legacySyncFlagKey, 'true');
    } catch (_) {}
  }

  void dispose() {
    _flushDebounce?.cancel();
  }
}

class _FlushResult {
  final Map<String, dynamic>? balances;
  const _FlushResult({this.balances});
}
