import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_profile_service.dart';
import 'currency_service.dart';
import 'remote_config_service.dart';

/// Провайдер сервиса достижений
final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService(ref);
});

/// Определение достижения
class AchievementDef {
  final String id;
  final String title;
  final String description;
  final int diamondReward;
  final String icon;

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    this.diamondReward = 5,
    this.icon = '🏆',
  });
}

/// Хардкод-каталог (fallback если remote config пуст)
/// title и description хранят ключи перевода (ach_*),
/// клиент отображает ref.tr(achievement.title).
const _defaultAchievements = <AchievementDef>[
  AchievementDef(
    id: 'first_story',
    title: 'ach_first_story',
    description: 'ach_first_story_desc',
    diamondReward: 10,
    icon: '📖',
  ),
  AchievementDef(
    id: 'first_choice',
    title: 'ach_first_choice',
    description: 'ach_first_choice_desc',
    diamondReward: 5,
    icon: '🎯',
  ),
  AchievementDef(
    id: 'five_chapters',
    title: 'ach_five_chapters',
    description: 'ach_five_chapters_desc',
    diamondReward: 15,
    icon: '📚',
  ),
  AchievementDef(
    id: 'first_love',
    title: 'ach_first_love',
    description: 'ach_first_love_desc',
    diamondReward: 10,
    icon: '💕',
  ),
  AchievementDef(
    id: 'completionist',
    title: 'ach_completionist',
    description: 'ach_completionist_desc',
    diamondReward: 25,
    icon: '⭐',
  ),
  AchievementDef(
    id: 'collector',
    title: 'ach_collector',
    description: 'ach_collector_desc',
    diamondReward: 15,
    icon: '🖼',
  ),
  AchievementDef(
    id: 'brave_heart',
    title: 'ach_brave_heart',
    description: 'ach_brave_heart_desc',
    diamondReward: 5,
    icon: '🦁',
  ),
  AchievementDef(
    id: 'mystery_solver',
    title: 'ach_mystery_solver',
    description: 'ach_mystery_solver_desc',
    diamondReward: 20,
    icon: '🔍',
  ),
  AchievementDef(
    id: 'ten_choices',
    title: 'ach_ten_choices',
    description: 'ach_ten_choices_desc',
    diamondReward: 10,
    icon: '🎲',
  ),
  AchievementDef(
    id: 'diamond_spender',
    title: 'ach_diamond_spender',
    description: 'ach_diamond_spender_desc',
    diamondReward: 20,
    icon: '💎',
  ),
];

/// Сервис проверки и выдачи достижений
class AchievementService {
  final Ref _ref;

  AchievementService(this._ref);

  /// Получить актуальный каталог достижений (remote config → fallback)
  List<AchievementDef> get allAchievements {
    final remote = _ref.read(remoteConfigProvider).achievements;
    if (remote.isNotEmpty) {
      return remote
          .map((a) => AchievementDef(
                id: a.id,
                title: a.title,
                description: a.description,
                diamondReward: a.diamondReward,
              ))
          .toList();
    }
    return _defaultAchievements;
  }

  /// Проверить все условия достижений и выдать заслуженные
  /// Возвращает список только что разблокированных достижений
  List<AchievementDef> checkAndGrant() {
    final profile = _ref.read(userProfileProvider);
    final profileNotifier = _ref.read(userProfileProvider.notifier);
    final currencyNotifier = _ref.read(currencyServiceProvider.notifier);

    final unlocked = <AchievementDef>[];

    for (final achievement in allAchievements) {
      if (profile.achievements.contains(achievement.id)) continue;

      if (_meetsCondition(achievement.id, profile)) {
        final isNew = profileNotifier.grantAchievement(achievement.id);
        if (isNew) {
          currencyNotifier.addDiamonds(achievement.diamondReward);
          unlocked.add(achievement);
        }
      }
    }

    return unlocked;
  }

  bool _meetsCondition(String id, UserProfile profile) {
    return switch (id) {
      'first_story' => profile.totalNovelsStarted >= 1,
      'first_choice' => profile.totalChoicesMade >= 1,
      'five_chapters' => profile.totalChaptersRead >= 5,
      'completionist' => profile.totalNovelsCompleted >= 1,
      'ten_choices' => profile.totalChoicesMade >= 10,
      'collector' => profile.unlockedCGs.length >= 3,
      'diamond_spender' => profile.totalDiamondsSpent >= 100,
      // Достижения на основе переменных проверяются отдельно
      _ => false,
    };
  }

  /// Get progress (current / required) for an achievement
  ({int current, int required}) getProgress(String id) {
    final profile = _ref.read(userProfileProvider);
    return switch (id) {
      'first_story' => (current: profile.totalNovelsStarted.clamp(0, 1), required: 1),
      'first_choice' => (current: profile.totalChoicesMade.clamp(0, 1), required: 1),
      'five_chapters' => (current: profile.totalChaptersRead.clamp(0, 5), required: 5),
      'completionist' => (current: profile.totalNovelsCompleted.clamp(0, 1), required: 1),
      'ten_choices' => (current: profile.totalChoicesMade.clamp(0, 10), required: 10),
      'collector' => (current: profile.unlockedCGs.length.clamp(0, 3), required: 3),
      'diamond_spender' => (current: profile.totalDiamondsSpent.clamp(0, 100), required: 100),
      'first_love' => (current: 0, required: 1), // variable-based, checked separately
      'brave_heart' => (current: 0, required: 1),
      'mystery_solver' => (current: 0, required: 1),
      _ => (current: 0, required: 1),
    };
  }

  /// Проверить достижения на основе переменных игры
  List<AchievementDef> checkVariableAchievements(
      Map<String, dynamic> variables) {
    final profile = _ref.read(userProfileProvider);
    final profileNotifier = _ref.read(userProfileProvider.notifier);
    final currencyNotifier = _ref.read(currencyServiceProvider.notifier);
    final unlocked = <AchievementDef>[];

    // Первая любовь — любой _love >= 10
    if (!profile.achievements.contains('first_love')) {
      final hasLove = variables.entries.any((e) =>
          e.key.contains('_love') && e.value is num && (e.value as num) >= 10);
      if (hasLove) {
        profileNotifier.grantAchievement('first_love');
        currencyNotifier.addDiamonds(10);
        unlocked.add(allAchievements.firstWhere((a) => a.id == 'first_love'));
      }
    }

    // Храброе сердце
    if (!profile.achievements.contains('brave_heart')) {
      if (variables['chose_brave'] == true) {
        profileNotifier.grantAchievement('brave_heart');
        currencyNotifier.addDiamonds(5);
        unlocked
            .add(allAchievements.firstWhere((a) => a.id == 'brave_heart'));
      }
    }

    // Детектив — mystery_clues >= 5
    if (!profile.achievements.contains('mystery_solver')) {
      final clues = variables['mystery_clues'];
      if (clues is num && clues >= 5) {
        profileNotifier.grantAchievement('mystery_solver');
        currencyNotifier.addDiamonds(20);
        unlocked.add(
            allAchievements.firstWhere((a) => a.id == 'mystery_solver'));
      }
    }

    return unlocked;
  }

  /// Получить определение достижения по id
  AchievementDef? getAchievement(String id) {
    try {
      return allAchievements.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
