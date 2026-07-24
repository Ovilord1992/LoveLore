import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navell/services/auth_service.dart';
import 'package:navell/services/currency_service.dart';
import 'package:navell/services/economy_service.dart';
import 'package:navell/services/http_client.dart';

/// Залогиненный/разлогиненный фейк авторизации
class _FakeAuthService extends AuthService {
  _FakeAuthService(super.ref, {bool loggedIn = true}) {
    state = loggedIn
        ? const AuthState(isLoggedIn: true, token: 'test-token')
        : const AuthState();
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('economy_queue_test');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(EconomyService.boxName);
    await Hive.openBox<String>('currency');
    await Hive.openBox<String>('app_settings');
    await Hive.openBox<String>('user_profile');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>(EconomyService.boxName).clear();
    await Hive.box<String>('currency').clear();
    await Hive.box<String>('app_settings').clear();
    await Hive.box<String>('user_profile').clear();
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

  test('enqueue кладёт операцию с уникальным uuid-ключом, reason и refId', () {
    final container = buildContainer(
      mockClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(container.dispose);
    final economy = container.read(economyServiceProvider);

    economy.enqueue(
      currency: 'diamonds',
      delta: -15,
      reason: 'spend_choice',
      refId: 'novel1:scene_5:2',
    );
    economy.enqueue(currency: 'tickets', delta: -1, reason: 'ticket_entry');

    final box = Hive.box<String>(EconomyService.boxName);
    expect(box.length, 2);

    final txs = box.values
        .map((v) => jsonDecode(v) as Map<String, dynamic>)
        .toList();
    final spend = txs.firstWhere((t) => t['reason'] == 'spend_choice');
    expect(spend['currency'], 'diamonds');
    expect(spend['delta'], -15);
    expect(spend['refId'], 'novel1:scene_5:2');
    expect(spend['clientTs'], isA<int>());
    expect(spend['key'], isNotEmpty);

    // Идемпотентные ключи: uuid уникальны и совпадают с ключами бокса
    final keys = txs.map((t) => t['key'] as String).toSet();
    expect(keys.length, 2);
    expect(box.keys.toSet(), keys);
  });

  test('flush: батч уходит с токеном, applied/rejected удаляются, '
      'balances из ответа авторитетны', () async {
    final requests = <Map<String, dynamic>>[];
    String? authHeader;

    final mock = MockClient((request) async {
      authHeader = request.headers['Authorization'];
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final txs = (body['transactions'] as List).cast<Map<String, dynamic>>();
      return http.Response(
        jsonEncode({
          'results': [
            for (final tx in txs)
              {
                'key': tx['key'],
                'status':
                    tx['reason'] == 'ticket_entry' ? 'rejected' : 'applied',
                if (tx['reason'] == 'ticket_entry') 'error': 'no tickets',
              },
          ],
          'balances': {'diamonds': 100, 'tickets': 3},
        }),
        200,
      );
    });

    final container = buildContainer(mockClient: mock);
    addTearDown(container.dispose);
    final economy = container.read(economyServiceProvider);

    economy.enqueue(
        currency: 'diamonds', delta: -15, reason: 'spend_choice');
    economy.enqueue(currency: 'tickets', delta: -1, reason: 'ticket_entry');

    await economy.flush();

    expect(authHeader, 'Bearer test-token');
    expect(requests, hasLength(1));
    expect((requests.first['transactions'] as List), hasLength(2));

    // applied и rejected удалены из очереди
    expect(Hive.box<String>(EconomyService.boxName).length, 0);

    // Серверные балансы применены (авторитетны)
    expect(container.read(currencyServiceProvider).diamonds, 100);
    expect(container.read(currencyServiceProvider).tickets, 3);
  });

  test('операция без результата от сервера остаётся в очереди', () async {
    final mock = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final txs = (body['transactions'] as List).cast<Map<String, dynamic>>();
      // Отвечаем только на ПЕРВУЮ операцию
      return http.Response(
        jsonEncode({
          'results': [
            {'key': txs.first['key'], 'status': 'applied'},
          ],
          'balances': {'diamonds': 100, 'tickets': 5},
        }),
        200,
      );
    });

    final container = buildContainer(mockClient: mock);
    addTearDown(container.dispose);
    final economy = container.read(economyServiceProvider);

    economy.enqueue(currency: 'diamonds', delta: -1, reason: 'spend_choice');
    economy.enqueue(currency: 'diamonds', delta: -2, reason: 'spend_choice');
    await economy.flush();

    expect(Hive.box<String>(EconomyService.boxName).length, 1);
  });

  test('сетевая ошибка — очередь не теряется', () async {
    final mock = MockClient((_) async {
      throw const SocketException('offline');
    });
    final container = buildContainer(mockClient: mock);
    addTearDown(container.dispose);
    final economy = container.read(economyServiceProvider);

    economy.enqueue(currency: 'diamonds', delta: -5, reason: 'spend_choice');
    await economy.flush();

    expect(Hive.box<String>(EconomyService.boxName).length, 1);
  });

  test('неавторизованный: flush ничего не шлёт, очередь копится', () async {
    var called = false;
    final mock = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });
    final container = buildContainer(mockClient: mock, loggedIn: false);
    addTearDown(container.dispose);
    final economy = container.read(economyServiceProvider);

    economy.enqueue(currency: 'diamonds', delta: -5, reason: 'spend_choice');
    await economy.flush();

    expect(called, isFalse);
    expect(Hive.box<String>(EconomyService.boxName).length, 1);
  });

  test('одноразовый legacy_sync: локальные алмазы > серверных → '
      'одна миграционная операция на разницу', () async {
    final requests = <Map<String, dynamic>>[];
    final mock = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      final txs = (body['transactions'] as List).cast<Map<String, dynamic>>();
      final isLegacy = txs.any((t) => t['reason'] == 'legacy_sync');
      return http.Response(
        jsonEncode({
          'results': [
            for (final tx in txs) {'key': tx['key'], 'status': 'applied'},
          ],
          'balances': {
            'diamonds': isLegacy ? 50 : 10, // после миграции сервер догнал
            'tickets': 5,
          },
        }),
        200,
      );
    });

    final container = buildContainer(mockClient: mock);
    addTearDown(container.dispose);
    final economy = container.read(economyServiceProvider);
    // Локальный стартовый баланс — 50 (defaults RemoteConfig)
    expect(container.read(currencyServiceProvider).diamonds, 50);

    economy.enqueue(currency: 'diamonds', delta: -1, reason: 'spend_choice');
    await economy.flush();

    // Два запроса: обычный батч + legacy_sync на разницу 50 - 10 = 40
    expect(requests, hasLength(2));
    final legacyTxs =
        (requests[1]['transactions'] as List).cast<Map<String, dynamic>>();
    expect(legacyTxs, hasLength(1));
    expect(legacyTxs.first['reason'], 'legacy_sync');
    expect(legacyTxs.first['delta'], 40);

    // Флаг выставлен — второй flush legacy_sync не повторяет
    expect(
        Hive.box<String>('app_settings').get('legacy_sync_done'), 'true');
    expect(container.read(currencyServiceProvider).diamonds, 50);

    requests.clear();
    economy.enqueue(currency: 'diamonds', delta: -2, reason: 'spend_choice');
    await economy.flush();
    expect(requests, hasLength(1)); // без второго legacy-запроса
  });
}
