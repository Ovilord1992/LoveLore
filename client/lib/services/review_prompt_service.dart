import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';

import 'user_profile_service.dart';

/// Провайдер in-app review (волна 3, чеклист 5)
final reviewPromptServiceProvider = Provider<ReviewPromptService>((ref) {
  return ReviewPromptService(ref);
});

/// Системный запрос оценки в сторе (`in_app_review`).
///
/// Триггер: первая достигнутая концовка ИЛИ 5+ завершённых глав.
/// Не чаще одного раза в 30 дней (`inapp_review_last_prompt` в app_settings).
/// Стор может молча не показать диалог — это нормально; недоступность
/// плагина/стора не роняет приложение (всё в try/catch).
class ReviewPromptService {
  static const _boxName = 'app_settings';
  static const lastPromptKey = 'inapp_review_last_prompt';
  static const _cooldown = Duration(days: 30);
  static const _chaptersThreshold = 5;

  final Ref _ref;

  ReviewPromptService(this._ref);

  /// Выполнены ли условия триггера (чистая проверка без плагина)
  bool shouldPrompt({DateTime? now}) {
    final profile = _ref.read(userProfileProvider);
    final qualifies = profile.unlockedEndings.isNotEmpty ||
        profile.totalChaptersRead >= _chaptersThreshold;
    if (!qualifies) return false;

    final last = _lastPromptTime;
    if (last == null) return true;
    return (now ?? DateTime.now()).difference(last) >= _cooldown;
  }

  /// Запросить системный диалог оценки, если условия выполнены
  Future<void> maybePrompt() async {
    if (!shouldPrompt()) return;
    // Флаг ставим ДО вызова: даже если стор молча съел запрос, свою
    // 30-дневную квоту мы потратили.
    _setLastPromptTime(DateTime.now());
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (e) {
      debugPrint('[Review] in-app review failed: $e');
    }
  }

  DateTime? get _lastPromptTime {
    try {
      final raw = Hive.box<String>(_boxName).get(lastPromptKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  void _setLastPromptTime(DateTime time) {
    try {
      Hive.box<String>(_boxName).put(lastPromptKey, time.toIso8601String());
    } catch (_) {}
  }
}
