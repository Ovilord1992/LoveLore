import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'currency_service.dart';

/// Провайдер VIP-сервиса
final vipServiceProvider =
    StateNotifierProvider<VipService, VipState>((ref) => VipService(ref));

/// Состояние VIP-подписки
class VipState {
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? lastDailyReward;
  final int dailyDiamondsCollected; // сколько дней подряд получал

  const VipState({
    this.isActive = false,
    this.expiresAt,
    this.lastDailyReward,
    this.dailyDiamondsCollected = 0,
  });

  VipState copyWith({
    bool? isActive,
    DateTime? expiresAt,
    DateTime? lastDailyReward,
    int? dailyDiamondsCollected,
  }) =>
      VipState(
        isActive: isActive ?? this.isActive,
        expiresAt: expiresAt ?? this.expiresAt,
        lastDailyReward: lastDailyReward ?? this.lastDailyReward,
        dailyDiamondsCollected:
            dailyDiamondsCollected ?? this.dailyDiamondsCollected,
      );

  Map<String, dynamic> toJson() => {
        'isActive': isActive,
        'expiresAt': expiresAt?.toIso8601String(),
        'lastDailyReward': lastDailyReward?.toIso8601String(),
        'dailyDiamondsCollected': dailyDiamondsCollected,
      };

  factory VipState.fromJson(Map<String, dynamic> json) => VipState(
        isActive: json['isActive'] as bool? ?? false,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        lastDailyReward: json['lastDailyReward'] != null
            ? DateTime.parse(json['lastDailyReward'] as String)
            : null,
        dailyDiamondsCollected:
            json['dailyDiamondsCollected'] as int? ?? 0,
      );
}

/// VIP-привилегии
class VipPerks {
  static const dailyDiamonds = 5;
  static const unlimitedTickets = true;
  static const earlyAccess = true;
  static const noAds = true;
  static const exclusiveFrame = true;
}

/// Сервис VIP-подписки
class VipService extends StateNotifier<VipState> {
  static const _boxName = 'app_settings';
  static const _key = 'vip_state';

  final Ref _ref;

  VipService(this._ref) : super(const VipState()) {
    _load();
    _checkExpiry();
  }

  /// Активировать VIP (вызывается после успешной покупки подписки)
  void activate({required DateTime expiresAt}) {
    state = state.copyWith(
      isActive: true,
      expiresAt: expiresAt,
    );
    _save();
  }

  /// Деактивировать VIP
  void deactivate() {
    state = state.copyWith(isActive: false);
    _save();
  }

  /// Забрать ежедневные алмазы (вызывается при входе в приложение)
  bool collectDailyDiamonds() {
    if (!state.isActive) return false;

    final now = DateTime.now();
    final last = state.lastDailyReward;

    // Уже собирал сегодня
    if (last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day) {
      return false;
    }

    _ref.read(currencyServiceProvider.notifier).addDiamonds(VipPerks.dailyDiamonds);
    state = state.copyWith(
      lastDailyReward: now,
      dailyDiamondsCollected: state.dailyDiamondsCollected + 1,
    );
    _save();
    return true;
  }

  /// Безлимитные билеты для VIP
  bool get hasUnlimitedTickets => state.isActive;

  /// Ранний доступ к главам
  bool get hasEarlyAccess => state.isActive;

  /// Без рекламы
  bool get isAdFree => state.isActive;

  /// Проверка истечения подписки
  void _checkExpiry() {
    if (state.isActive && state.expiresAt != null) {
      if (DateTime.now().isAfter(state.expiresAt!)) {
        deactivate();
      }
    }
  }

  void _load() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_key);
      if (data != null) {
        state = VipState.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }
}
