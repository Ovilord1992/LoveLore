/// Чистые функции расчёта времени локальных уведомлений (спека 4.10).
/// Вынесены отдельно от плагина ради юнит-тестов.
library;

/// Момент полного восстановления билетов.
///
/// Возвращает null, если уведомление не нужно:
/// - [isVip] — у VIP билеты безлимитные/неактуальные;
/// - билеты уже полные;
/// - некорректный интервал рефилла;
/// - расчётное время уже в прошлом (билеты доначислятся при входе).
///
/// Логика зеркалит [CurrencyService]: каждые [refillMinutes] минут от
/// [lastRefill] прибавляется один билет.
DateTime? computeTicketRefillTime({
  required int tickets,
  required int maxTickets,
  required DateTime? lastRefill,
  required int refillMinutes,
  required bool isVip,
  required DateTime now,
}) {
  if (isVip) return null;
  if (tickets >= maxTickets) return null;
  if (refillMinutes <= 0) return null;
  final base = lastRefill ?? now;
  final missing = maxTickets - tickets;
  final fullAt = base.add(Duration(minutes: refillMinutes * missing));
  if (!fullAt.isAfter(now)) return null;
  return fullAt;
}

/// Момент напоминания о ежедневной награде: ближайшие [hour]:00 локального
/// времени (сегодня, если час ещё не наступил, иначе завтра).
///
/// Возвращает null, если награда за сегодня уже забрана — завтра при входе
/// в приложение расписание пересчитается.
DateTime? computeDailyRewardReminderTime({
  required bool claimedToday,
  required DateTime now,
  int hour = 20,
}) {
  if (claimedToday) return null;
  final todayAtHour = DateTime(now.year, now.month, now.day, hour);
  if (todayAtHour.isAfter(now)) return todayAtHour;
  return DateTime(now.year, now.month, now.day + 1, hour);
}
