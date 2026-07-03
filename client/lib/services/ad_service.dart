import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'remote_config_service.dart';
import 'user_profile_service.dart';

/// Провайдер сервиса рекламы
final adServiceProvider = Provider<AdService>((ref) => AdService(ref));

/// Сервис rewarded-рекламы за алмазы и билеты
class AdService {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  final Ref _ref;

  /// Hive box, открытый в main.dart до runApp.
  static const _settingsBox = 'app_settings';
  static const _adsCountKey = 'ads_watched_today';
  static const _adsResetDateKey = 'ads_last_reset_date';

  AdsConfig get _cfg => _ref.read(remoteConfigProvider).ads;
  int get maxAdsPerDay => _cfg.maxAdsPerDay;
  int get diamondReward => _cfg.diamondReward;
  int get ticketReward => _cfg.ticketReward;

  AdService(this._ref);

  // Тестовые AdUnit ID (заменить на боевые перед релизом)
  static String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android test
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS test
    }
    return '';
  }

  /// Инициализация Mobile Ads SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Можно ли смотреть рекламу (лимит в день)
  bool get canShowAd {
    _checkDailyReset();
    return _adsWatchedToday < maxAdsPerDay;
  }

  /// Сколько просмотров осталось
  int get adsRemainingToday {
    _checkDailyReset();
    return maxAdsPerDay - _adsWatchedToday;
  }

  /// Загрузить rewarded ad заранее
  void preloadAd() {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// Показать рекламу за награду
  /// [onReward] вызывается при успешном просмотре с типом награды
  Future<bool> showRewardedAd({
    required void Function(String rewardType, int amount) onReward,
    String rewardType = 'diamonds',
  }) async {
    _checkDailyReset();
    if (_adsWatchedToday >= maxAdsPerDay) return false;

    if (_rewardedAd == null) {
      preloadAd();
      return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;

    // `ad.show()` завершается уже при ПОКАЗЕ рекламы, а `onUserEarnedReward`
    // приходит только после досмотра. Поэтому ждём закрытия рекламы через
    // Completer и возвращаем реальный результат — иначе UI всегда видел бы
    // `false` и не начислял бы честно заработанную награду.
    final completer = Completer<bool>();
    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadAd(); // предзагрузка следующей
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(onUserEarnedReward: (_, reward) {
      _setAdsWatchedToday(_adsWatchedToday + 1);
      // Накопительный счётчик для достижений (ads_100 и т.п.).
      _ref.read(userProfileProvider.notifier).incrementAdsWatched();
      rewarded = true;
      final amount = rewardType == 'tickets' ? ticketReward : diamondReward;
      onReward(rewardType, amount);
    });

    return completer.future;
  }

  /// Геттер: текущее число просмотров за сегодня (из Hive).
  int get _adsWatchedToday {
    try {
      final box = Hive.box<String>(_settingsBox);
      final raw = box.get(_adsCountKey);
      if (raw == null || raw.isEmpty) return 0;
      return int.tryParse(raw) ?? 0;
    } catch (e) {
      debugPrint('[Ads] Failed to read ads_watched_today: $e');
      return 0;
    }
  }

  /// Сеттер: сохранить число просмотров в Hive.
  void _setAdsWatchedToday(int value) {
    try {
      final box = Hive.box<String>(_settingsBox);
      box.put(_adsCountKey, value.toString());
    } catch (e) {
      debugPrint('[Ads] Failed to write ads_watched_today: $e');
    }
  }

  /// Геттер: дата последнего сброса (или null).
  DateTime? get _lastResetDate {
    try {
      final box = Hive.box<String>(_settingsBox);
      final raw = box.get(_adsResetDateKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (e) {
      debugPrint('[Ads] Failed to read ads_last_reset_date: $e');
      return null;
    }
  }

  /// Сеттер: записать дату последнего сброса (ISO 8601).
  void _setLastResetDate(DateTime date) {
    try {
      final box = Hive.box<String>(_settingsBox);
      box.put(_adsResetDateKey, date.toIso8601String());
    } catch (e) {
      debugPrint('[Ads] Failed to write ads_last_reset_date: $e');
    }
  }

  /// Сброс счётчика при новом дне
  void _checkDailyReset() {
    final today = DateTime.now();
    final last = _lastResetDate;
    if (last == null ||
        today.day != last.day ||
        today.month != last.month ||
        today.year != last.year) {
      _setAdsWatchedToday(0);
      _setLastResetDate(today);
    }
  }

  /// Готова ли реклама к показу
  bool get isAdReady => _rewardedAd != null && canShowAd;

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
