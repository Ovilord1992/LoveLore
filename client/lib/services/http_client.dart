import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

/// Провайдер единого HTTP-слоя приложения
final httpClientProvider = Provider<ApiHttpClient>((ref) {
  return ApiHttpClient(
    tokenProvider: () => ref.read(authServiceProvider).token,
    refresher: () => ref.read(authServiceProvider.notifier).refreshTokens(),
  );
});

/// Единая точка авторизованных запросов (спека 2.1).
///
/// На 401 выполняет ОДИН сериализованный refresh (через
/// [AuthService.refreshTokens], который сам single-flight) и повторяет
/// запрос один раз. При провале refresh AuthService выполняет разлогин.
class ApiHttpClient {
  final String baseUrl;
  final http.Client _http;
  final Duration timeout;

  /// Текущий access-токен (или null)
  final String? Function() tokenProvider;

  /// Сериализованный refresh; true — токен обновлён
  final Future<bool> Function() refresher;

  ApiHttpClient({
    required this.tokenProvider,
    required this.refresher,
    this.baseUrl = ApiConfig.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  /// GET-запрос. [auth]: true — требует токен (null токен → исключение
  /// [ApiUnauthorizedException]); false — всегда без токена;
  /// authOptional=true через [optionalAuth].
  Future<http.Response> get(
    String path, {
    bool auth = true,
    bool optionalAuth = false,
  }) {
    return _send('GET', path, auth: auth, optionalAuth: optionalAuth);
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    bool auth = true,
    bool optionalAuth = false,
  }) {
    return _send('POST', path,
        body: body, auth: auth, optionalAuth: optionalAuth);
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    bool auth = true,
    bool optionalAuth = false,
  }) {
    return _send('PUT', path,
        body: body, auth: auth, optionalAuth: optionalAuth);
  }

  Future<http.Response> delete(
    String path, {
    Object? body,
    bool auth = true,
    bool optionalAuth = false,
  }) {
    return _send('DELETE', path,
        body: body, auth: auth, optionalAuth: optionalAuth);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    required bool auth,
    required bool optionalAuth,
  }) async {
    final needsToken = auth && !optionalAuth;
    var token = tokenProvider();
    if (needsToken && (token == null || token.isEmpty)) {
      throw const ApiUnauthorizedException('No auth token');
    }

    var response = await _request(method, path, body, auth ? token : null);

    // Один повтор после сериализованного refresh
    if (response.statusCode == 401 && auth && token != null) {
      final refreshed = await refresher();
      if (!refreshed) {
        if (needsToken) {
          throw const ApiUnauthorizedException('Refresh failed');
        }
        return response;
      }
      token = tokenProvider();
      response = await _request(method, path, body, token);
    }

    return response;
  }

  Future<http.Response> _request(
    String method,
    String path,
    Object? body,
    String? token,
  ) {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : jsonEncode(body);

    final Future<http.Response> future = switch (method) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: encoded),
      'PUT' => _http.put(uri, headers: headers, body: encoded),
      'DELETE' => _http.delete(uri, headers: headers, body: encoded),
      _ => throw ArgumentError('Unsupported method $method'),
    };
    return future.timeout(timeout);
  }

  void close() => _http.close();
}

/// Нет валидного токена и восстановить его не удалось
class ApiUnauthorizedException implements Exception {
  final String message;
  const ApiUnauthorizedException(this.message);
  @override
  String toString() => 'ApiUnauthorizedException: $message';
}
