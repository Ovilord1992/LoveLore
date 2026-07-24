import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Провайдер профиля пользователя
final userProfileProvider =
    StateNotifierProvider<UserProfileService, UserProfile>((ref) {
  return UserProfileService();
});

/// Профиль пользователя
class UserProfile {
  final String displayName;
  final int avatarIndex;
  final int totalNovelsStarted;
  final int totalNovelsCompleted;
  final int totalChoicesMade;
  final int totalChaptersRead;
  final Set<String> unlockedCGs; // разблокированные CG-арты
  final Set<String> achievements; // полученные достижения
  final Set<String> unlockedEndings; // концовки, формат "<novelId>:<endingId>"
  final int totalDiamondsSpent;
  final int adsWatched; // всего просмотрено rewarded-рекламы
  final int premiumChoicesMade; // всего сделано платных выборов
  final DateTime createdAt;

  const UserProfile({
    this.displayName = 'Читатель',
    this.avatarIndex = 0,
    this.totalNovelsStarted = 0,
    this.totalNovelsCompleted = 0,
    this.totalChoicesMade = 0,
    this.totalChaptersRead = 0,
    this.unlockedCGs = const {},
    this.achievements = const {},
    this.unlockedEndings = const {},
    this.totalDiamondsSpent = 0,
    this.adsWatched = 0,
    this.premiumChoicesMade = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? const _DefaultDateTime();

  UserProfile copyWith({
    String? displayName,
    int? avatarIndex,
    int? totalNovelsStarted,
    int? totalNovelsCompleted,
    int? totalChoicesMade,
    int? totalChaptersRead,
    Set<String>? unlockedCGs,
    Set<String>? achievements,
    Set<String>? unlockedEndings,
    int? totalDiamondsSpent,
    int? adsWatched,
    int? premiumChoicesMade,
  }) =>
      UserProfile(
        displayName: displayName ?? this.displayName,
        avatarIndex: avatarIndex ?? this.avatarIndex,
        totalNovelsStarted: totalNovelsStarted ?? this.totalNovelsStarted,
        totalNovelsCompleted:
            totalNovelsCompleted ?? this.totalNovelsCompleted,
        totalChoicesMade: totalChoicesMade ?? this.totalChoicesMade,
        totalChaptersRead: totalChaptersRead ?? this.totalChaptersRead,
        unlockedCGs: unlockedCGs ?? this.unlockedCGs,
        achievements: achievements ?? this.achievements,
        unlockedEndings: unlockedEndings ?? this.unlockedEndings,
        totalDiamondsSpent: totalDiamondsSpent ?? this.totalDiamondsSpent,
        adsWatched: adsWatched ?? this.adsWatched,
        premiumChoicesMade: premiumChoicesMade ?? this.premiumChoicesMade,
        createdAt: createdAt,
      );

  /// Ключ концовки в [unlockedEndings]
  static String endingKey(String novelId, String endingId) =>
      '$novelId:$endingId';

  /// Концовки, открытые в конкретной новелле (набор endingId)
  Set<String> endingsForNovel(String novelId) {
    final prefix = '$novelId:';
    return unlockedEndings
        .where((e) => e.startsWith(prefix))
        .map((e) => e.substring(prefix.length))
        .toSet();
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'avatarIndex': avatarIndex,
        'totalNovelsStarted': totalNovelsStarted,
        'totalNovelsCompleted': totalNovelsCompleted,
        'totalChoicesMade': totalChoicesMade,
        'totalChaptersRead': totalChaptersRead,
        'unlockedCGs': unlockedCGs.toList(),
        'achievements': achievements.toList(),
        'unlockedEndings': unlockedEndings.toList(),
        'totalDiamondsSpent': totalDiamondsSpent,
        'adsWatched': adsWatched,
        'premiumChoicesMade': premiumChoicesMade,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        displayName: json['displayName'] as String? ?? 'Читатель',
        avatarIndex: json['avatarIndex'] as int? ?? 0,
        totalNovelsStarted: json['totalNovelsStarted'] as int? ?? 0,
        totalNovelsCompleted: json['totalNovelsCompleted'] as int? ?? 0,
        totalChoicesMade: json['totalChoicesMade'] as int? ?? 0,
        totalChaptersRead: json['totalChaptersRead'] as int? ?? 0,
        unlockedCGs: Set<String>.from(json['unlockedCGs'] as List? ?? []),
        achievements: Set<String>.from(json['achievements'] as List? ?? []),
        unlockedEndings:
            Set<String>.from(json['unlockedEndings'] as List? ?? []),
        totalDiamondsSpent: json['totalDiamondsSpent'] as int? ?? 0,
        adsWatched: json['adsWatched'] as int? ?? 0,
        premiumChoicesMade: json['premiumChoicesMade'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

/// Хак для default DateTime в const конструкторе
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  DateTime get _now => DateTime.now();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Function.apply(
        (_now as dynamic),
        invocation.positionalArguments,
      );

  @override
  String toIso8601String() => _now.toIso8601String();

  @override
  String toString() => _now.toString();
}

/// Сервис управления профилем пользователя
class UserProfileService extends StateNotifier<UserProfile> {
  static const _boxName = 'user_profile';
  static const _key = 'profile';

  UserProfileService() : super(const UserProfile()) {
    _loadSync();
  }

  void setDisplayName(String name) {
    state = state.copyWith(displayName: name);
    _save();
  }

  void setAvatar(int index) {
    state = state.copyWith(avatarIndex: index);
    _save();
  }

  void incrementNovelsStarted() {
    state =
        state.copyWith(totalNovelsStarted: state.totalNovelsStarted + 1);
    _save();
  }

  void incrementNovelsCompleted() {
    state =
        state.copyWith(totalNovelsCompleted: state.totalNovelsCompleted + 1);
    _save();
  }

  void incrementChoicesMade() {
    state = state.copyWith(totalChoicesMade: state.totalChoicesMade + 1);
    _save();
  }

  void incrementChaptersRead() {
    state = state.copyWith(totalChaptersRead: state.totalChaptersRead + 1);
    _save();
  }

  /// Разблокировать CG-арт
  void unlockCG(String cgId) {
    final cgs = Set<String>.from(state.unlockedCGs)..add(cgId);
    state = state.copyWith(unlockedCGs: cgs);
    _save();
  }

  void incrementDiamondsSpent(int amount) {
    state = state.copyWith(totalDiamondsSpent: state.totalDiamondsSpent + amount);
    _save();
  }

  void incrementAdsWatched() {
    state = state.copyWith(adsWatched: state.adsWatched + 1);
    _save();
  }

  void incrementPremiumChoices() {
    state = state.copyWith(premiumChoicesMade: state.premiumChoicesMade + 1);
    _save();
  }

  /// Разблокировать концовку. Ключ — `<novelId>:<endingId>`.
  /// Возвращает true, если концовка новая.
  bool unlockEnding(String novelId, String endingId) {
    final key = UserProfile.endingKey(novelId, endingId);
    if (state.unlockedEndings.contains(key)) return false;
    final endings = Set<String>.from(state.unlockedEndings)..add(key);
    state = state.copyWith(unlockedEndings: endings);
    _save();
    return true;
  }

  /// Выдать достижение
  bool grantAchievement(String achievementId) {
    if (state.achievements.contains(achievementId)) return false;
    final achievements = Set<String>.from(state.achievements)
      ..add(achievementId);
    state = state.copyWith(achievements: achievements);
    _save();
    return true;
  }

  /// Полный сброс профиля (смена аккаунта на устройстве).
  void reset() {
    state = const UserProfile();
    _save();
  }

  Future<void> _save() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void _loadSync() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_key);
      if (data != null) {
        state =
            UserProfile.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  /// Мерж данных с сервера (берём максимальные значения статистики)
  void mergeFromServer(Map<String, dynamic> serverData) {
    final serverProfile = UserProfile.fromJson(serverData);
    state = state.copyWith(
      displayName: serverProfile.displayName,
      avatarIndex: serverProfile.avatarIndex,
      totalNovelsStarted: state.totalNovelsStarted > serverProfile.totalNovelsStarted
          ? state.totalNovelsStarted
          : serverProfile.totalNovelsStarted,
      totalNovelsCompleted: state.totalNovelsCompleted > serverProfile.totalNovelsCompleted
          ? state.totalNovelsCompleted
          : serverProfile.totalNovelsCompleted,
      totalChoicesMade: state.totalChoicesMade > serverProfile.totalChoicesMade
          ? state.totalChoicesMade
          : serverProfile.totalChoicesMade,
      totalChaptersRead: state.totalChaptersRead > serverProfile.totalChaptersRead
          ? state.totalChaptersRead
          : serverProfile.totalChaptersRead,
      unlockedCGs: state.unlockedCGs.union(serverProfile.unlockedCGs),
      achievements: state.achievements.union(serverProfile.achievements),
      unlockedEndings:
          state.unlockedEndings.union(serverProfile.unlockedEndings),
      totalDiamondsSpent: state.totalDiamondsSpent > serverProfile.totalDiamondsSpent
          ? state.totalDiamondsSpent
          : serverProfile.totalDiamondsSpent,
      adsWatched: state.adsWatched > serverProfile.adsWatched
          ? state.adsWatched
          : serverProfile.adsWatched,
      premiumChoicesMade:
          state.premiumChoicesMade > serverProfile.premiumChoicesMade
              ? state.premiumChoicesMade
              : serverProfile.premiumChoicesMade,
    );
    _save();
  }
}
