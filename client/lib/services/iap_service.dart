import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'currency_service.dart';
import 'iap_api_client.dart';
import 'iap_pending_queue.dart';
import 'remote_config_service.dart';
import 'vip_service.dart';

/// Провайдер IAP-сервиса
final iapServiceProvider =
    StateNotifierProvider<IapService, IapState>((ref) => IapService(ref));

/// ID продуктов (настроить в App Store Connect / Google Play Console)
class ProductIds {
  static const diamonds20 = 'diamonds_20';
  static const diamonds60 = 'diamonds_60';
  static const diamonds150 = 'diamonds_150';
  static const diamonds500 = 'diamonds_500';
  static const tickets5 = 'tickets_5';
  static const starterBundle = 'starter_bundle';
  static const vipMonthly = 'vip_monthly';

  static const consumables = {
    diamonds20,
    diamonds60,
    diamonds150,
    diamonds500,
    tickets5,
    starterBundle,
  };

  static const subscriptions = {vipMonthly};

  static const all = {
    ...consumables,
    ...subscriptions,
  };

  /// Награды за покупку consumable
  static const rewards = <String, Map<String, int>>{
    diamonds20: {'diamonds': 20},
    diamonds60: {'diamonds': 60},
    diamonds150: {'diamonds': 150},
    diamonds500: {'diamonds': 500},
    tickets5: {'tickets': 5},
    starterBundle: {'diamonds': 100, 'tickets': 10},
  };
}

/// Состояние IAP
class IapState {
  final bool isAvailable;
  final bool isLoading;
  final List<ProductDetails> products;
  final List<PurchaseDetails> purchases;
  final bool starterBundlePurchased;
  final String? error;

  const IapState({
    this.isAvailable = false,
    this.isLoading = true,
    this.products = const [],
    this.purchases = const [],
    this.starterBundlePurchased = false,
    this.error,
  });

  IapState copyWith({
    bool? isAvailable,
    bool? isLoading,
    List<ProductDetails>? products,
    List<PurchaseDetails>? purchases,
    bool? starterBundlePurchased,
    String? error,
  }) =>
      IapState(
        isAvailable: isAvailable ?? this.isAvailable,
        isLoading: isLoading ?? this.isLoading,
        products: products ?? this.products,
        purchases: purchases ?? this.purchases,
        starterBundlePurchased:
            starterBundlePurchased ?? this.starterBundlePurchased,
        error: error,
      );
}

/// Тонкая обёртка над `Platform.isIOS` — чтобы тесты могли подсунуть значение.
typedef PlatformResolver = String Function();

String _defaultPlatformResolver() {
  // На вебе/десктопе доступа к платёжному стору всё равно нет, но дефолт
  // оставим разумным.
  if (Platform.isIOS || Platform.isMacOS) return 'apple';
  return 'google';
}

/// Сервис покупок.
///
/// Контракт: валюту/VIP начисляет ТОЛЬКО после успешного ответа от
/// `POST /v1/iap/verify`. При сетевых сбоях покупка кладётся в
/// [IapPendingQueue] и повторяется при следующем `_init` или ручном
/// `processPendingNow`. `completePurchase` мы зовём всегда, чтобы стор
/// не ретраил бесконечно — но это не значит, что валюта начислена.
class IapService extends StateNotifier<IapState> {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final InAppPurchase _iap;
  final Ref _ref;
  final IapVerifier _verifier;
  final IapPendingQueue _pendingQueue;
  final PlatformResolver _platformResolver;

  /// Ключ Hive для дедупликации обработанных purchaseId
  static const _processedKey = 'processed_purchase_ids';

  /// Максимальная глубина FIFO-окна обработанных id
  static const _processedHistoryLimit = 200;

  /// Коллбэк для начисления наград (устанавливается из UI).
  /// Сохраняем сигнатуру для обратной совместимости — теперь дёргается
  /// только после ответа сервера success/already_claimed.
  void Function(String productId, Map<String, int> rewards)? onReward;

  /// Опциональный коллбэк для UI-ошибок (snackbar и т.п.).
  void Function(String message)? onPurchaseError;

  /// Опциональный коллбэк, когда покупка ушла в очередь до сети.
  void Function(String productId)? onPending;

  IapService(
    this._ref, {
    InAppPurchase? iap,
    IapVerifier? verifier,
    IapPendingQueue? pendingQueue,
    PlatformResolver? platformResolver,
    bool autoInit = true,
  })  : _iap = iap ?? InAppPurchase.instance,
        _verifier = verifier ?? _ref.read(iapApiClientProvider),
        _platformResolver = platformResolver ?? _defaultPlatformResolver,
        _pendingQueue = pendingQueue ??
            IapPendingQueue(
              verifier: verifier ?? _ref.read(iapApiClientProvider),
            ),
        super(const IapState()) {
    if (autoInit) {
      // ignore: discarded_futures
      _init();
    }
  }

