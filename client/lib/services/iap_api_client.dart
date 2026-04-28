import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

/// Источник JWT для IAP-эндпоинта. Абстрагирован, чтобы тесты могли
/// подменять без поднятия [AuthService].
abstract class IapAuthTokenSource {
  Future<String?> getToken();
}

/// Реальная реализация — читает токен из [AuthService] через [Ref].
class _RiverpodAuthTokenSource implements IapAuthTokenSource {
  final Ref _ref;
  _RiverpodAuthTokenSource(this._ref);

  @override
  Future<String?> getToken() async {
    return _ref.read(authServiceProvider).token;
  }
}

/// Контракт IAP-валидатора. Сделан абстрактным — в тестах подменяется
/// фейком, в проде используется [IapApiClient].
abstract class IapVerifier {
  Future<IapVerifyResult> verifyPurchase({
    required String platform,
    required String productId,
    required String receipt,
  });
}

/// Серверный баланс пользователя, возвращённый эндпоинтом верификации.
class IapNewBalance {
  final int diamonds;
  final int tickets;

  const IapNewBalance({required this.diamonds, required this.tickets});

  factory IapNewBalance.fromJson(Map<String, dynamic> json) => IapNewBalance(
        diamonds: (json['diamonds'] as num?)?.toInt() ?? 0,
        tickets: (json['tickets'] as num?)?.toInt() ?? 0,
      );
}

/// Возможные финальные статусы IAP-верификации.
class IapVerifyStatus {
  static const success = 'success';
  static const alreadyClaimed = 'already_claimed';
  static const invalid = 'invalid';
}

/// Результат вызова [IapApiClient.verifyPurchase].
///
/// Сетевые/серверные ошибки наружу пробрасываются исключениями
/// (см. [IapVerifyTransientException]). Только финальные ответы 200/400
/// сворачиваются в [IapVerifyResult].
class IapVerifyResult {
  final String status;
  final Map<String, dynamic>? rewards;
  final IapNewBalance? newBalance;
  final DateTime? vipExpiresAt;
  final String? error;

  const IapVerifyResult({
    required this.status,
    this.rewards,
    this.newBalance,
    this.vipExpiresAt,
    this.error,
  });

  bool get isSuccess =>
      status == IapVerifyStatus.success ||
      status == IapVerifyStatus.alreadyClaimed;

  factory IapVerifyResult.invalid({String? error}) => IapVerifyResult(
        status: IapVerifyStatus.invalid,
        error: error,
      );

  factory IapVerifyResult.fromJson(Map<String, dynamic> json) {
    final balance = json['newBalance'];
    final expires = json['vipExpiresAt'];
    final rewards = json['rewards'];
    return IapVerifyResult(
      status: json['status'] as String? ?? IapVerifyStatus.invalid,
      rewards: rewards is Map<String, dynamic> ? rewards : null,
      newBalance: balance is Map<String, dynamic>
          ? IapNewBalance.fromJson(balance)
          : null,
      vipExpiresAt: expires is String ? DateTime.tryParse(expires) : null,
      error: json['error'] as String?,
    );
  }
}

/// Бросается, когда верификация недоступна по транзиентной причине
/// (нет сети / таймаут / 5xx). Покупка должна быть положена в
/// pending-очередь и повторена позже.
class IapVerifyTransientException implements Exception {
  final String message;
  const IapVerifyTransientException(this.message);
  @override
  String toString() => 'IapVerifyTransientException: $message';
}

/// Бросается, когда пользователь не авторизован (401) либо нет JWT.
class IapVerifyUnauthorizedException implements Exception {
  final String message;
  const IapVerifyUnauthorizedException(this.message);
  @override
  String toString() => 'IapVerifyUnauthorizedException: $message';
}

/// HTTP-клиент серверного IAP-эндпоинта `POST /v1/iap/verify`.
class IapApiClient implements IapVerifier {
  final String _baseUrl;
  final IapAuthTokenSource _auth;
  final http.Client _http;
  final Duration _timeout;

  IapApiClient({
    String baseUrl = ApiConfig.baseUrl,
    required IapAuthTokenSource auth,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
  })  : _baseUrl = baseUrl,
        _auth = auth,
        _http = httpClient ?? http.Client(),
        _timeout = timeout;

  /// Удобный конструктор — берёт токен из [AuthService] через [Ref].
  factory IapApiClient.fromRef(Ref ref) => IapApiClient(
        auth: _RiverpodAuthTokenSource(ref),
      );

  @override
  Future<IapVerifyResult> verifyPurchase({
    required String platform,
    required String productId,
    required String receipt,
  }) async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw const IapVerifyUnauthorizedException('No auth token');
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$_baseUrl/iap/verify'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'platform': platform,
              'productId': productId,
              'receipt': receipt,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException catch (e) {
      throw IapVerifyTransientException('timeout: $e');
    } on SocketException catch (e) {
      throw IapVerifyTransientException('socket: $e');
    } on http.ClientException catch (e) {
      throw IapVerifyTransientException('http: $e');
    }

    final code = response.statusCode;
    if (code == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return IapVerifyResult.fromJson(body);
      }
      return IapVerifyResult.invalid(error: 'malformed response');
    } else if (code == 400) {
      String? error;
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          error = body['error'] as String?;
        }
      } catch (_) {}
      return IapVerifyResult.invalid(error: error);
    } else if (code == 401) {
      throw const IapVerifyUnauthorizedException('401 from /iap/verify');
    } else if (code >= 500 && code < 600) {
      throw IapVerifyTransientException('server $code');
    } else {
      // Прочие непредвиденные коды считаем транзиентными — лучше отложить,
      // чем потерять валюту.
      throw IapVerifyTransientException('unexpected status $code');
    }
  }

  /// Закрыть подлежащий http-клиент. Нужно только в тестах.
  void close() => _http.close();
}

/// Провайдер IAP API-клиента (отдельный, чтобы можно было override-нуть в тестах).
final iapApiClientProvider = Provider<IapVerifier>((ref) {
  return IapApiClient.fromRef(ref);
});
