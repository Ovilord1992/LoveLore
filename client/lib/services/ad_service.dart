import 'dart:async';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'analytics_service.dart';
import 'consent_service.dart';
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

  // Тестовые Google-ID — только для debug-сборок (фолбэк при пустом конфиге)
  static const _testAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testAdUnitIdIos = 'ca-app-pub-3940256099942544/1712485313';

  AdsConfig get _cfg => _ref.read(remoteConfigProvider).ads;
  int get maxAdsPerDay => _cfg.maxAdsPerDay;
  int get diamondReward => _cfg.diamondReward;
  int get ticketReward => _cfg.ticketReward;

  AdService(this._ref);

  /// AdUnit ID из Remote Config (ads.rewardedAdUnitIdAndroid/Ios).
  /// В debug при пустом конфиге — тестовые ID Google.
  /// В release при пустом конфиге — null → реклама отключена (UI прячет кнопки).
  String? get _rewardedAdUnitId {
    final String configured;
    if (Platform.isAndroid) {
      configured = _cfg.rewardedAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      configured = _cfg.rewardedAdUnitIdIos;
    } else {
      configured = '';
    }
    if (configured.isNotEmpty) return configured;
    if (kDebugMode) {
      if (Platform.isAndroid) return _testAdUnitIdAndroid;
      if (Platform.isIOS) return _testAdUnitIdIos;
    }
    return null;
  }

  /// Включена ли реклама вообще (есть валидный AdUnit ID)
  bool get adsEnabled => _rewardedAdUnitId != null;

  /// Инициализация Mobile Ads SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Можно ли смотреть рекламу (реклама включена + лимит в день)
  bool get canShowAd {
    if (!adsEnabled) return false;
    _checkDailyReset();
    return _adsWatchedToday < maxAdsPerDay;
  }

  /// Сколько просмотров осталось
  int get adsRemainingToday {
    if (!adsEnabled) return 0;
    _checkDailyReset();
    return maxAdsPerDay - _adsWatchedToday;
  }

  /// ATT-статус этой сессии (null — ещё не запрашивали). iOS-only.
  bool? _attAuthorized;

  /// Собрать AdRequest с учётом согласия (спека 4.10): при выключенной
  /// персонализации — non-personalized запрос (`npa=1` через extras);
  /// на iOS перед первой персонализированной загрузкой — запрос ATT,
  /// отказ → тоже npa. На Android ATT-плагин не дёргается.
  Future<AdRequest> _buildAdRequest() async {
    var personalized = ConsentService.adsPersonalizationAllowed();
    if (personalized && Platform.isIOS) {
      personalized = await _ensureAttAuthorized();
    }
    return personalized
        ? const AdRequest()
        : const AdRequest(extras: {'npa': '1'});
  }

  /// iOS: убедиться, что трекинг разрешён (ATT). Диалог показывается один
  /// раз системой; недоступность плагина трактуем как отказ (npa).
  Future<bool> _ensureAttAuthorized() async {
    final cached = _attAuthorized;
    if (cached != null) return cached;
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status =
            await AppTrackingTransparency.requestTrackingAuthorization();
      }
      final ok = status == TrackingStatus.authorized;
      _attAuthorized = ok;
      return ok;
    } catch (e) {
      debugPrint('[Ads] ATT request failed: $e');
      return false;
    }
  }

  /// Загрузить rewarded ad заранее
  void preloadAd() {
    final adUnitId = _rewardedAdUnitId;
    if (adUnitId == null || _rewardedAd != null || _isLoading) return;
    _isLoading = true;
    // ignore: discarded_futures
    _loadAd(adUnitId);
  }

  Future<void> _loadAd(String adUnitId) async {
    AdRequest request;
    try {
      request = await _buildAdRequest();
    } catch (e) {
      debugPrint('[Ads] Failed to build ad request: $e');
      request = const AdRequest(extras: {'npa': '1'});
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: request,
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
    if (!adsEnabled) return false;
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
      _ref.read(analyticsServiceProvider).log('ad_reward', {
        'rewardType': rewardType,
        'amount': amount,
      });
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