  Future<void> _init() async {
    // Восстанавливаем флаг «стартовый бандл куплен» из Hive — иначе после
    // рестарта оффер снова показывается и покупается повторно.
    state = state.copyWith(starterBundlePurchased: _readStarterPurchased());

    final available = await _iap.isAvailable();
    if (!available) {
      state = state.copyWith(isAvailable: false, isLoading: false);
      // Даже если стор недоступен — попробуем разгрести pending.
      // ignore: discarded_futures
      _flushPending();
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      (purchases) {
        // ignore: discarded_futures
        _onPurchaseUpdate(purchases);
      },
      onError: (Object error) {
        state = state.copyWith(error: error.toString());
      },
    );

    await _loadProducts();
    // Разгребаем pending при старте.
    // ignore: discarded_futures
    _flushPending();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(ProductIds.all);
    if (response.error != null) {
      state = state.copyWith(
        isLoading: false,
        error: response.error!.message,
      );
      return;
    }

    // Сортируем по цене
    final sorted = response.productDetails.toList()
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    state = state.copyWith(
      isAvailable: true,
      isLoading: false,
      products: sorted,
    );
  }

  /// Купить продукт
  Future<bool> purchase(ProductDetails product) async {
    // Стартовый бандл — только один раз
    if (product.id == ProductIds.starterBundle &&
        state.starterBundlePurchased) {
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);

    if (ProductIds.subscriptions.contains(product.id)) {
      return _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      return _iap.buyConsumable(purchaseParam: purchaseParam);
    }
  }

  /// Прогнать pending-очередь руками (например, по onResume).
  Future<PendingProcessReport> processPendingNow() => _flushPending();

