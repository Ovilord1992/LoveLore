import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Провайдер согласий (спека 4.10: возраст 16+, аналитика,
/// персонализированная реклама)
final consentServiceProvider =
    StateNotifierProvider<ConsentService, ConsentState>((ref) {
  return ConsentService();
});

/// Состояние согласий пользователя
class ConsentState {
  /// Подтверждён ли возраст 16+ (false → показываем экран согласий)
  final bool ageConfirmed;

  /// Согласие на аналитику (default on)
  final bool analytics;

  /// Согласие на персонализированную рекламу (default on)
  final bool adsPersonalized;

  const ConsentState({
    this.ageConfirmed = false,
    this.analytics = true,
    this.adsPersonalized = true,
  });

  ConsentState copyWith({
    bool? ageConfirmed,
    bool? analytics,
    bool? adsPersonalized,
  }) =>
      ConsentState(
        ageConfirmed: ageConfirmed ?? this.ageConfirmed,
        analytics: analytics ?? this.analytics,
        adsPersonalized: adsPersonalized ?? this.adsPersonalized,
      );
}

/// Сервис согласий. Ключи в Hive-боксе `app_settings`:
/// `age_confirmed`, `consent_analytics`, `consent_ads_personalized`.
///
/// Аналитика и персонализация по умолчанию ВКЛЮЧЕНЫ (спека 4.10) — экран
/// согласий при первом запуске позволяет их выключить; изменить можно
/// в настройках (секция «Приватность»).
class ConsentService extends StateNotifier<ConsentState> {
  static const _boxName = 'app_settings';
  static const ageConfirmedKey = 'age_confirmed';
  static const analyticsKey = 'consent_analytics';
  static const adsPersonalizedKey = 'consent_ads_personalized';

  ConsentService() : super(const ConsentState()) {
    _loadSync();
  }

  /// Статический геттер для сервисов вне Riverpod-графа (analytics):
  /// согласие на аналитику (default true).
  static bool analyticsAllowed() => _readBool(analyticsKey, true);

  /// Статический геттер: согласие на персонализированную рекламу.
  static bool adsPersonalizationAllowed() =>
      _readBool(adsPersonalizedKey, true);

  static bool _readBool(String key, bool fallback) {
    try {
      final raw = Hive.box<String>(_boxName).get(key);
      if (raw == null || raw.isEmpty) return fallback;
      return raw == 'true';
    } catch (_) {
      return fallback;
    }
  }

  static void _writeBool(String key, bool value) {
    try {
      Hive.box<String>(_boxName).put(key, value.toString());
    } catch (_) {}
  }

  /// Принять согласия с экрана первого запуска
  void acceptConsents({
    required bool analytics,
    required bool adsPersonalized,
  }) {
    _writeBool(ageConfirmedKey, true);
    _writeBool(analyticsKey, analytics);
    _writeBool(adsPersonalizedKey, adsPersonalized);
    state = ConsentState(
      ageConfirmed: true,
      analytics: analytics,
      adsPersonalized: adsPersonalized,
    );
  }

  void setAnalytics(bool value) {
    _writeBool(analyticsKey, value);
    state = state.copyWith(analytics: value);
  }

  void setAdsPersonalized(bool value) {
    _writeBool(adsPersonalizedKey, value);
    state = state.copyWith(adsPersonalized: value);
  }

  void _loadSync() {
    state = ConsentState(
      ageConfirmed: _readBool(ageConfirmedKey, false),
      analytics: _readBool(analyticsKey, true),
      adsPersonalized: _readBool(adsPersonalizedKey, true),
    );
  }
}
