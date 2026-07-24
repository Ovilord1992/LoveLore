// Промокоды (спека 4.5): POST /v1/promo/redeem через единый HTTP-слой.
//
// Успех: показ награды + применение balances (авторитетны, как в
// economy_service). Ошибки 404/409/410 маппятся в человеческие сообщения.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'currency_service.dart';
import 'http_client.dart';
import 'vip_service.dart';

/// Провайдер сервиса промокодов
final promoServiceProvider = Provider<PromoService>((ref) {
  return PromoService(ref);
});

/// Награда промокода
class PromoReward {
  final int diamonds;
  final int tickets;
  final int vipDays;

  const PromoReward({
    this.diamonds = 0,
    this.tickets = 0,
    this.vipDays = 0,
  });

  factory PromoReward.fromJson(Map<String, dynamic> json) => PromoReward(
        diamonds: (json['diamonds'] as num?)?.toInt() ?? 0,
        tickets: (json['tickets'] as num?)?.toInt() ?? 0,
        vipDays: (json['vipDays'] as num?)?.toInt() ?? 0,
      );

  bool get isEmpty => diamonds == 0 && tickets == 0 && vipDays == 0;
}

/// Результат активации промокода
class PromoRedeemResult {
  final bool success;
  final PromoReward? reward;

  /// Человекочитаемое сообщение (для snackbar/диалога)
  final String message;

  const PromoRedeemResult._({
    required this.success,
    this.reward,
    required this.message,
  });

  factory PromoRedeemResult.ok(PromoReward reward) => PromoRedeemResult._(
        success: true,
        reward: reward,
        message: 'Промокод активирован!',
      );

  factory PromoRedeemResult.fail(String message) =>
      PromoRedeemResult._(success: false, message: message);
}

/// Сервис активации промокодов
class PromoService {
  final Ref _ref;

  PromoService(this._ref);

  /// Активировать промокод. Balances из ответа авторитетны —
  /// локальный баланс приводится к ним (как в EconomyService).
  Future<PromoRedeemResult> redeem(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return PromoRedeemResult.fail('Введите промокод');
    }

    try {
      final client = _ref.read(httpClientProvider);
      final response =
          await client.post('/promo/redeem', body: {'code': trimmed});

      switch (response.statusCode) {
        case 200:
          Map<String, dynamic> body;
          try {
            body = jsonDecode(response.body) as Map<String, dynamic>;
          } catch (_) {
            body = const {};
          }
          final reward = PromoReward.fromJson(
            body['reward'] is Map<String, dynamic>
                ? body['reward'] as Map<String, dynamic>
                : const {},
          );
          final balances = body['balances'];
          if (balances is Map<String, dynamic>) {
            _applyBalances(balances);
          }
          if (reward.vipDays > 0) {
            _extendVip(reward.vipDays);
          }
          return PromoRedeemResult.ok(reward);
        case 404:
          return PromoRedeemResult.fail('Промокод не найден или неактивен');
        case 409:
          return PromoRedeemResult.fail('Вы уже активировали этот промокод');
        case 410:
          return PromoRedeemResult.fail(
              'Срок действия промокода истёк или лимит активаций исчерпан');
        case 401:
          return PromoRedeemResult.fail(
              'Войдите в аккаунт, чтобы активировать промокод');
        default:
          debugPrint('[Promo] redeem status ${response.statusCode}');
          return PromoRedeemResult.fail(
              'Не удалось активировать промокод. Попробуйте позже');
      }
    } on ApiUnauthorizedException {
      return PromoRedeemResult.fail(
          'Войдите в аккаунт, чтобы активировать промокод');
    } catch (e) {
      debugPrint('[Promo] redeem failed: $e');
      return PromoRedeemResult.fail('Нет соединения. Попробуйте позже');
    }
  }

  /// Серверные балансы авторитетны (спека 2.2/4.5)
  void _applyBalances(Map<String, dynamic> balances) {
    final diamonds = balances['diamonds'];
    final tickets = balances['tickets'];
    _ref.read(currencyServiceProvider.notifier).setBalance(
          diamonds: diamonds is num ? diamonds.toInt() : null,
          tickets: tickets is num ? tickets.toInt() : null,
        );
  }

  /// Локальное продление VIP: сервер продлил vipExpiresAt от
  /// max(now, текущий) — повторяем ту же семантику на клиенте.
  void _extendVip(int vipDays) {
    try {
      final vipState = _ref.read(vipServiceProvider);
      final now = DateTime.now();
      final current = vipState.expiresAt;
      final base = (current != null && current.isAfter(now)) ? current : now;
      _ref
          .read(vipServiceProvider.notifier)
          .setExpiresAt(base.add(Duration(days: vipDays)));
    } catch (e) {
      debugPrint('[Promo] VIP extend failed: $e');
    }
  }
}
