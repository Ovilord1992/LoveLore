import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'iap_api_client.dart';

/// Минимальный snapshot покупки, который мы можем заверификать
/// повторно после рестарта приложения.
@immutable
class PendingIapPurchase {
  final String platform; // 'apple' | 'google'
  final String productId;
  final String receipt;
  final String? purchaseId;
  final int timestamp; // millisSinceEpoch

  const PendingIapPurchase({
    required this.platform,
    required this.productId,
    required this.receipt,
    required this.timestamp,
    this.purchaseId,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'productId': productId,
        'receipt': receipt,
        'purchaseId': purchaseId,
        'timestamp': timestamp,
      };

  factory PendingIapPurchase.fromJson(Map<String, dynamic> json) =>
      PendingIapPurchase(
        platform: json['platform'] as String,
        productId: json['productId'] as String,
        receipt: json['receipt'] as String,
        purchaseId: json['purchaseId'] as String?,
        timestamp:
            (json['timestamp'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
      );

  /// Уникальный ключ записи — для дедупликации в очереди.
  String get key => purchaseId?.isNotEmpty == true
      ? '$platform|$productId|$purchaseId'
      : '$platform|$productId|${receipt.hashCode}';
}

/// Абстрактный store — чтобы тесты могли подсовывать in-memory
/// реализацию вместо Hive.
abstract class PendingQueueStorage {
  List<PendingIapPurchase> read();
  Future<void> write(List<PendingIapPurchase> items);
}

/// Боевая реализация поверх уже открытого Hive-бокса `app_settings`.
class HivePendingQueueStorage implements PendingQueueStorage {
  static const _hiveBoxName = 'app_settings';
  static const _hiveKey = 'pending_iap_verifications';

  @override
  List<PendingIapPurchase> read() {
    try {
      final box = Hive.box<String>(_hiveBoxName);
      final raw = box.get(_hiveKey);
      if (raw == null || raw.isEmpty) return <PendingIapPurchase>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PendingIapPurchase>[];
      return decoded
          .whereType<Map>()
          .map((e) => PendingIapPurchase.fromJson(
              Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[IAP] pending-queue read error: $e');
      return <PendingIapPurchase>[];
    }
  }

  @override
  Future<void> write(List<PendingIapPurchase> items) async {
    try {
      final box = Hive.box<String>(_hiveBoxName);
      await box.put(
        _hiveKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[IAP] pending-queue write error: $e');
    }
  }
}

/// Результат [IapPendingQueue.processAll] — сводка для логов/UI.
class PendingProcessReport {
  final int total;
  final int succeeded;
  final int stillPending;
  final int dropped; // 'invalid' от сервера → выкидываем
  final List<IapVerifyResult> successResults;

  const PendingProcessReport({
    required this.total,
    required this.succeeded,
    required this.stillPending,
    required this.dropped,
    required this.successResults,
  });
}

/// Очередь покупок, ждущих серверной верификации.
///
/// Контракт:
/// - [add] — положить покупку (дедуплицируется по [PendingIapPurchase.key]).
/// - [processAll] — пройтись по очереди, для каждой вызвать [IapVerifier].
///   Успешные / невалидные удаляются, транзиентные остаются.
/// - Persists через [PendingQueueStorage] (по умолчанию — Hive).
class IapPendingQueue {
  final PendingQueueStorage _storage;
  final IapVerifier _verifier;

  /// Колбэк для применения успешного результата (обновить currency / vip / UI).
  final Future<void> Function(
      PendingIapPurchase purchase, IapVerifyResult result)? onApply;

  IapPendingQueue({
    required IapVerifier verifier,
    PendingQueueStorage? storage,
    this.onApply,
  })  : _verifier = verifier,
        _storage = storage ?? HivePendingQueueStorage();

  /// Вернуть текущий снапшот очереди (для тестов / диагностики).
  List<PendingIapPurchase> snapshot() => _storage.read();

  /// Положить покупку в очередь. Дубликаты по [PendingIapPurchase.key]
  /// игнорируются.
  Future<void> add(PendingIapPurchase item) async {
    final current = _storage.read();
    if (current.any((e) => e.key == item.key)) return;
    current.add(item);
    await _storage.write(current);
  }

  /// Пройти всю очередь. Для каждой записи вызывается [IapVerifier].
  /// - success / already_claimed → удалить + позвать [onApply]
  /// - invalid → удалить (валюту не давать, дальше повторять смысла нет)
  /// - transient (network / 5xx) → оставить, попробовать в след. раз
  /// - unauthorized → оставить (юзер залогинится — повторим)
  Future<PendingProcessReport> processAll() async {
    final items = _storage.read();
    if (items.isEmpty) {
      return const PendingProcessReport(
        total: 0,
        succeeded: 0,
        stillPending: 0,
        dropped: 0,
        successResults: [],
      );
    }

    final remaining = <PendingIapPurchase>[];
    final successResults = <IapVerifyResult>[];
    var succeeded = 0;
    var dropped = 0;

    for (final item in items) {
      try {
        final result = await _verifier.verifyPurchase(
          platform: item.platform,
          productId: item.productId,
          receipt: item.receipt,
        );
        if (result.isSuccess) {
          succeeded++;
          successResults.add(result);
          if (onApply != null) {
            try {
              await onApply!(item, result);
            } catch (e) {
              debugPrint('[IAP] pending onApply failed: $e');
            }
          }
        } else {
          // 400/invalid — выкидываем, повторять бесполезно.
          dropped++;
          debugPrint(
              '[IAP] dropping pending ${item.productId}: status=${result.status} error=${result.error}');
        }
      } on IapVerifyTransientException catch (e) {
        debugPrint('[IAP] pending transient ${item.productId}: $e');
        remaining.add(item);
      } on IapVerifyUnauthorizedException catch (e) {
        debugPrint('[IAP] pending unauthorized ${item.productId}: $e');
        remaining.add(item);
      } catch (e) {
        debugPrint('[IAP] pending unknown error ${item.productId}: $e');
        remaining.add(item);
      }
    }

    await _storage.write(remaining);

    return PendingProcessReport(
      total: items.length,
      succeeded: succeeded,
      stillPending: remaining.length,
      dropped: dropped,
      successResults: successResults,
    );
  }
}
