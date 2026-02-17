// Мультиязычность — простой менеджер локализации
//
// Поддерживает русский и английский языки.
// Строки хранятся в Map для быстрого доступа без зависимости от intl.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'remote_config_service.dart';

/// Текущий язык приложения
final localeProvider =
    StateNotifierProvider<LocaleNotifier, AppLocale>((ref) {
  return LocaleNotifier();
});

enum AppLocale { ru, en }

class LocaleNotifier extends StateNotifier<AppLocale> {
  static const _boxName = 'app_locale';
  static const _key = 'locale';

  LocaleNotifier() : super(AppLocale.ru) {
    _loadSync();
  }

  void setLocale(AppLocale locale) {
    state = locale;
    _save();
  }

  void toggle() {
    state = state == AppLocale.ru ? AppLocale.en : AppLocale.ru;
    _save();
  }

  Future<void> _save() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_key, state.name);
    } catch (_) {}
  }

  void _loadSync() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_key);
      if (data == 'en') state = AppLocale.en;
    } catch (_) {}
  }
}

/// Доступ к строкам: ref.tr('key')
/// Сначала ищет в remote config, затем в хардкоде
extension LocaleRefExtension on WidgetRef {
  String tr(String key) {
    final locale = watch(localeProvider);
    final remote = watch(remoteConfigProvider).localization;
    final lang = locale == AppLocale.ru ? 'ru' : 'en';
    // Remote config override
    if (remote.containsKey(lang) && remote[lang]!.containsKey(key)) {
      return remote[lang]![key]!;
    }
    return AppStrings.get(key, locale);
  }
}

/// Статический доступ
class AppStrings {
  static String get(String key, AppLocale locale) {
    final strings =
        locale == AppLocale.ru ? _stringsRu : _stringsEn;
    return strings[key] ?? key;
  }
}

const _stringsRu = <String, String>{
  // Общие
  'app_name': 'Amoria',
  'your_stories': 'Твои истории',
  'settings': 'Настройки',
  'profile': 'Профиль',
  'gallery': 'Галерея',
  'back': 'Назад',
  'cancel': 'Отмена',
  'save': 'Сохранить',
  'saved': 'Сохранено ✓',
  'delete': 'Удалить',

  // Библиотека
  'no_novels': 'Пока нет новелл',
  'add_novels_hint': 'Добавьте новеллы в assets/novels/',

  // Игровой экран
  'end_of_chapter': 'Конец главы',
  'not_enough_diamonds': 'Не хватает алмазов',

  // Детали новеллы
  'continue_reading': 'Продолжить',
  'start_story': 'Начать историю',
  'start_over': 'Начать заново',
  'start_over_confirm': 'Начать заново?',
  'progress_will_be_lost': 'Весь прогресс будет потерян. Вы уверены?',
  'has_save': 'Есть сохранение',
  'chapters_count': 'глав',

  // Настройки
  'text': 'Текст',
  'text_speed': 'Скорость текста',
  'fast': 'Быстро',
  'slow': 'Медленно',
  'auto_play': 'Автопрокрутка',
  'auto_play_desc': 'Автоматически переключать диалоги',
  'auto_play_delay': 'Задержка автопрокрутки',
  'sound': 'Звук',
  'sound_on': 'Включён',
  'sound_off': 'Выключен',
  'music': 'Музыка',
  'sfx': 'Звуковые эффекты',
  'about': 'О приложении',
  'version': 'Версия 1.0.0',
  'language': 'Язык',

  // Профиль
  'reader': 'Читатель',
  'diamonds': 'Алмазы',
  'tickets': 'Билеты',
  'statistics': 'Статистика',
  'novels_started': 'Новелл начато',
  'novels_completed': 'Новелл пройдено',
  'chapters_read': 'Глав прочитано',
  'choices_made': 'Выборов сделано',
  'achievements': 'Достижения',
  'no_achievements': 'Пока нет достижений.\nИграй, чтобы открывать новые!',
  'gallery_empty': 'Галерея пуста.\nРазблокируй CG-арты в историях!',
  'choose_avatar': 'Выбери аватар',
  'name': 'Имя',
  'enter_name': 'Введи имя',

  // Достижения
  'achievement_unlocked': 'Достижение разблокировано!',

  // Гардероб
  'wardrobe': 'Гардероб',
  'wardrobe_empty': 'Пока нет нарядов.\nОткрывай новые образы в историях!',
  'outfit_unlocked': 'Новый наряд разблокирован!',
  'equip': 'Надеть',
  'equipped': 'Надето',
};

const _stringsEn = <String, String>{
  // General
  'app_name': 'Amoria',
  'your_stories': 'Your Stories',
  'settings': 'Settings',
  'profile': 'Profile',
  'gallery': 'Gallery',
  'back': 'Back',
  'cancel': 'Cancel',
  'save': 'Save',
  'saved': 'Saved ✓',
  'delete': 'Delete',

  // Library
  'no_novels': 'No novels yet',
  'add_novels_hint': 'Add novels to assets/novels/',

  // Game screen
  'end_of_chapter': 'End of chapter',
  'not_enough_diamonds': 'Not enough diamonds',

  // Novel detail
  'continue_reading': 'Continue',
  'start_story': 'Start Story',
  'start_over': 'Start Over',
  'start_over_confirm': 'Start over?',
  'progress_will_be_lost': 'All progress will be lost. Are you sure?',
  'has_save': 'Has save',
  'chapters_count': 'chapters',

  // Settings
  'text': 'Text',
  'text_speed': 'Text speed',
  'fast': 'Fast',
  'slow': 'Slow',
  'auto_play': 'Auto-play',
  'auto_play_desc': 'Automatically advance dialogue',
  'auto_play_delay': 'Auto-play delay',
  'sound': 'Sound',
  'sound_on': 'On',
  'sound_off': 'Off',
  'music': 'Music',
  'sfx': 'Sound effects',
  'about': 'About',
  'version': 'Version 1.0.0',
  'language': 'Language',

  // Profile
  'reader': 'Reader',
  'diamonds': 'Diamonds',
  'tickets': 'Tickets',
  'statistics': 'Statistics',
  'novels_started': 'Novels started',
  'novels_completed': 'Novels completed',
  'chapters_read': 'Chapters read',
  'choices_made': 'Choices made',
  'achievements': 'Achievements',
  'no_achievements': 'No achievements yet.\nPlay to unlock new ones!',
  'gallery_empty': 'Gallery is empty.\nUnlock CG art in stories!',
  'choose_avatar': 'Choose avatar',
  'name': 'Name',
  'enter_name': 'Enter name',

  // Achievements
  'achievement_unlocked': 'Achievement unlocked!',

  // Wardrobe
  'wardrobe': 'Wardrobe',
  'wardrobe_empty': 'No outfits yet.\nUnlock new looks in stories!',
  'outfit_unlocked': 'New outfit unlocked!',
  'equip': 'Equip',
  'equipped': 'Equipped',
};