  Future<PendingProcessReport> _flushPending() async {
    final report = await _pendingQueue.processAll();
    for (var i = 0; i < report.successResults.length; i++) {
      // Пробрасываем productId из очереди — иначе starter bundle из pending
      // не пометится купленным и оффер вернётся.
      final pid =
          i < report.successItems.length ? report.successItems[i].productId : null;
      _applyServerResult(report.successResults[i], productId: pid);
    }
    return report;
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _deliverProduct(purchase);
        }
      } catch (e, st) {
        debugPrint('[IAP] _deliverProduct crashed: $e\n$st');
        _emitError('Не удалось обработать покупку');
      } finally {
        // completePurchase ВСЕГДА — иначе стор будет ретраить и пользователь
        // застрянет. Сервер сам отдаст already_claimed на повторе.
        if (purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
          } catch (e) {
            debugPrint('[IAP] completePurchase failed: $e');
          }
        }
      }
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final purchaseId = purchase.purchaseID;
    final processed = _readProcessedIds();
    // Локальная FIFO-дедупликация — defense-in-depth, чтобы не делать
    // лишний роудтрип. Сервер всё равно вернул бы already_claimed.
    if (purchaseId != null &&
        purchaseId.isNotEmpty &&
        processed.contains(purchaseId)) {
      debugPrint(
          '[IAP] Skipping duplicate delivery for purchaseId=$purchaseId '
          '(productId=${purchase.productID})');
      return;
    }

    final receipt = purchase.verificationData.serverVerificationData;
    if (receipt.isEmpty) {
      debugPrint('[IAP] Empty receipt for ${purchase.productID}');
      _emitError('Покупка не прошла верификацию');
      return;
    }

    final pendingItem = PendingIapPurchase(
      platform: _platformResolver(),
      productId: purchase.productID,
      receipt: receipt,
      purchaseId: purchaseId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    IapVerifyResult result;
    try {
      result = await _verifier.verifyPurchase(
        platform: pendingItem.platform,
        productId: pendingItem.productId,
        receipt: pendingItem.receipt,
      );
    } on IapVerifyTransientException catch (e) {
      debugPrint('[IAP] transient verify failure: $e — queueing');
      await _pendingQueue.add(pendingItem);
      onPending?.call(purchase.productID);
      _emitError('Покупка обрабатывается, валюта появится при подключении');
      return;
    } on IapVerifyUnauthorizedException catch (e) {
      debugPrint('[IAP] unauthorized verify: $e — queueing');
      await _pendingQueue.add(pendingItem);
      onPending?.call(purchase.productID);
      _emitError('Войдите в аккаунт, чтобы получить покупку');
      return;
    } catch (e) {
      // Неизвестная ошибка — тоже в очередь, не теряем валюту.
      debugPrint('[IAP] verify unknown error: $e — queueing');
      await _pendingQueue.add(pendingItem);
      onPending?.call(purchase.productID);
      _emitError('Покупка обрабатывается, валюта появится при подключении');
      return;
    }

    if (result.isSuccess) {
      _applyServerResult(result, productId: purchase.productID);

      if (purchaseId != null && purchaseId.isNotEmpty) {
        _appendProcessedId(purchaseId, processed);
      }
    } else {
      // 400 / invalid — НЕ начисляем.
      debugPrint(
          '[IAP] verify rejected ${purchase.productID}: status=${result.status} error=${result.error}');
      _emitError('Покупка не прошла верификацию');
    }
  }

  /// Применить результат сервера: обновить кеш баланса / VIP / позвать onReward.
  void _applyServerResult(IapVerifyResult result, {String? productId}) {
    // Сервер — источник истины: ставим баланс абсолютно.
    final newBalance = result.newBalance;
    if (newBalance != null) {
      _ref.read(currencyServiceProvider.notifier).setBalance(
            diamonds: newBalance.diamonds,
            tickets: newBalance.tickets,
          );
    }

    final vipExp = result.vipExpiresAt;
    if (vipExp != null) {
      _ref.read(vipServiceProvider.notifier).setExpiresAt(vipExp);
    }

    // Стартовый бандл — помечаем купленным и персистим (в т.ч. из pending-пути).
    if (productId == ProductIds.starterBundle) {
      if (!state.starterBundlePurchased) {
        state = state.copyWith(starterBundlePurchased: true);
      }
      _writeStarterPurchased(true);
    }

    // onReward — для UI (snackbar). Серверные rewards имеют приоритет,
    // fallback — Remote Config / хардкод (для старого UI, который кладёт
    // diamonds/tickets из Map<String,int>).
    if (productId != null) {
      final rewardsMap = _coerceRewards(result.rewards) ?? _fallbackRewards(productId);
      if (rewardsMap != null && rewardsMap.isNotEmpty) {
        onReward?.call(productId, rewardsMap);
      }
    }
  }

  /// Прочитать флаг «стартовый бандл куплен» из Hive.
  bool _readStarterPurchased() {
    try {
      final box = Hive.box<String>('app_settings');
      return box.get('starter_bundle_purchased') == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Сохранить флаг «стартовый бандл куплен» в Hive.
  void _writeStarterPurchased(bool value) {
    try {
      final box = Hive.box<String>('app_settings');
      box.put('starter_bundle_purchased', value.toString());
    } catch (e) {
      debugPrint('[IAP] Failed to persist starter flag: $e');
    }
  }

  Map<String, int>? _coerceRewards(Map<String, dynamic>? rewards) {
    if (rewards == null) return null;
    final result = <String, int>{};
    rewards.forEach((k, v) {
      if (v is num) {
        result[k] = v.toInt();
      } else if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) result[k] = parsed;
      }
    });
    return result.isEmpty ? null : result;
  }

  Map<String, int>? _fallbackRewards(String productId) {
    final configIap = _ref.read(remoteConfigProvider).iap;
    final remote = configIap.getReward(productId);
    if (remote.isNotEmpty) return remote;
    return ProductIds.rewards[productId];
  }

  void _emitError(String message) {
    onPurchaseError?.call(message);
    state = state.copyWith(error: message);
  }

  /// Прочитать множество обработанных purchaseId из Hive.
  /// Возвращает пустой список, если бокса/ключа нет или JSON битый.
  List<String> _readProcessedIds() {
    try {
      final box = Hive.box<String>('app_settings');
      final raw = box.get(_processedKey);
      if (raw == null || raw.isEmpty) return <String>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
      return <String>[];
    } catch (e) {
      debugPrint('[IAP] Failed to read processed purchase ids: $e');
      return <String>[];
    }
  }

  /// Добавить purchaseId в FIFO-окно и сохранить в Hive.
  void _appendProcessedId(String purchaseId, List<String> existing) {
    try {
      final updated = List<String>.from(existing)..add(purchaseId);
      // Обрезаем самые старые id, оставляя последние _processedHistoryLimit
      final trimmed = updated.length > _processedHistoryLimit
          ? updated.sublist(updated.length - _processedHistoryLimit)
          : updated;
      final box = Hive.box<String>('app_settings');
      box.put(_processedKey, jsonEncode(trimmed));
    } catch (e) {
      debugPrint('[IAP] Failed to persist processed purchase id: $e');
    }
  }

  /// Восстановить покупки (подписки).
  /// Restored-purchases приходят в `purchaseStream` и проходят тот же
  /// серверный verify (сервер вернёт already_claimed без двойного начисления).
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Найти продукт по ID
  ProductDetails? findProduct(String id) {
    try {
      return state.products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
