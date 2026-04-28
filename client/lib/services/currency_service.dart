import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'remote_config_service.dart';
import 'user_profile_service.dart';

/// Провайдер сервиса валюты
final currencyServiceProvider =
    StateNotifierProvider<CurrencyService, CurrencyState>((ref) {
  return CurrencyService(ref);
});

/// Состояние валюты пользователя
class CurrencyState {
  final int diamonds;
  final int tickets; // билеты на чтение глав (энергия)
  final DateTime? lastTicketRefill;

  const CurrencyState({
    this.diamonds = 50, // стартовый бонус
    this.tickets = 5,
    this.lastTicketRefill,
  });

  CurrencyState copyWith({
    int? diamonds,
    int? tickets,
    DateTime? lastTicketRefill,
  }) =>
      CurrencyState(
        diamonds: diamonds ?? this.diamonds,
        tickets: tickets ?? this.tickets,
        lastTicketRefill: lastTicketRefill ?? this.lastTicketRefill,
      );

  Map<String, dynamic> toJson() => {
        'diamonds': diamonds,
        'tickets': tickets,
        'lastTicketRefill': lastTicketRefill?.toIso8601String(),
      };

  factory CurrencyState.fromJson(Map<String, dynamic> json) => CurrencyState(
        diamonds: json['diamonds'] as int? ?? 50,
        tickets: json['tickets'] as int? ?? 5,
        lastTicketRefill: json['lastTicketRefill'] != null
            ? DateTime.parse(json['lastTicketRefill'] as String)
            : null,
      );
}

/// Сервис управления внутриигровой валютой
class CurrencyService extends StateNotifier<CurrencyState> {
  static const _boxName = 'currency';
  static const _key = 'state';

  final Ref _ref;

  // Геттеры для конфигурируемых значений
  EconomyConfig get _economy => _ref.read(remoteConfigProvider).economy;
  int get maxTickets => _economy.maxTickets;
  int get ticketRefillMinutes => _economy.ticketRefillMinutes;

  // Для обратной совместимости (статические ссылки в UI)
  static int get defaultMaxTickets => 5;
  static int get defaultTicketRefillMinutes => 30;

  CurrencyService(this._ref) : super(const CurrencyState()) {
    _loadSync();
    _refillTickets();
  }

  /// Начальное состояние для нового пользователя (из Remote Config)
  CurrencyState get _initialState => CurrencyState(
        diamonds: _economy.startDiamonds,
        tickets: _economy.startTickets,
      );

  /// Вызвать пересчёт билетов (для внешнего вызова, напр. из таймера)
  void checkRefill() {
    _refillTickets();
  }

  /// Хватает ли алмазов на покупку
  bool canAfford(int cost) => state.diamonds >= cost;

  /// Потратить алмазы (возвращает true если успешно)
  bool spendDiamonds(int amount) {
    if (state.diamonds < amount) return false;
    state = state.copyWith(diamonds: state.diamonds - amount);
    _save();
    _ref.read(userProfileProvider.notifier).incrementDiamondsSpent(amount);
    return true;
  }

  /// Добавить алмазы (награда, покупка)
  void addDiamonds(int amount) {
    state = state.copyWith(diamonds: state.diamonds + amount);
    _save();
  }

  /// Абсолютная установка баланса от сервера (источник истины — backend).
  /// Используется после успешной серверной верификации IAP, чтобы
  /// клиент не мог разойтись с реальным балансом.
  void setBalance({int? diamonds, int? tickets}) {
    state = state.copyWith(
      diamonds: diamonds ?? state.diamonds,
      tickets: tickets != null ? tickets.clamp(0, maxTickets) : state.tickets,
    );
    _save();
  }

  /// Потратить билет (энергию) для чтения главы
  bool spendTicket() {
    _refillTickets();
    if (state.tickets <= 0) return false;
    final wasFull = state.tickets >= maxTickets;
    state = state.copyWith(
      tickets: state.tickets - 1,
      // Запускаем таймер рефилла при расходе из полного запаса
      lastTicketRefill: wasFull ? DateTime.now() : state.lastTicketRefill ?? DateTime.now(),
    );
    _save();
    return true;
  }

  /// Добавить билеты
  void addTickets(int amount) {
    state = state.copyWith(
      tickets: (state.tickets + amount).clamp(0, maxTickets),
    );
    _save();
  }

  /// Проверить и пополнить билеты по времени
  void _refillTickets() {
    if (state.tickets >= maxTickets) return;
    final lastRefill = state.lastTicketRefill ?? DateTime.now();
    final elapsed = DateTime.now().difference(lastRefill);
    final ticketsToAdd = elapsed.inMinutes ~/ ticketRefillMinutes;

    if (ticketsToAdd > 0) {
      state = state.copyWith(
        tickets: (state.tickets + ticketsToAdd).clamp(0, maxTickets),
        lastTicketRefill: DateTime.now(),
      );
      _save();
    }
  }

  /// Время до следующего билета
  Duration get timeToNextTicket {
    if (state.tickets >= maxTickets) return Duration.zero;
    final lastRefill = state.lastTicketRefill ?? DateTime.now();
    final next =
        lastRefill.add(Duration(minutes: ticketRefillMinutes));
    final remaining = next.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
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
            CurrencyState.fromJson(jsonDecode(data) as Map<String, dynamic>);
        _refillTickets();
      } else {
        // Новый пользователь — берём значения из Remote Config
        state = _initialState;
        _save();
      }
    } catch (_) {}
  }

  /// Мерж данных с сервера (берём максимум алмазов)
  void mergeFromServer(Map<String, dynamic> serverData) {
    final serverCurrency = CurrencyState.fromJson(serverData);
    state = state.copyWith(
      diamonds: state.diamonds > serverCurrency.diamonds
          ? state.diamonds
          : serverCurrency.diamonds,
      tickets: state.tickets > serverCurrency.tickets
          ? state.tickets
          : serverCurrency.tickets,
    );
    _save();
  }
}
