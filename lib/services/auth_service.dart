import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
  return AuthService();
});

/// Сервис авторизации (JWT + email/пароль)
class AuthService extends StateNotifier<AuthState> {
  static const _boxName = 'app_settings';
  static const _tokenKey = 'auth_token';
  static const _baseUrl = 'http://localhost:3000/v1';

  AuthService() : super(const AuthState()) {
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
      } else {
        // Токен невалиден — разлогиниваем
        await logout();
      }
    } catch (_) {
      // Сервер недоступен — работаем оффлайн с токеном
    }
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

        await _saveToken(token);
        state = AuthState(
          isLoggedIn: true,
          token: token,
          userId: user['id'] as String,
          email: user['email'] as String,
          displayName: user['displayName'] as String?,
        );
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

        await _saveToken(token);
        state = AuthState(
          isLoggedIn: true,
          token: token,
          userId: user['id'] as String,
          email: user['email'] as String,
          displayName: user['displayName'] as String?,
        );
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

        await _saveToken(token);
        state = AuthState(
          isLoggedIn: true,
          token: token,
          userId: user['id'] as String,
          email: user['email'] as String,
          displayName: user['displayName'] as String?,
        );
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

  /// Выход
  Future<void> logout() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.delete(_tokenKey);
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

  Future<void> _saveToken(String token) async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_tokenKey, token);
    } catch (_) {}
  }
}
