import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

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

  const RemoteConfig({
    this.version = 0,
    this.economy = const EconomyConfig(),
    this.ads = const AdsConfig(),
    this.iap = const IapConfig(),
    this.vip = const VipConfig(),
    this.daily = const [],
    this.achievements = const [],
    this.localization = const {},
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

  const AdsConfig({
    this.maxAdsPerDay = 5,
    this.diamondReward = 3,
    this.ticketReward = 1,
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) => AdsConfig(
        maxAdsPerDay: json['maxAdsPerDay'] as int? ?? 5,
        diamondReward: json['diamondReward'] as int? ?? 3,
        ticketReward: json['ticketReward'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'maxAdsPerDay': maxAdsPerDay,
        'diamondReward': diamondReward,
        'ticketReward': ticketReward,
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
    this.dailyDiamonds = 5,
    this.unlimitedTickets = true,
    this.earlyAccess = true,
    this.noAds = true,
    this.exclusiveFrame = true,
  });

  factory VipConfig.fromJson(Map<String, dynamic> json) => VipConfig(
        dailyDiamonds: json['dailyDiamonds'] as int? ?? 5,
        unlimitedTickets: json['unlimitedTickets'] as bool? ?? true,
        earlyAccess: json['earlyAccess'] as bool? ?? true,
        noAds: json['noAds'] as bool? ?? true,
        exclusiveFrame: json['exclusiveFrame'] as bool? ?? true,
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

  /// Текущий конфиг (для чтения из main.dart)
  RemoteConfig get config => state;

  RemoteConfigService() : super(_defaultConfig) {
    _loadCached();
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
      state = RemoteConfig.fromJson(json);
      debugPrint('[RemoteConfig] Loaded v${state.version} from server');
      _saveCache();
    } catch (e) {
      debugPrint('[RemoteConfig] Fetch failed: $e (using cache/defaults)');
    }
  }

  void _loadCached() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_cacheKey);
      if (data != null) {
        state = RemoteConfig.fromJson(
            jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_cacheKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }
}
