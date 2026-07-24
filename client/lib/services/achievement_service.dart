import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novel.dart';
import 'user_profile_service.dart';
import 'currency_service.dart';
import 'daily_reward_service.dart';
import 'remote_config_service.dart';
import 'vip_service.dart';
import 'wardrobe_service.dart';

/// Провайдер сервиса достижений
final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService(ref);
});

enum AchievementRarity { common, rare, epic, legendary }

enum AchievementCategory {
  story,
  chapters,
  relationships,
  collection,
  economy,
  daily,
  social,
  completionist,
  secret,
}

/// Определение достижения
class AchievementDef {
  final String id;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final IconData icon;
  final int diamondReward;
  final bool hidden;
  final String trigger;
  final int targetValue;

  const AchievementDef({
    required this.id,
    this.category = AchievementCategory.story,
    this.rarity = AchievementRarity.common,
    this.icon = Icons.emoji_events,
    this.diamondReward = 5,
    this.hidden = false,
    this.trigger = '',
    this.targetValue = 1,
  });

  /// Locale key for the title: ach_{id}_title
  String get titleKey => 'ach_${id}_title';

  /// Locale key for the description: ach_{id}_desc
  String get descKey => 'ach_${id}_desc';
}


/// Icon lookup by string name (for remote config mapping)
const _iconMap = <String, IconData>{
  'all_inclusive': Icons.all_inclusive,
  'auto_stories': Icons.auto_stories,
  'bedtime': Icons.bedtime,
  'book': Icons.book,
  'bookmark': Icons.bookmark,
  'calendar_today': Icons.calendar_today,
  'campaign': Icons.campaign,
  'casino': Icons.casino,
  'celebration': Icons.celebration,
  'chat': Icons.chat,
  'checkroom': Icons.checkroom,
  'chrome_reader_mode': Icons.chrome_reader_mode,
  'code': Icons.code,
  'collections': Icons.collections,
  'diamond': Icons.diamond,
  'emoji_events': Icons.emoji_events,
  'explore': Icons.explore,
  'favorite': Icons.favorite,
  'favorite_border': Icons.favorite_border,
  'feedback': Icons.feedback,
  'flag': Icons.flag,
  'flash_on': Icons.flash_on,
  'group': Icons.group,
  'heart_broken': Icons.heart_broken,
  'image': Icons.image,
  'library_books': Icons.library_books,
  'local_library': Icons.local_library,
  'lock_open': Icons.lock_open,
  'login': Icons.login,
  'loyalty': Icons.loyalty,
  'menu_book': Icons.menu_book,
  'military_tech': Icons.military_tech,
  'monetization_on': Icons.monetization_on,
  'nights_stay': Icons.nights_stay,
  'payment': Icons.payment,
  'people': Icons.people,
  'person_add': Icons.person_add,
  'photo_library': Icons.photo_library,
  'rate_review': Icons.rate_review,
  'replay': Icons.replay,
  'route': Icons.route,
  'search': Icons.search,
  'share': Icons.share,
  'shield': Icons.shield,
  'shopping_cart': Icons.shopping_cart,
  'speed': Icons.speed,
  'star': Icons.star,
  'timer': Icons.timer,
  'touch_app': Icons.touch_app,
  'videogame_asset': Icons.videogame_asset,
  'visibility_off': Icons.visibility_off,
  'wb_sunny': Icons.wb_sunny,
  'workspace_premium': Icons.workspace_premium,
};

