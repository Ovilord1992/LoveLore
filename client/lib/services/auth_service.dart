import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'analytics_service.dart';
import 'api_config.dart';
import 'currency_service.dart';
import 'economy_service.dart';
import 'user_profile_service.dart';
import 'vip_service.dart';

/// Состояние авторизации
class AuthState {
  final bool isLoggedIn;
  final String? token;
  final String? userId;
  final String? email;
  final String? displayName;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.token,
    this.userId,
    this.email,
    this.displayName,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? token,
    String? userId,
    String? email,
    String? displayName,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        token: token ?? this.token,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final authServiceProvider =
    StateNotifierProvider<AuthService, AuthState>((ref) {
  return AuthService(ref);
});

/// Сервис авторизации (JWT + refresh + email/пароль + Google + Apple)
class AuthService extends StateNotifier<AuthState> {
  static const _boxName = 'app_settings';
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _baseUrl = ApiConfig.baseUrl;

  final Ref _ref;

  /// Сериализация refresh: один общий Future на все параллельные 401.
  Future<bool>? _refreshInFlight;

  AuthService(this._ref) : super(const AuthState()) {
    _loadToken();
  }

  /// Загрузить сохранённый токен
  void _loadToken() {
    try {
      final box = Hive.box<String>(_boxName);
      final token = box.get(_tokenKey);
      if (token != null) {
        state = state.copyWith(token: token, isLoggedIn: true);
        _fetchMe(token);
      }
    } catch (_) {}
  }

