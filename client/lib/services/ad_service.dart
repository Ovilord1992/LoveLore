import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'remote_config_service.dart';

/// Провайдер сервиса рекламы
final adServiceProvider = Provider<AdService>((ref) => AdService(ref));

/// Сервис rewarded-рекламы за алмазы и билеты
class AdService {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  int _adsWatchedToday = 0;
  DateTime? _lastResetDate;
  final Ref _ref;

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

    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadAd(); // предзагрузка следующей
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadAd();
      },
    );

    await ad.show(onUserEarnedReward: (_, reward) {
      _adsWatchedToday++;
      rewarded = true;
      final amount = rewardType == 'tickets' ? ticketReward : diamondReward;
      onReward(rewardType, amount);
    });

    return rewarded;
  }

  /// Сброс счётчика при новом дне
  void _checkDailyReset() {
    final today = DateTime.now();
    if (_lastResetDate == null ||
        today.day != _lastResetDate!.day ||
        today.month != _lastResetDate!.month ||
        today.year != _lastResetDate!.year) {
      _adsWatchedToday = 0;
      _lastResetDate = today;
    }
  }

  /// Готова ли реклама к показу
  bool get isAdReady => _rewardedAd != null && canShowAd;

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