/// Хардкод-каталог (fallback если remote config пуст)
const _defaultAchievements = <AchievementDef>[
  // ── Story Progression (13) ──
  AchievementDef(
    id: 'first_story',
    category: AchievementCategory.story,
    rarity: AchievementRarity.common,
    icon: Icons.auto_stories,
    diamondReward: 10,
    trigger: 'novels_started',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'stories_3',
    category: AchievementCategory.story,
    rarity: AchievementRarity.common,
    icon: Icons.auto_stories,
    diamondReward: 10,
    trigger: 'novels_started',
    targetValue: 3,
  ),
  AchievementDef(
    id: 'stories_5',
    category: AchievementCategory.story,
    rarity: AchievementRarity.common,
    icon: Icons.library_books,
    diamondReward: 10,
    trigger: 'novels_started',
    targetValue: 5,
  ),
  AchievementDef(
    id: 'stories_10',
    category: AchievementCategory.story,
    rarity: AchievementRarity.common,
    icon: Icons.library_books,
    diamondReward: 10,
    trigger: 'novels_started',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'stories_25',
    category: AchievementCategory.story,
    rarity: AchievementRarity.rare,
    icon: Icons.library_books,
    diamondReward: 20,
    trigger: 'novels_started',
    targetValue: 25,
  ),
  AchievementDef(
    id: 'stories_50',
    category: AchievementCategory.story,
    rarity: AchievementRarity.epic,
    icon: Icons.library_books,
    diamondReward: 40,
    trigger: 'novels_started',
    targetValue: 50,
  ),
  AchievementDef(
    id: 'novel_finished',
    category: AchievementCategory.story,
    rarity: AchievementRarity.common,
    icon: Icons.bookmark,
    diamondReward: 10,
    trigger: 'novels_completed',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'novels_3',
    category: AchievementCategory.story,
    rarity: AchievementRarity.rare,
    icon: Icons.bookmark,
    diamondReward: 20,
    trigger: 'novels_completed',
    targetValue: 3,
  ),
  AchievementDef(
    id: 'novels_5',
    category: AchievementCategory.story,
    rarity: AchievementRarity.rare,
    icon: Icons.bookmark,
    diamondReward: 25,
    trigger: 'novels_completed',
    targetValue: 5,
  ),
  AchievementDef(
    id: 'novels_10',
    category: AchievementCategory.story,
    rarity: AchievementRarity.epic,
    icon: Icons.star,
    diamondReward: 45,
    trigger: 'novels_completed',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'novels_all',
    category: AchievementCategory.story,
    rarity: AchievementRarity.legendary,
    icon: Icons.workspace_premium,
    diamondReward: 100,
    trigger: 'novels_completed',
    targetValue: 20,
  ),
  AchievementDef(
    id: 'first_chapter',
    category: AchievementCategory.story,
    rarity: AchievementRarity.common,
    icon: Icons.book,
    diamondReward: 5,
    trigger: 'chapters_read',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'prologue_complete',
    category: AchievementCategory.story,
    rarity: AchievementRarity.common,
    icon: Icons.chrome_reader_mode,
    diamondReward: 5,
    trigger: 'chapters_read',
    targetValue: 3,
  ),
  // ── Chapter Milestones (12) ──
  AchievementDef(
    id: 'five_chapters',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.common,
    icon: Icons.menu_book,
    diamondReward: 10,
    trigger: 'chapters_read',
    targetValue: 5,
  ),
  AchievementDef(
    id: 'chapters_10',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.common,
    icon: Icons.menu_book,
    diamondReward: 10,
    trigger: 'chapters_read',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'chapters_25',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.common,
    icon: Icons.menu_book,
    diamondReward: 10,
    trigger: 'chapters_read',
    targetValue: 25,
  ),
  AchievementDef(
    id: 'chapters_50',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.rare,
    icon: Icons.local_library,
    diamondReward: 15,
    trigger: 'chapters_read',
    targetValue: 50,
  ),
  AchievementDef(
    id: 'chapters_100',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.rare,
    icon: Icons.local_library,
    diamondReward: 25,
    trigger: 'chapters_read',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'chapters_200',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.epic,
    icon: Icons.local_library,
    diamondReward: 35,
    trigger: 'chapters_read',
    targetValue: 200,
  ),
  AchievementDef(
    id: 'chapters_500',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.legendary,
    icon: Icons.military_tech,
    diamondReward: 75,
    trigger: 'chapters_read',
    targetValue: 500,
  ),
  AchievementDef(
    id: 'speed_reader',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.common,
    icon: Icons.speed,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'marathon_reader',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.common,
    icon: Icons.timer,
    diamondReward: 10,
    trigger: 'chapters_read',
    targetValue: 30,
  ),
  AchievementDef(
    id: 'night_owl',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.common,
    icon: Icons.bedtime,
    diamondReward: 10,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'bookworm',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.rare,
    icon: Icons.local_library,
    diamondReward: 15,
    trigger: 'chapters_read',
    targetValue: 75,
  ),
  AchievementDef(
    id: 'chapter_marathon',
    category: AchievementCategory.chapters,
    rarity: AchievementRarity.epic,
    icon: Icons.menu_book,
    diamondReward: 35,
    trigger: 'chapters_read',
    targetValue: 150,
  ),
  // ── Relationship Milestones (12) ──
  AchievementDef(
    id: 'first_love',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.common,
    icon: Icons.favorite,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'relationship_25',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.rare,
    icon: Icons.favorite,
    diamondReward: 15,
    trigger: 'variable_check',
    targetValue: 25,
  ),
  AchievementDef(
    id: 'relationship_50',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.rare,
    icon: Icons.favorite,
    diamondReward: 25,
    trigger: 'variable_check',
    targetValue: 50,
  ),
  AchievementDef(
    id: 'relationship_100',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.epic,
    icon: Icons.favorite,
    diamondReward: 40,
    trigger: 'variable_check',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'relationship_max',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.legendary,
    icon: Icons.favorite_border,
    diamondReward: 75,
    trigger: 'variable_check',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'heartbreaker',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.common,
    icon: Icons.heart_broken,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'friend_zone',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.common,
    icon: Icons.people,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'soulmate',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.legendary,
    icon: Icons.loyalty,
    diamondReward: 75,
    trigger: 'variable_check',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'love_triangle',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.epic,
    icon: Icons.favorite,
    diamondReward: 35,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'all_friends',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.epic,
    icon: Icons.people,
    diamondReward: 40,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'jealousy',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.common,
    icon: Icons.heart_broken,
    diamondReward: 5,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'confession',
    category: AchievementCategory.relationships,
    rarity: AchievementRarity.common,
    icon: Icons.chat,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  // ── CG Collection (8) ──
  AchievementDef(
    id: 'first_cg',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.common,
    icon: Icons.image,
    diamondReward: 5,
    trigger: 'cg_unlocked',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'collector',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.common,
    icon: Icons.collections,
    diamondReward: 10,
    trigger: 'cg_unlocked',
    targetValue: 3,
  ),
  AchievementDef(
    id: 'cg_10',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.rare,
    icon: Icons.photo_library,
    diamondReward: 20,
    trigger: 'cg_unlocked',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'cg_25',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.rare,
    icon: Icons.photo_library,
    diamondReward: 25,
    trigger: 'cg_unlocked',
    targetValue: 25,
  ),
  AchievementDef(
    id: 'cg_50',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.epic,
    icon: Icons.photo_library,
    diamondReward: 40,
    trigger: 'cg_unlocked',
    targetValue: 50,
  ),
  AchievementDef(
    id: 'cg_all',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.legendary,
    icon: Icons.all_inclusive,
    diamondReward: 100,
    trigger: 'cg_unlocked',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'rare_cg',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.epic,
    icon: Icons.visibility_off,
    diamondReward: 30,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'gallery_complete',
    category: AchievementCategory.collection,
    rarity: AchievementRarity.legendary,
    icon: Icons.collections,
    diamondReward: 75,
    trigger: 'cg_unlocked',
    targetValue: 75,
  ),
  // ── Premium / Economy (12) ──
  AchievementDef(
    id: 'first_choice',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.common,
    icon: Icons.touch_app,
    diamondReward: 5,
    trigger: 'choices_made',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'ten_choices',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.common,
    icon: Icons.casino,
    diamondReward: 10,
    trigger: 'choices_made',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'choices_25',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.common,
    icon: Icons.touch_app,
    diamondReward: 10,
    trigger: 'choices_made',
    targetValue: 25,
  ),
  AchievementDef(
    id: 'choices_50',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.common,
    icon: Icons.touch_app,
    diamondReward: 10,
    trigger: 'choices_made',
    targetValue: 50,
  ),
  AchievementDef(
    id: 'choices_100',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.rare,
    icon: Icons.touch_app,
    diamondReward: 15,
    trigger: 'choices_made',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'diamond_spender',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.rare,
    icon: Icons.diamond,
    diamondReward: 20,
    trigger: 'diamonds_spent',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'diamonds_500',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.rare,
    icon: Icons.diamond,
    diamondReward: 25,
    trigger: 'diamonds_spent',
    targetValue: 500,
  ),
  AchievementDef(
    id: 'diamonds_1000',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.epic,
    icon: Icons.diamond,
    diamondReward: 40,
    trigger: 'diamonds_spent',
    targetValue: 1000,
  ),
  AchievementDef(
    id: 'diamonds_5000',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.legendary,
    icon: Icons.diamond,
    diamondReward: 100,
    trigger: 'diamonds_spent',
    targetValue: 5000,
  ),
  AchievementDef(
    id: 'first_purchase',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.common,
    icon: Icons.shopping_cart,
    diamondReward: 10,
    trigger: 'premium_choices',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'big_spender',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.epic,
    icon: Icons.monetization_on,
    diamondReward: 50,
    trigger: 'diamonds_spent',
    targetValue: 2500,
  ),
  AchievementDef(
    id: 'premium_collector',
    category: AchievementCategory.economy,
    rarity: AchievementRarity.epic,
    icon: Icons.payment,
    diamondReward: 40,
    trigger: 'premium_choices',
    targetValue: 25,
  ),
  // ── Daily / Login (10) ──
  AchievementDef(
    id: 'daily_reward',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.common,
    icon: Icons.calendar_today,
    diamondReward: 5,
    trigger: 'login_streak',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'login_3',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.common,
    icon: Icons.login,
    diamondReward: 5,
    trigger: 'login_streak',
    targetValue: 3,
  ),
  AchievementDef(
    id: 'login_7',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.common,
    icon: Icons.login,
    diamondReward: 10,
    trigger: 'login_streak',
    targetValue: 7,
  ),
  AchievementDef(
    id: 'login_14',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.common,
    icon: Icons.calendar_today,
    diamondReward: 10,
    trigger: 'login_streak',
    targetValue: 14,
  ),
  AchievementDef(
    id: 'login_30',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.rare,
    icon: Icons.calendar_today,
    diamondReward: 20,
    trigger: 'login_streak',
    targetValue: 30,
  ),
  AchievementDef(
    id: 'login_60',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.rare,
    icon: Icons.calendar_today,
    diamondReward: 25,
    trigger: 'login_streak',
    targetValue: 60,
  ),
  AchievementDef(
    id: 'login_90',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.epic,
    icon: Icons.calendar_today,
    diamondReward: 35,
    trigger: 'login_streak',
    targetValue: 90,
  ),
  AchievementDef(
    id: 'login_180',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.epic,
    icon: Icons.star,
    diamondReward: 45,
    trigger: 'login_streak',
    targetValue: 180,
  ),
  AchievementDef(
    id: 'login_365',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.legendary,
    icon: Icons.emoji_events,
    diamondReward: 100,
    trigger: 'login_streak',
    targetValue: 365,
  ),
  AchievementDef(
    id: 'comeback',
    category: AchievementCategory.daily,
    rarity: AchievementRarity.common,
    icon: Icons.replay,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  // ── Social (6) ──
  AchievementDef(
    id: 'share_first',
    category: AchievementCategory.social,
    rarity: AchievementRarity.common,
    icon: Icons.share,
    diamondReward: 5,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'rate_app',
    category: AchievementCategory.social,
    rarity: AchievementRarity.common,
    icon: Icons.rate_review,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'invite_friend',
    category: AchievementCategory.social,
    rarity: AchievementRarity.common,
    icon: Icons.person_add,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'community_member',
    category: AchievementCategory.social,
    rarity: AchievementRarity.rare,
    icon: Icons.group,
    diamondReward: 20,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'feedback_given',
    category: AchievementCategory.social,
    rarity: AchievementRarity.common,
    icon: Icons.feedback,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'influencer',
    category: AchievementCategory.social,
    rarity: AchievementRarity.epic,
    icon: Icons.campaign,
    diamondReward: 40,
    trigger: 'variable_check',
    targetValue: 10,
  ),
  // ── Completionist (11) ──
  AchievementDef(
    id: 'completionist',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.rare,
    icon: Icons.star,
    diamondReward: 15,
    trigger: 'novels_completed',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'all_routes',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.epic,
    icon: Icons.route,
    diamondReward: 40,
    trigger: 'routes_completed',
    targetValue: 5,
  ),
  AchievementDef(
    id: 'all_endings',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.epic,
    icon: Icons.flag,
    diamondReward: 45,
    trigger: 'routes_completed',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'perfect_run',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.legendary,
    icon: Icons.military_tech,
    diamondReward: 75,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'explorer',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.rare,
    icon: Icons.explore,
    diamondReward: 20,
    trigger: 'routes_completed',
    targetValue: 3,
  ),
  AchievementDef(
    id: 'replay_master',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.rare,
    icon: Icons.replay,
    diamondReward: 20,
    trigger: 'novels_completed',
    targetValue: 3,
  ),
  AchievementDef(
    id: 'dialogue_master',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.common,
    icon: Icons.chat,
    diamondReward: 10,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'fashion_expert',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.rare,
    icon: Icons.checkroom,
    diamondReward: 25,
    trigger: 'wardrobe_items',
    targetValue: 10,
  ),
  AchievementDef(
    id: 'collector_supreme',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.legendary,
    icon: Icons.emoji_events,
    diamondReward: 75,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'achievement_hunter_50',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.rare,
    icon: Icons.emoji_events,
    diamondReward: 25,
    trigger: 'achievements_unlocked',
    targetValue: 50,
  ),
  AchievementDef(
    id: 'achievement_hunter_100',
    category: AchievementCategory.completionist,
    rarity: AchievementRarity.epic,
    icon: Icons.military_tech,
    diamondReward: 50,
    trigger: 'achievements_unlocked',
    targetValue: 100,
  ),
  // ── Secret / Hidden (18) ──
  AchievementDef(
    id: 'brave_heart',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.common,
    icon: Icons.shield,
    diamondReward: 5,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'mystery_solver',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.epic,
    icon: Icons.search,
    diamondReward: 30,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 5,
  ),
  AchievementDef(
    id: 'easter_egg',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.common,
    icon: Icons.celebration,
    diamondReward: 10,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'developer_mode',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.legendary,
    icon: Icons.code,
    diamondReward: 100,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'speed_demon',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.common,
    icon: Icons.flash_on,
    diamondReward: 10,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'patience_master',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.common,
    icon: Icons.timer,
    diamondReward: 10,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'night_reader',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.common,
    icon: Icons.nights_stay,
    diamondReward: 10,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'early_bird',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.common,
    icon: Icons.wb_sunny,
    diamondReward: 10,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'holiday_special',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.common,
    icon: Icons.celebration,
    diamondReward: 10,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'secret_ending',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.epic,
    icon: Icons.lock_open,
    diamondReward: 35,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'hidden_route',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.epic,
    icon: Icons.route,
    diamondReward: 35,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'perfect_choices',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.epic,
    icon: Icons.star,
    diamondReward: 40,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'no_premium_clear',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.legendary,
    icon: Icons.military_tech,
    diamondReward: 75,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'max_all_relationships',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.legendary,
    icon: Icons.all_inclusive,
    diamondReward: 75,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'all_cg_one_novel',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.epic,
    icon: Icons.collections,
    diamondReward: 40,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'speedrun',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.legendary,
    icon: Icons.speed,
    diamondReward: 75,
    hidden: true,
    trigger: 'variable_check',
    targetValue: 1,
  ),
  AchievementDef(
    id: 'ads_100',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.rare,
    icon: Icons.videogame_asset,
    diamondReward: 25,
    hidden: true,
    trigger: 'ads_watched',
    targetValue: 100,
  ),
  AchievementDef(
    id: 'vip_subscriber',
    category: AchievementCategory.secret,
    rarity: AchievementRarity.legendary,
    icon: Icons.workspace_premium,
    diamondReward: 50,
    hidden: true,
    trigger: 'vip_active',
    targetValue: 1,
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
      return remote.map((a) {
        final fallback = _defaultAchievements.cast<AchievementDef?>().firstWhere(
          (d) => d!.id == a.id,
          orElse: () => null,
        );
        return AchievementDef(
          id: a.id,
          category: fallback?.category ?? AchievementCategory.story,
          rarity: fallback?.rarity ?? AchievementRarity.common,
          icon: _iconMap[a.icon] ?? fallback?.icon ?? Icons.emoji_events,
          diamondReward: a.diamondReward,
          hidden: fallback?.hidden ?? false,
          trigger: fallback?.trigger ?? '',
          targetValue: fallback?.targetValue ?? 1,
        );
      }).toList();
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
          currencyNotifier.addDiamonds(
            achievement.diamondReward,
            reason: 'achievement',
            refId: achievement.id,
          );
          unlocked.add(achievement);
        }
      }
    }

    return unlocked;
  }

  /// Триггеры концовок (v2). Вызывается движком при достижении концовки:
  /// - `secret_ending` — открыта скрытая (`hidden: true` в meta.endings);
  /// - `all_endings` — открыты ВСЕ концовки новеллы из meta.endings;
  /// - счётчиковые (`routes_completed` → число открытых концовок) добираются
  ///   обычным [checkAndGrant].
  List<AchievementDef> onEndingReached(
    String novelId,
    String endingId,
    List<NovelEnding> metaEndings,
  ) {
    final unlocked = <AchievementDef>[];
    final profile = _ref.read(userProfileProvider);

    final reachedMeta =
        metaEndings.where((e) => e.id == endingId).firstOrNull;
    if (reachedMeta?.hidden == true) {
      final def = _grantById('secret_ending');
      if (def != null) unlocked.add(def);
    }

    if (metaEndings.isNotEmpty) {
      final unlockedForNovel = profile.endingsForNovel(novelId);
      final allUnlocked =
          metaEndings.every((e) => unlockedForNovel.contains(e.id));
      if (allUnlocked) {
        final def = _grantById('all_endings');
        if (def != null) unlocked.add(def);
      }
    }

    // Счётчиковые триггеры (первая концовка → explorer/all_routes и т.д.)
    unlocked.addAll(checkAndGrant());
    return unlocked;
  }

  /// Выдать конкретное достижение по id (если ещё не выдано)
  AchievementDef? _grantById(String id) {
    final profile = _ref.read(userProfileProvider);
    if (profile.achievements.contains(id)) return null;
    final def = getAchievement(id);
    if (def == null) return null;
    final isNew =
        _ref.read(userProfileProvider.notifier).grantAchievement(id);
    if (!isNew) return null;
    _ref.read(currencyServiceProvider.notifier).addDiamonds(
          def.diamondReward,
          reason: 'achievement',
          refId: def.id,
        );
    return def;
  }


  bool _meetsCondition(String id, UserProfile profile) {
    final def = allAchievements.cast<AchievementDef?>().firstWhere(
      (a) => a!.id == id,
      orElse: () => null,
    );
    if (def == null) return false;
    return _triggerValue(def.trigger, profile) >= def.targetValue;
  }

  /// Resolve the current numeric value for a given trigger type.
  int _triggerValue(String trigger, UserProfile profile) {
    return switch (trigger) {
      'novels_started' => profile.totalNovelsStarted,
      'novels_completed' => profile.totalNovelsCompleted,
      'chapters_read' => profile.totalChaptersRead,
      'choices_made' => profile.totalChoicesMade,
      'premium_choices' => profile.premiumChoicesMade,
      'cg_unlocked' => profile.unlockedCGs.length,
      'diamonds_spent' => profile.totalDiamondsSpent,
      'login_streak' => _ref.read(dailyRewardProvider).currentStreak,
      'achievements_unlocked' => profile.achievements.length,
      // v2: маршрут = открытая концовка (unlockedEndings из движка).
      'routes_completed' => profile.unlockedEndings.length,
      'wardrobe_items' =>
        _ref.read(wardrobeServiceProvider).unlockedOutfitIds.length,
      'ads_watched' => profile.adsWatched,
      'vip_active' => _ref.read(vipServiceProvider).isActive ? 1 : 0,
      'variable_check' => 0, // handled in checkVariableAchievements
      _ => 0,
    };
  }

  /// Get progress (current / required) for an achievement
  ({int current, int required}) getProgress(String id) {
    final profile = _ref.read(userProfileProvider);
    final def = allAchievements.cast<AchievementDef?>().firstWhere(
      (a) => a!.id == id,
      orElse: () => null,
    );
    final target = def?.targetValue ?? 1;
    final trigger = def?.trigger ?? '';
    final current = _triggerValue(trigger, profile).clamp(0, target);
    return (current: current, required: target);
  }

  /// Проверить достижения на основе переменных игры
  List<AchievementDef> checkVariableAchievements(
      Map<String, dynamic> variables) {
    final profile = _ref.read(userProfileProvider);
    final profileNotifier = _ref.read(userProfileProvider.notifier);
    final currencyNotifier = _ref.read(currencyServiceProvider.notifier);
    final unlocked = <AchievementDef>[];

    // Первая любовь — любой _love >= targetValue
    final firstLoveDef = getAchievement('first_love');
    if (firstLoveDef != null && !profile.achievements.contains('first_love')) {
      final hasLove = variables.entries.any((e) =>
          e.key.contains('_love') &&
          e.value is num &&
          (e.value as num) >= firstLoveDef.targetValue);
      if (hasLove) {
        profileNotifier.grantAchievement('first_love');
        currencyNotifier.addDiamonds(firstLoveDef.diamondReward,
            reason: 'achievement', refId: 'first_love');
        unlocked.add(firstLoveDef);
      }
    }

    // Храброе сердце
    final braveHeartDef = getAchievement('brave_heart');
    if (braveHeartDef != null && !profile.achievements.contains('brave_heart')) {
      if (variables['chose_brave'] == true) {
        profileNotifier.grantAchievement('brave_heart');
        currencyNotifier.addDiamonds(braveHeartDef.diamondReward,
            reason: 'achievement', refId: 'brave_heart');
        unlocked.add(braveHeartDef);
      }
    }

    // Детектив — mystery_clues >= targetValue
    final mysterySolverDef = getAchievement('mystery_solver');
    if (mysterySolverDef != null &&
        !profile.achievements.contains('mystery_solver')) {
      final clues = variables['mystery_clues'];
      if (clues is num && clues >= mysterySolverDef.targetValue) {
        profileNotifier.grantAchievement('mystery_solver');
        currencyNotifier.addDiamonds(mysterySolverDef.diamondReward,
            reason: 'achievement', refId: 'mystery_solver');
        unlocked.add(mysterySolverDef);
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
