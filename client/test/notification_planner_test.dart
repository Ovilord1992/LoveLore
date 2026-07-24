import 'package:flutter_test/flutter_test.dart';
import 'package:navell/services/notification_planner.dart';

void main() {
  final now = DateTime(2026, 7, 24, 12, 0); // 12:00 локального

  group('computeTicketRefillTime (спека 4.10)', () {
    test('обычный случай: время полного рефилла от lastRefill', () {
      final lastRefill = now.subtract(const Duration(minutes: 10));
      final result = computeTicketRefillTime(
        tickets: 2,
        maxTickets: 5,
        lastRefill: lastRefill,
        refillMinutes: 30,
        isVip: false,
        now: now,
      );
      // Не хватает 3 билетов × 30 минут = 90 минут от lastRefill
      expect(result, lastRefill.add(const Duration(minutes: 90)));
    });

    test('lastRefill == null: отсчёт от now', () {
      final result = computeTicketRefillTime(
        tickets: 4,
        maxTickets: 5,
        lastRefill: null,
        refillMinutes: 30,
        isVip: false,
        now: now,
      );
      expect(result, now.add(const Duration(minutes: 30)));
    });

    test('VIP → null', () {
      final result = computeTicketRefillTime(
        tickets: 0,
        maxTickets: 5,
        lastRefill: now,
        refillMinutes: 30,
        isVip: true,
        now: now,
      );
      expect(result, isNull);
    });

    test('билеты полные → null', () {
      final result = computeTicketRefillTime(
        tickets: 5,
        maxTickets: 5,
        lastRefill: now,
        refillMinutes: 30,
        isVip: false,
        now: now,
      );
      expect(result, isNull);
    });

    test('билетов больше максимума (после покупки) → null', () {
      final result = computeTicketRefillTime(
        tickets: 8,
        maxTickets: 5,
        lastRefill: now,
        refillMinutes: 30,
        isVip: false,
        now: now,
      );
      expect(result, isNull);
    });

    test('расчётное время в прошлом → null (доначислится при входе)', () {
      final result = computeTicketRefillTime(
        tickets: 4,
        maxTickets: 5,
        lastRefill: now.subtract(const Duration(hours: 2)),
        refillMinutes: 30,
        isVip: false,
        now: now,
      );
      expect(result, isNull);
    });

    test('некорректный интервал рефилла → null', () {
      final result = computeTicketRefillTime(
        tickets: 1,
        maxTickets: 5,
        lastRefill: now,
        refillMinutes: 0,
        isVip: false,
        now: now,
      );
      expect(result, isNull);
    });
  });

  group('computeDailyRewardReminderTime (спека 4.10)', () {
    test('не забрана, до 20:00 → сегодня в 20:00', () {
      final result = computeDailyRewardReminderTime(
        claimedToday: false,
        now: DateTime(2026, 7, 24, 12, 0),
      );
      expect(result, DateTime(2026, 7, 24, 20, 0));
    });

    test('не забрана, после 20:00 → завтра в 20:00', () {
      final result = computeDailyRewardReminderTime(
        claimedToday: false,
        now: DateTime(2026, 7, 24, 21, 30),
      );
      expect(result, DateTime(2026, 7, 25, 20, 0));
    });

    test('ровно 20:00 → завтра (момент уже наступил)', () {
      final result = computeDailyRewardReminderTime(
        claimedToday: false,
        now: DateTime(2026, 7, 24, 20, 0),
      );
      expect(result, DateTime(2026, 7, 25, 20, 0));
    });

    test('награда забрана сегодня → null', () {
      final result = computeDailyRewardReminderTime(
        claimedToday: true,
        now: DateTime(2026, 7, 24, 12, 0),
      );
      expect(result, isNull);
    });

    test('кастомный час', () {
      final result = computeDailyRewardReminderTime(
        claimedToday: false,
        now: DateTime(2026, 7, 24, 12, 0),
        hour: 18,
      );
      expect(result, DateTime(2026, 7, 24, 18, 0));
    });

    test('переход через конец месяца', () {
      final result = computeDailyRewardReminderTime(
        claimedToday: false,
        now: DateTime(2026, 7, 31, 22, 0),
      );
      expect(result, DateTime(2026, 8, 1, 20, 0));
    });
  });
}
