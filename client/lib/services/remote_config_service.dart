import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'api_config.dart';
import 'config_overrides.dart';

final remoteConfigProvider =
    StateNotifierProvider<RemoteConfigService, RemoteConfig>((ref) {
  return RemoteConfigService();
});

/// Конфигурация игры, загружаемая с сервера
class RemoteConfig {
  final int version;
  final EconomyConfig economy;
  final AdsConfig ads;
  final IapConfig iap;
  final VipConfig vip;
  final List<DailyRewardConfig> daily;
  final List<AchievementConfig> achievements;
  final Map<String, Map<String, String>> localization;
  final LinksConfig links;

  const RemoteConfig({
    this.version = 0,
    this.economy = const EconomyConfig(),
    this.ads = const AdsConfig(),
    this.iap = const IapConfig(),
    this.vip = const VipConfig(),
    this.daily = const [],
    this.achievements = const [],
    this.localization = const {},
    this.links = const LinksConfig(),
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      version: json['version'] as int? ?? 0,
      economy: EconomyConfig.fromJson(
          json['economy'] as Map<String, dynamic>? ?? {}),
      ads: AdsConfig.fromJson(json['ads'] as Map<String, dynamic>? ?? {}),
      iap: IapConfig.fromJson(json['iap'] as Map<String, dynamic>? ?? {}),
      vip: VipConfig.fromJson(json['vip'] as Map<String, dynamic>? ?? {}),
      daily: (json['daily'] as List<dynamic>?)
              ?.map((e) =>
                  DailyRewardConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((e) =>
                  AchievementConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      localization: _parseLocalization(json['localization']),
      links:
          LinksConfig.fromJson(json['links'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'economy': economy.toJson(),
        'ads': ads.toJson(),
        'iap': iap.toJson(),
        'vip': vip.toJson(),
        'daily': daily.map((e) => e.toJson()).toList(),
        'achievements': achievements.map((e) => e.toJson()).toList(),
        'localization': localization,
        'links': links.toJson(),
      };

  static Map<String, Map<String, String>> _parseLocalization(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        result[entry.key as String] = (entry.value as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }
    return result;
  }
}

class EconomyConfig {
  final int maxTickets;
  final int ticketRefillMinutes;
  final int startDiamonds;
  final int startTickets;
  final int diamondCostPerTicket;

  const EconomyConfig({
    this.maxTickets = 5,
    this.ticketRefillMinutes = 30,
    this.startDiamonds = 50,
    this.startTickets = 5,
    this.diamondCostPerTicket = 10,
  });

  factory EconomyConfig.fromJson(Map<String, dynamic> json) => EconomyConfig(
        maxTickets: json['maxTickets'] as int? ?? 5,
        ticketRefillMinutes: json['ticketRefillMinutes'] as int? ?? 30,
        startDiamonds: json['startDiamonds'] as int? ?? 50,
        startTickets: json['startTickets'] as int? ?? 5,
        diamondCostPerTicket: json['diamondCostPerTicket'] as int? ?? 10,
      );

  Map<String, dynamic> toJson() => {
        'maxTickets': maxTickets,
        'ticketRefillMinutes': ticketRefillMinutes,
        'startDiamonds': startDiamonds,
        'startTickets': startTickets,
        'diamondCostPerTicket': diamondCostPerTicket,
      };
}

class AdsConfig {
  final int maxAdsPerDay;
  final int diamondReward;
  final int ticketReward;

  /// AdMob rewarded ad unit ID (Android). Пустой в release = реклама выключена.
  final String rewardedAdUnitIdAndroid;

  /// AdMob rewarded ad unit ID (iOS). Пустой в release = реклама выключена.
  final String rewardedAdUnitIdIos;

  const AdsConfig({
    this.maxAdsPerDay = 5,
    this.diamondReward = 3,
    this.ticketReward = 1,
    this.rewardedAdUnitIdAndroid = '',
    this.rewardedAdUnitIdIos = '',
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) => AdsConfig(
        maxAdsPerDay: json['maxAdsPerDay'] as int? ?? 5,
        diamondReward: json['diamondReward'] as int? ?? 3,
        ticketReward: json['ticketReward'] as int? ?? 1,
        rewardedAdUnitIdAndroid:
            json['rewardedAdUnitIdAndroid'] as String? ?? '',
        rewardedAdUnitIdIos: json['rewardedAdUnitIdIos'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'maxAdsPerDay': maxAdsPerDay,
        'diamondReward': diamondReward,
        'ticketReward': ticketReward,
        'rewardedAdUnitIdAndroid': rewardedAdUnitIdAndroid,
        'rewardedAdUnitIdIos': rewardedAdUnitIdIos,
      };
}

class IapConfig {
  final Map<String, Map<String, int>> rewards;

  const IapConfig({this.rewards = const {}});

  factory IapConfig.fromJson(Map<String, dynamic> json) {
    final rewards = <String, Map<String, int>>{};
    for (final entry in json.entries) {
      if (entry.value is Map) {
        rewards[entry.key] = (entry.value as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    }
    return IapConfig(rewards: rewards);
  }

  Map<String, dynamic> toJson() => rewards;

  Map<String, int> getReward(String productId) =>
      rewards[productId] ?? {};
}

class VipConfig {
  final int dailyDiamonds;
  final bool unlimitedTickets;
  final bool earlyAccess;
  final bool noAds;
  final bool exclusiveFrame;

  const VipConfig({
    this.dailyDiamonds = 0,
    this.unlimitedTickets = false,
    this.earlyAccess = false,
    this.noAds = false,
    this.exclusiveFrame = false,
  });

  factory VipConfig.fromJson(Map<String, dynamic> json) => VipConfig(
        dailyDiamonds: json['dailyDiamonds'] as int? ?? 0,
        unlimitedTickets: json['unlimitedTickets'] as bool? ?? false,
        earlyAccess: json['earlyAccess'] as bool? ?? false,
        noAds: json['noAds'] as bool? ?? false,
        exclusiveFrame: json['exclusiveFrame'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'dailyDiamonds': dailyDiamonds,
        'unlimitedTickets': unlimitedTickets,
        'earlyAccess': earlyAccess,
        'noAds': noAds,
        'exclusiveFrame': exclusiveFrame,
      };
}

class DailyRewardConfig {
  final int day;
  final int diamonds;
  final int tickets;
  final String label;

  const DailyRewardConfig({
    required this.day,
    this.diamonds = 0,
    this.tickets = 0,
    required this.label,
  });

  factory DailyRewardConfig.fromJson(Map<String, dynamic> json) =>
      DailyRewardConfig(
        day: json['day'] as int? ?? 1,
        diamonds: json['diamonds'] as int? ?? 0,
        tickets: json['tickets'] as int? ?? 0,
        label: json['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'diamonds': diamonds,
        'tickets': tickets,
        'label': label,
      };
}

/// v2.1 (спека 4.10): ссылки на политику конфиденциальности и условия
/// использования — показываются на экране согласий и в настройках.
class LinksConfig {
  final String privacyPolicyUrl;
  final String termsUrl;

  const LinksConfig({
    this.privacyPolicyUrl = '',
    this.termsUrl = '',
  });

  factory LinksConfig.fromJson(Map<String, dynamic> json) => LinksConfig(
        privacyPolicyUrl: json['privacyPolicyUrl'] as String? ?? '',
        termsUrl: json['termsUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'privacyPolicyUrl': privacyPolicyUrl,
        'termsUrl': termsUrl,
      };
}

class AchievementConfig {
  final String id;
  final String title;
  final String icon;
  final int diamondReward;
  final String description;

  const AchievementConfig({
    required this.id,
    required this.title,
    this.icon = 'star',
    this.diamondReward = 0,
    this.description = '',
  });

  factory AchievementConfig.fromJson(Map<String, dynamic> json) =>
      AchievementConfig(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        icon: json['icon'] as String? ?? 'star',
        diamondReward: json['diamondReward'] as int? ?? 0,
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'diamondReward': diamondReward,
        'description': description,
      };
}

/// Defaults — используются когда нет ни сервера, ни кеша
const _defaultConfig = RemoteConfig(
  version: 0,
  economy: EconomyConfig(),
  ads: AdsConfig(),
  iap: IapConfig(rewards: {
    'diamonds_20': {'diamonds': 20},
    'diamonds_60': {'diamonds': 60},
    'diamonds_150': {'diamonds': 150},
    'diamonds_500': {'diamonds': 500},
    'tickets_5': {'tickets': 5},
    'starter_bundle': {'diamonds': 100, 'tickets': 10},
  }),
  vip: VipConfig(),
  daily: [
    DailyRewardConfig(day: 1, diamonds: 5, label: '5 💎'),
    DailyRewardConfig(day: 2, tickets: 1, label: '1 ⚡'),
    DailyRewardConfig(day: 3, diamonds: 10, label: '10 💎'),
    DailyRewardConfig(day: 4, tickets: 2, label: '2 ⚡'),
    DailyRewardConfig(day: 5, diamonds: 15, label: '15 💎'),
    DailyRewardConfig(day: 6, tickets: 3, label: '3 ⚡'),
    DailyRewardConfig(day: 7, diamonds: 30, label: '30 💎'),
  ],
);

class RemoteConfigService extends StateNotifier<RemoteConfig> {
  static const _boxName = 'app_settings';
  static const _cacheKey = 'remote_config';
  static const _deviceIdKey = 'device_id';

  /// Ключ даты первого запуска (для условий installedAfter/Before, спека 4.6)
  static const firstLaunchKey = 'first_launch_ts';

  /// Текущий конфиг (для чтения из main.dart)
  RemoteConfig get config => state;

  /// Контекст для сегментов/экспериментов (инъекция в тестах)
  final OverrideContext Function() _contextProvider;

  /// Сырой конфиг (base, без overrides) — именно он кешируется, чтобы
  /// секции experiments/segments переживали рестарт, а overrides
  /// пересчитывались на актуальном контексте.
  Map<String, dynamic>? _rawConfig;

  /// Эксперименты, применённые к этому устройству: expId → variant
  final Map<String, String> _appliedExperiments = {};

  /// Эксперименты, по которым exposure уже отправлен в этой сессии
  final Set<String> _exposuresSent = {};

  void Function(String name, [Map<String, dynamic>? params])? _exposureLogger;

  RemoteConfigService({OverrideContext Function()? contextProvider})
      : _contextProvider = contextProvider ?? defaultOverrideContext,
        super(_defaultConfig) {
    _ensureFirstLaunchTs();
    _loadCached();
  }

  /// Применённые эксперименты (expId → variant) — для отладки/тестов
  Map<String, String> get appliedExperiments =>
      Map.unmodifiable(_appliedExperiments);

  /// Подключить логгер аналитики для событий `experiment_exposure`
  /// (вызывается один раз при старте приложения из app.dart).
  /// Каждый применённый эксперимент логируется не чаще раза за сессию.
  void attachExposureLogger(
    void Function(String name, [Map<String, dynamic>? params]) logger,
  ) {
    _exposureLogger = logger;
    _drainExposures();
  }

  void _drainExposures() {
    final logger = _exposureLogger;
    if (logger == null) return;
    for (final entry in _appliedExperiments.entries) {
      if (!_exposuresSent.add(entry.key)) continue;
      logger('experiment_exposure', {
        'experimentId': entry.key,
        'variant': entry.value,
      });
    }
  }

  /// Загрузить конфиг с сервера (вызывается из main.dart)
  Future<void> fetch() async {
    try {
      final url = '${ApiConfig.baseUrl}/config?v=${state.version}';
      debugPrint('[RemoteConfig] Fetching: $url');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );

      debugPrint('[RemoteConfig] Status: ${response.statusCode}');
      if (response.statusCode == 304) {
        debugPrint('[RemoteConfig] Not modified, using cached v${state.version}');
        return;
      }
      if (response.statusCode != 200) {
        debugPrint('[RemoteConfig] Error body: ${response.body}');
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _applyRaw(json);
      debugPrint('[RemoteConfig] Loaded v${state.version} from server');
      _saveCache();
    } catch (e) {
      debugPrint('[RemoteConfig] Fetch failed: $e (using cache/defaults)');
    }
  }

  /// Применить сырой конфиг: overrides сегментов/экспериментов (спека 4.6)
  /// накладываются ДО того, как конфиг становится доступен типизированным
  /// геттерам (state).
  void _applyRaw(Map<String, dynamic> raw) {
    _rawConfig = raw;
    final applied = <AppliedExperiment>[];
    Map<String, dynamic> effective;
    try {
      effective = applyConfigOverrides(
        raw,
        context: _contextProvider(),
        appliedExperiments: applied,
      );
    } catch (e) {
      debugPrint('[RemoteConfig] Overrides failed: $e (using base config)');
      effective = raw;
    }
    state = RemoteConfig.fromJson(effective);
    for (final exp in applied) {
      _appliedExperiments[exp.experimentId] = exp.variant;
    }
    _drainExposures();
  }

  /// Дата первого запуска: проставляется один раз при первом старте
  void _ensureFirstLaunchTs() {
    try {
      final box = Hive.box<String>(_boxName);
      if (box.get(firstLaunchKey) == null) {
        box.put(
          firstLaunchKey,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
    } catch (_) {}
  }

  /// Контекст по умолчанию: deviceId/vip/first_launch — из Hive,
  /// платформа — из dart:io.
  static OverrideContext defaultOverrideContext() {
    var deviceId = 'unknown';
    var isVip = false;
    DateTime? firstLaunch;
    try {
      final box = Hive.box<String>(_boxName);
      var id = box.get(_deviceIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        box.put(_deviceIdKey, id);
      }
      deviceId = id;

      final vipRaw = box.get('vip_state');
      if (vipRaw != null) {
        final vipJson = jsonDecode(vipRaw) as Map<String, dynamic>;
        if (vipJson['isActive'] == true) {
          final expiresAt = vipJson['expiresAt'];
          final expiry =
              expiresAt is String ? DateTime.tryParse(expiresAt) : null;
          isVip = expiry == null || expiry.isAfter(DateTime.now());
        }
      }

      final launchRaw = box.get(firstLaunchKey);
      final launchMs = launchRaw != null ? int.tryParse(launchRaw) : null;
      if (launchMs != null) {
        firstLaunch = DateTime.fromMillisecondsSinceEpoch(launchMs);
      }
    } catch (_) {}

    String platform;
    try {
      platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : Platform.operatingSystem;
    } catch (_) {
      platform = 'unknown';
    }

    return OverrideContext(
      deviceId: deviceId,
      platform: platform,
      isVip: isVip,
      firstLaunchAt: firstLaunch,
    );
  }

  void _loadCached() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_cacheKey);
      if (data != null) {
        _applyRaw(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final box = Hive.box<String>(_boxName);
      final raw = _rawConfig;
      if (raw == null) return;
      await box.put(_cacheKey, jsonEncode(raw));
    } catch (_) {}
  }
}
