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

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    this.diamondReward = 5,
  });
}

/// Хардкод-каталог (fallback если remote config пуст)
const _defaultAchievements = <AchievementDef>[
  AchievementDef(
    id: 'first_story',
    title: 'Первая история',
    description: 'Начни свою первую новеллу',
    diamondReward: 10,
  ),
  AchievementDef(
    id: 'first_choice',
    title: 'Первый выбор',
    description: 'Сделай первый выбор в истории',
    diamondReward: 5,
  ),
  AchievementDef(
    id: 'five_chapters',
    title: '5 глав',
    description: 'Прочитай 5 глав',
    diamondReward: 15,
  ),
  AchievementDef(
    id: 'first_love',
    title: 'Первая любовь',
    description: 'Набери 10+ очков отношений с персонажем',
    diamondReward: 10,
  ),
  AchievementDef(
    id: 'completionist',
    title: 'Прохождение',
    description: 'Пройди новеллу до конца',
    diamondReward: 25,
  ),
  AchievementDef(
    id: 'collector',
    title: 'Коллекционер',
    description: 'Разблокируй 3 CG-арта',
    diamondReward: 15,
  ),
  AchievementDef(
    id: 'brave_heart',
    title: 'Храброе сердце',
    description: 'Выбери смелый вариант',
    diamondReward: 5,
  ),
  AchievementDef(
    id: 'mystery_solver',
    title: 'Детектив',
    description: 'Собери 5 улик',
    diamondReward: 20,
  ),
  AchievementDef(
    id: 'ten_choices',
    title: 'Решительность',
    description: 'Сделай 10 выборов',
    diamondReward: 10,
  ),
  AchievementDef(
    id: 'diamond_spender',
    title: 'Щедрая душа',
    description: 'Потрать 50 алмазов на премиум-выборы',
    diamondReward: 20,
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
      // Достижения на основе переменных проверяются отдельно
      _ => false,
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
