import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navell/services/auth_service.dart';
import 'package:navell/services/currency_service.dart';
import 'package:navell/services/http_client.dart';
import 'package:navell/services/promo_service.dart';
import 'package:navell/services/vip_service.dart';

/// Залогиненный/разлогиненный фейк авторизации (как в economy_queue_test)
class _FakeAuthService extends AuthService {
  _FakeAuthService(super.ref, {bool loggedIn = true}) {
    state = loggedIn
        ? const AuthState(isLoggedIn: true, token: 'test-token')
        : const AuthState();
  }
}

void main() {
  late Directory tempDir;

  const boxes = ['app_settings', 'currency', 'user_profile', 'economy_queue'];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('promo_service_test');
    Hive.init(tempDir.path);
    for (final box in boxes) {
      await Hive.openBox<String>(box);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    for (final box in boxes) {
      await Hive.box<String>(box).clear();
    }
  });

  ProviderContainer buildContainer({
    required MockClient mockClient,
    bool loggedIn = true,
  }) {
    return ProviderContainer(overrides: [
      authServiceProvider.overrideWith(
        (ref) => _FakeAuthService(ref, loggedIn: loggedIn),
      ),
      httpClientProvider.overrideWith(
        (ref) => ApiHttpClient(
          tokenProvider: () => loggedIn ? 'test-token' : null,
          refresher: () async => false,
          httpClient: mockClient,
        ),
      ),
    ]);
  }

  group('Промокоды (спека 4.5)', () {
    test('успех: POST /promo/redeem, награда парсится, balances авторитетны',
        () async {
      String? requestPath;
      Map<String, dynamic>? requestBody;
      final mock = MockClient((request) async {
        requestPath = request.url.path;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'reward': {'diamonds': 50, 'tickets': 2, 'vipDays': 0},
            'balances': {'diamonds': 150, 'tickets': 7},
          }),
          200,
        );
      });

      final container = buildContainer(mockClient: mock);
      addTearDown(container.dispose);

      final result =
          await container.read(promoServiceProvider).redeem('  summer26  ');

      expect(result.success, isTrue);
      expect(result.reward?.diamonds, 50);
      expect(result.reward?.tickets, 2);
      expect(result.reward?.vipDays, 0);
      expect(requestPath, endsWith('/promo/redeem'));
      // Код триммится перед отправкой
      expect(requestBody?['code'], 'summer26');

      // Балансы из ответа применены как авторитетные
      final currency = container.read(currencyServiceProvider);
      expect(currency.diamonds, 150);
      expect(currency.tickets, 7);
    });

    test('vipDays > 0 продлевает VIP локально (от max(now, текущего))',
        () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'reward': {'diamonds': 0, 'tickets': 0, 'vipDays': 30},
              'balances': {'diamonds': 100, 'tickets': 5},
            }),
            200,
          ));

      final container = buildContainer(mockClient: mock);
      addTearDown(container.dispose);

      final result =
          await container.read(promoServiceProvider).redeem('VIPCODE');
      expect(result.success, isTrue);

      final vip = container.read(vipServiceProvider);
      expect(vip.isActive, isTrue);
      final expiresAt = vip.expiresAt;
      expect(expiresAt, isNotNull);
      final expectedMin =
          DateTime.now().add(const Duration(days: 29, hours: 23));
      final expectedMax = DateTime.now().add(const Duration(days: 30, hours: 1));
      expect(expiresAt!.isAfter(expectedMin), isTrue);
      expect(expiresAt.isBefore(expectedMax), isTrue);
    });

    test('404 → «не найден», баланс не меняется', () async {
      final mock =
          MockClient((_) async => http.Response('{"error":"not found"}', 404));
      final container = buildContainer(mockClient: mock);
      addTearDown(container.dispose);

      final before = container.read(currencyServiceProvider).diamonds;
      final result = await container.read(promoServiceProvider).redeem('NOPE');

      expect(result.success, isFalse);
      expect(result.message, 'Промокод не найден или неактивен');
      expect(container.read(currencyServiceProvider).diamonds, before);
    });

    test('409 → «уже активирован»', () async {
      final mock =
          MockClient((_) async => http.Response('{"error":"dup"}', 409));
      final container = buildContainer(mockClient: mock);
      addTearDown(container.dispose);

      final result = await container.read(promoServiceProvider).redeem('DUP');
      expect(result.success, isFalse);
      expect(result.message, 'Вы уже активировали этот промокод');
    });

    test('410 → «истёк или исчерпан»', () async {
      final mock =
          MockClient((_) async => http.Response('{"error":"gone"}', 410));
      final container = buildContainer(mockClient: mock);
      addTearDown(container.dispose);

      final result = await container.read(promoServiceProvider).redeem('OLD');
      expect(result.success, isFalse);
      expect(result.message,
          'Срок действия промокода истёк или лимит активаций исчерпан');
    });

    test('сетевая ошибка → человеческое сообщение, не исключение', () async {
      final mock = MockClient((_) async {
        throw const SocketException('offline');
      });
      final container = buildContainer(mockClient: mock);
      addTearDown(container.dispose);

      final result = await container.read(promoServiceProvider).redeem('ANY');
      expect(result.success, isFalse);
      expect(result.message, 'Нет соединения. Попробуйте позже');
    });

    test('без логина → просьба войти, запрос не уходит', () async {
      var called = false;
      final mock = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final container = buildContainer(mockClient: mock, loggedIn: false);
      addTearDown(container.dispose);

      final result = await container.read(promoServiceProvider).redeem('ANY');
      expect(result.success, isFalse);
      expect(result.message, 'Войдите в аккаунт, чтобы активировать промокод');
      expect(called, isFalse);
    });

    test('пустой код → валидация без запроса', () async {
      var called = false;
      final mock = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final container = buildContainer(mockClient: mock);
      addTearDown(container.dispose);

      final result = await container.read(promoServiceProvider).redeem('   ');
      expect(result.success, isFalse);
      expect(called, isFalse);
    });
  });
}
