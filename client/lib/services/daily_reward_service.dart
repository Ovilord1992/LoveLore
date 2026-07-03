import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'remote_config_service.dart';

final dailyRewardProvider =
    StateNotifierProvider<DailyRewardService, DailyRewardState>((ref) {
  return DailyRewardService(ref);
});

class DailyRewardState {
  final int currentStreak; // 1–7
  final DateTime? lastClaimDate;
  final bool claimedToday;

  const DailyRewardState({
    this.currentStreak = 0,
    this.lastClaimDate,
    this.claimedToday = false,
  });

  DailyRewardState copyWith({
    int? currentStreak,
    DateTime? lastClaimDate,
    bool? claimedToday,
  }) =>
      DailyRewardState(
        currentStreak: currentStreak ?? this.currentStreak,
        lastClaimDate: lastClaimDate ?? this.lastClaimDate,
        claimedToday: claimedToday ?? this.claimedToday,
      );

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'lastClaimDate': lastClaimDate?.toIso8601String(),
      };

  factory DailyRewardState.fromJson(Map<String, dynamic> json) {
    final lastClaim = json['lastClaimDate'] != null
        ? DateTime.parse(json['lastClaimDate'] as String)
        : null;
    final streak = json['currentStreak'] as int? ?? 0;
    final today = DateTime.now();
    final claimedToday = lastClaim != null &&
        lastClaim.year == today.year &&
        lastClaim.month == today.month &&
        lastClaim.day == today.day;

    return DailyRewardState(
      currentStreak: streak,
      lastClaimDate: lastClaim,
      claimedToday: claimedToday,
    );
  }
}

/// Награды по дням (7-дневный цикл)
class DailyReward {
  final int day;
  final int diamonds;
  final int tickets;
  final String label;

  const DailyReward({
    required this.day,
    this.diamonds = 0,
    this.tickets = 0,
    required this.label,
  });
}

const dailyRewards = [
  DailyReward(day: 1, diamonds: 5, label: '5 💎'),
  DailyReward(day: 2, tickets: 1, label: '1 ⚡'),
  DailyReward(day: 3, diamonds: 10, label: '10 💎'),
  DailyReward(day: 4, tickets: 2, label: '2 ⚡'),
  DailyReward(day: 5, diamonds: 15, label: '15 💎'),
  DailyReward(day: 6, tickets: 3, label: '3 ⚡'),
  DailyReward(day: 7, diamonds: 30, label: '30 💎'),
];

class DailyRewardService extends StateNotifier<DailyRewardState> {
  static const _boxName = 'app_settings';
  static const _key = 'daily_reward';

  final Ref _ref;
  List<DailyRewardConfig> get _rewards =>
      _ref.read(remoteConfigProvider).daily.isNotEmpty
          ? _ref.read(remoteConfigProvider).daily
          : _defaultDailyRewards;

  DailyRewardService(this._ref) : super(const DailyRewardState()) {
    _load();
  }

  /// Нужно ли показать popup ежедневной награды
  bool get shouldShowReward => !state.claimedToday;

  /// Публичный каталог наград (для диалога — единый источник, чтобы показ
  /// совпадал с начислением).
  List<DailyRewardConfig> get rewards => _rewards;

  /// Номер дня серии, который будет засчитан при следующем claim (1..N).
  int get todayDayNumber => _nextStreak();

  /// Вычислить, какой день серии будет при следующем получении награды.
  /// Одна логика и для показа, и для начисления — иначе показанная и
  /// выданная награды расходятся.
  int _nextStreak() {
    final today = DateTime.now();
    final lastClaim = state.lastClaimDate;
    if (lastClaim == null) return 1;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final isConsecutive = lastClaim.year == yesterday.year &&
        lastClaim.month == yesterday.month &&
        lastClaim.day == yesterday.day;
    var s = isConsecutive ? state.currentStreak + 1 : 1;
    if (s > _rewards.length) s = 1;
    return s;
  }

  /// Текущая награда — по дню, который РЕАЛЬНО будет засчитан (а не по
  /// старому стрику).
  DailyReward get todayReward {
    final rewards = _rewards;
    final dayIndex = (_nextStreak() - 1) % rewards.length;
    final cfg = rewards[dayIndex];
    return DailyReward(
      day: cfg.day,
      diamonds: cfg.diamonds,
      tickets: cfg.tickets,
      label: cfg.label,
    );
  }

  /// Забрать награду. Возвращает {diamonds, tickets}
  Map<String, int> claimReward() {
    final today = DateTime.now();
    final rewards = _rewards;
    final newStreak = _nextStreak();

    // Награда за НОВЫЙ день серии (тот же расчёт, что и в todayReward).
    final cfg = rewards[(newStreak - 1) % rewards.length];

    state = DailyRewardState(
      currentStreak: newStreak,
      lastClaimDate: today,
      claimedToday: true,
    );
    _save();

    return {
      if (cfg.diamonds > 0) 'diamonds': cfg.diamonds,
      if (cfg.tickets > 0) 'tickets': cfg.tickets,
    };
  }

  Future<void> _save() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void _load() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_key);
      if (data != null) {
        state =
            DailyRewardState.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }
}

const _defaultDailyRewards = [
  DailyRewardConfig(day: 1, diamonds: 5, label: '5 💎'),
  DailyRewardConfig(day: 2, tickets: 1, label: '1 ⚡'),
  DailyRewardConfig(day: 3, diamonds: 10, label: '10 💎'),
  DailyRewardConfig(day: 4, tickets: 2, label: '2 ⚡'),
  DailyRewardConfig(day: 5, diamonds: 15, label: '15 💎'),
  DailyRewardConfig(day: 6, tickets: 3, label: '3 ⚡'),
  DailyRewardConfig(day: 7, diamonds: 30, label: '30 💎'),
];
