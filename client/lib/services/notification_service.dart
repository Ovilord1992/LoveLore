import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'currency_service.dart';
import 'daily_reward_service.dart';
import 'notification_planner.dart';
import 'remote_config_service.dart';
import 'vip_service.dart';

/// Провайдер локальных уведомлений (спека 4.10)
final notificationServiceProvider =
    StateNotifierProvider<NotificationService, NotificationPrefs>((ref) {
  return NotificationService(ref);
});

/// Тумблеры уведомлений (default off до явного включения пользователем)
class NotificationPrefs {
  final bool ticketRefill;
  final bool dailyReward;

  const NotificationPrefs({
    this.ticketRefill = false,
    this.dailyReward = false,
  });

  NotificationPrefs copyWith({bool? ticketRefill, bool? dailyReward}) =>
      NotificationPrefs(
        ticketRefill: ticketRefill ?? this.ticketRefill,
        dailyReward: dailyReward ?? this.dailyReward,
      );

  bool get anyEnabled => ticketRefill || dailyReward;
}

/// Локальные напоминания (спека 4.10): «Билеты восстановились ✨» на момент
/// полного рефилла и «Твоя ежедневная награда ждёт 🎁» на 20:00 локального.
///
/// Планируются при уходе приложения в фон, отменяются при возврате.
/// Только НЕточные алармы (androidScheduleMode: inexact*) — без
/// SCHEDULE_EXACT_ALARM. Все вызовы плагина в try/catch: недоступность
/// платформенного канала (тесты, десктоп) не должна ронять приложение.
class NotificationService extends StateNotifier<NotificationPrefs> {
  static const _boxName = 'app_settings';
  static const ticketRefillKey = 'notify_tickets_refill';
  static const dailyRewardKey = 'notify_daily_reward';

  static const _ticketNotificationId = 1001;
  static const _dailyNotificationId = 1002;

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService(this._ref) : super(const NotificationPrefs()) {
    _loadSync();
  }

  void _loadSync() {
    state = NotificationPrefs(
      ticketRefill: _readBool(ticketRefillKey),
      dailyReward: _readBool(dailyRewardKey),
    );
  }

  bool _readBool(String key) {
    try {
      return Hive.box<String>(_boxName).get(key) == 'true';
    } catch (_) {
      return false;
    }
  }

  void _writeBool(String key, bool value) {
    try {
      Hive.box<String>(_boxName).put(key, value.toString());
    } catch (_) {}
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Разрешения запрашиваем явно при включении тумблера
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('[Notifications] init failed: $e');
      return false;
    }
  }

  /// Запросить разрешения (Android 13+ / iOS). Вызывается при включении
  /// тумблера. Возвращает false при явном отказе.
  Future<bool> requestPermissions() async {
    if (!await _ensureInitialized()) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? true;
      }
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      }
    } catch (e) {
      debugPrint('[Notifications] permission request failed: $e');
    }
    return true;
  }

  /// Включить/выключить напоминание о восстановлении билетов
  Future<void> setTicketRefillEnabled(bool enabled) async {
    if (enabled) await requestPermissions();
    _writeBool(ticketRefillKey, enabled);
    state = state.copyWith(ticketRefill: enabled);
    if (!enabled) await _cancel(_ticketNotificationId);
  }

  /// Включить/выключить напоминание о ежедневной награде
  Future<void> setDailyRewardEnabled(bool enabled) async {
    if (enabled) await requestPermissions();
    _writeBool(dailyRewardKey, enabled);
    state = state.copyWith(dailyReward: enabled);
    if (!enabled) await _cancel(_dailyNotificationId);
  }

  /// Уход приложения в фон: спланировать напоминания
  Future<void> onAppPaused() async {
    if (!state.anyEnabled) return;
    if (!await _ensureInitialized()) return;

    await _cancelAll();
    final now = DateTime.now();

    if (state.ticketRefill) {
      final time = _computeTicketTime(now);
      if (time != null) {
        await _schedule(
          _ticketNotificationId,
          'Билеты восстановились ✨',
          'Энергия снова полная — пора вернуться к истории!',
          time,
        );
      }
    }

    if (state.dailyReward) {
      final time = _computeDailyTime(now);
      if (time != null) {
        await _schedule(
          _dailyNotificationId,
          'Твоя ежедневная награда ждёт 🎁',
          'Забери подарок дня и продолжи серию!',
          time,
        );
      }
    }
  }

  /// Возврат в приложение: отменить запланированное
  Future<void> onAppResumed() async {
    if (!state.anyEnabled && !_initialized) return;
    if (!await _ensureInitialized()) return;
    await _cancelAll();
  }

  DateTime? _computeTicketTime(DateTime now) {
    try {
      final currency = _ref.read(currencyServiceProvider);
      final economy = _ref.read(remoteConfigProvider).economy;
      final isVip = _ref.read(vipServiceProvider).isActive;
      return computeTicketRefillTime(
        tickets: currency.tickets,
        maxTickets: economy.maxTickets,
        lastRefill: currency.lastTicketRefill,
        refillMinutes: economy.ticketRefillMinutes,
        isVip: isVip,
        now: now,
      );
    } catch (e) {
      debugPrint('[Notifications] ticket time compute failed: $e');
      return null;
    }
  }

  DateTime? _computeDailyTime(DateTime now) {
    try {
      final lastClaim = _ref.read(dailyRewardProvider).lastClaimDate;
      final claimedToday = lastClaim != null &&
          lastClaim.year == now.year &&
          lastClaim.month == now.month &&
          lastClaim.day == now.day;
      return computeDailyRewardReminderTime(
        claimedToday: claimedToday,
        now: now,
      );
    } catch (e) {
      debugPrint('[Notifications] daily time compute failed: $e');
      return null;
    }
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    try {
      // Абсолютный момент: конверсия DateTime → TZDateTime сохраняет instant,
      // поэтому отдельный плагин определения таймзоны не нужен.
      final scheduledDate = tz.TZDateTime.from(when, tz.local);
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'amoria_reminders',
            'Напоминания',
            channelDescription:
                'Восстановление билетов и ежедневные награды',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // НЕточный аларм — без разрешения SCHEDULE_EXACT_ALARM (спека 4.10)
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[Notifications] schedule failed: $e');
    }
  }

  Future<void> _cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('[Notifications] cancel failed: $e');
    }
  }

  Future<void> _cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[Notifications] cancelAll failed: $e');
    }
  }
}