  /// Получить данные текущего пользователя по токену
  Future<void> _fetchMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: _authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['user'] as Map<String, dynamic>;
        state = state.copyWith(
          userId: data['id'] as String,
          email: data['email'] as String,
          displayName: data['displayName'] as String?,
        );
      } else if (response.statusCode == 401) {
        // Токен протух — пробуем refresh (спека 2.1); при провале — logout.
        // 500/502/503 (падение БД, деплой, прокси) НЕ должны разлогинивать.
        final refreshed = await refreshTokens();
        if (refreshed && state.token != null) {
          await _fetchMe(state.token!);
        }
      }
    } catch (_) {
      // Сервер недоступен — работаем оффлайн с токеном
    }
  }

  /// Сохранённый refresh-токен (или null)
  String? get refreshToken {
    try {
      return Hive.box<String>(_boxName).get(_refreshTokenKey);
    } catch (_) {
      return null;
    }
  }

  /// Один сериализованный refresh access-токена (спека 2.1).
  ///
  /// Возвращает true при успехе. При явном отказе сервера (400/401/403) —
  /// разлогин и false. При сетевой ошибке — false БЕЗ разлогина (офлайн не
  /// должен выбрасывать из аккаунта).
  Future<bool> refreshTokens() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _doRefresh().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = future;
    return future;
  }

  Future<bool> _doRefresh() async {
    final refresh = refreshToken;
    if (refresh == null || refresh.isEmpty) {
      // Легаси-сессия без refresh-токена: обновить нечем.
      await logout();
      return false;
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final token = body['token'] as String?;
        final newRefresh = body['refreshToken'] as String?;
        if (token == null) return false;
        await _saveTokens(token, newRefresh ?? refresh);
        state = state.copyWith(token: token, isLoggedIn: true);
        return true;
      }
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 404) {
        // Refresh отклонён (ротация/отзыв/эндпоинт недоступен логически) —
        // сессию восстановить нельзя.
        await logout();
        return false;
      }
      return false; // 5xx — транзиентно, не разлогиниваем
    } catch (_) {
      return false; // сеть — транзиентно
    }
  }

  /// Валидный access-токен: если текущий истекает в ближайшие 30 секунд —
  /// сначала выполняется (сериализованный) refresh.
  Future<String?> getValidAccessToken() async {
    final token = state.token;
    if (token == null) return null;
    final exp = _tokenExpiry(token);
    if (exp != null &&
        exp.isBefore(DateTime.now().add(const Duration(seconds: 30))) &&
        refreshToken != null) {
      await refreshTokens();
    }
    return state.token;
  }

  /// Распарсить exp из JWT (без верификации подписи — только для клиента)
  DateTime? _tokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      }
    } catch (_) {}
    return null;
  }

  /// Регистрация
  Future<bool> register(String email, String password, {String? displayName}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'email': email,
          'password': password,
          // ignore: use_null_aware_elements
          if (displayName != null) 'displayName': displayName,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        final token = body['token'] as String;
        final user = body['user'] as Map<String, dynamic>;

        await _saveTokens(token, body['refreshToken'] as String?);
        state = AuthState(
          isLoggedIn: true,
          token: token,
          userId: user['id'] as String,
          email: user['email'] as String,
          displayName: user['displayName'] as String?,
        );
        _onLoggedIn();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: body['error'] as String? ?? 'Registration failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection error: $e',
      );
      return false;
    }
  }

  /// Вход
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = body['token'] as String;
        final user = body['user'] as Map<String, dynamic>;

        await _saveTokens(token, body['refreshToken'] as String?);
        state = AuthState(
          isLoggedIn: true,
          token: token,
          userId: user['id'] as String,
          email: user['email'] as String,
          displayName: user['displayName'] as String?,
        );
        _onLoggedIn();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: body['error'] as String? ?? 'Login failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection error: $e',
      );
      return false;
    }
  }

  /// Вход через Google
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        state = state.copyWith(isLoading: false, error: 'Google token error');
        return false;
      }

      return _socialLogin(
        provider: 'google',
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Google Sign-In error: $e');
      return false;
    }
  }

  /// Вход через Apple
  Future<bool> loginWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      state = state.copyWith(error: 'Apple Sign-In доступен только на iOS');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        state = state.copyWith(isLoading: false, error: 'Apple token error');
        return false;
      }

      final name = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');

      return _socialLogin(
        provider: 'apple',
        idToken: idToken,
        email: credential.email,
        displayName: name.isNotEmpty ? name : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Apple Sign-In error: $e');
      return false;
    }
  }

  /// Общий метод для соцсетей — отправляет токен на сервер
  Future<bool> _socialLogin({
    required String provider,
    required String idToken,
    String? email,
    String? displayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/social'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'provider': provider,
          'idToken': idToken,
          // ignore: use_null_aware_elements
          if (email != null) 'email': email,
          // ignore: use_null_aware_elements
          if (displayName != null) 'displayName': displayName,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = body['token'] as String;
        final user = body['user'] as Map<String, dynamic>;

        await _saveTokens(token, body['refreshToken'] as String?);
        state = AuthState(
          isLoggedIn: true,
          token: token,
          userId: user['id'] as String,
          email: user['email'] as String,
          displayName: user['displayName'] as String?,
        );
        _onLoggedIn();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: body['error'] as String? ?? 'Social login failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Connection error: $e');
      return false;
    }
  }

  /// Хук после успешного логина/регистрации: отдать накопленные офлайн-очереди.
  void _onLoggedIn() {
    try {
      _ref.read(economyServiceProvider).onLogin();
      _ref.read(analyticsServiceProvider).flush();
    } catch (_) {}
  }

  /// Выход. Помимо токена очищаем данные, привязанные к аккаунту, чтобы они
  /// не «протекли» следующему пользователю на этом же устройстве.
  Future<void> logout() async {
    // Отзываем refresh-токен на сервере (best-effort)
    final refresh = refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$_baseUrl/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': refresh}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    try {
      final box = Hive.box<String>(_boxName);
      await box.delete(_tokenKey);
      await box.delete(_refreshTokenKey);
      await box.delete('vip_state');
      await box.delete('pending_iap_verifications');
      await box.delete('processed_purchase_ids');
      await box.delete('starter_bundle_purchased');
    } catch (_) {}
    // Сбрасываем in-memory состояние сервисов (Hive-очистки недостаточно —
    // StateNotifier'ы держат значения в памяти до перезапуска).
    try {
      _ref.read(currencyServiceProvider.notifier).reset();
      _ref.read(vipServiceProvider.notifier).reset();
      _ref.read(userProfileProvider.notifier).reset();
    } catch (_) {}
    state = const AuthState();
  }

  /// HTTP headers с токеном
  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Получить auth headers для других сервисов
  Map<String, String>? get authHeaders {
    if (state.token == null) return null;
    return _authHeaders(state.token!);
  }

  Future<void> _saveTokens(String token, String? refreshToken) async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_tokenKey, token);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await box.put(_refreshTokenKey, refreshToken);
      }
    } catch (_) {}
  }
}
