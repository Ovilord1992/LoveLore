import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'remote_config_service.dart';

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

/// Сервис покупок
class IapService extends StateNotifier<IapState> {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final InAppPurchase _iap = InAppPurchase.instance;
  final Ref _ref;

  /// Ключ Hive для дедупликации обработанных purchaseId
  static const _processedKey = 'processed_purchase_ids';

  /// Максимальная глубина FIFO-окна обработанных id
  static const _processedHistoryLimit = 200;

  /// Коллбэк для начисления наград (устанавливается из UI)
  void Function(String productId, Map<String, int> rewards)? onReward;

  IapService(this._ref) : super(const IapState()) {
    _init();
  }

  Future<void> _init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      state = state.copyWith(isAvailable: false, isLoading: false);
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        state = state.copyWith(error: error.toString());
      },
    );

    await _loadProducts();
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

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _deliverProduct(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void _deliverProduct(PurchaseDetails purchase) {
    // Дедупликация: если purchaseID уже обрабатывали — пропускаем начисление,
    // но completePurchase в _onPurchaseUpdate всё равно отработает.
    final purchaseId = purchase.purchaseID;
    final processed = _readProcessedIds();
    if (purchaseId != null &&
        purchaseId.isNotEmpty &&
        processed.contains(purchaseId)) {
      debugPrint(
          '[IAP] Skipping duplicate delivery for purchaseId=$purchaseId '
          '(productId=${purchase.productID})');
      return;
    }

    // Берём награды из Remote Config, fallback на хардкод
    final configIap = _ref.read(remoteConfigProvider).iap;
    final rewards = configIap.getReward(purchase.productID).isNotEmpty
        ? configIap.getReward(purchase.productID)
        : ProductIds.rewards[purchase.productID];
    if (rewards != null) {
      onReward?.call(purchase.productID, rewards);
    }

    if (purchase.productID == ProductIds.starterBundle) {
      state = state.copyWith(starterBundlePurchased: true);
    }

    // Запоминаем обработанный purchaseId (FIFO, не больше 200).
    if (purchaseId != null && purchaseId.isNotEmpty) {
      _appendProcessedId(purchaseId, processed);
    }
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

  /// Восстановить покупки (подписки)
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
