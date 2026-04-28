import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navell/services/iap_api_client.dart';
import 'package:navell/services/iap_pending_queue.dart';

/// Фейковый источник токена.
class _FakeTokenSource implements IapAuthTokenSource {
  final String? token;
  const _FakeTokenSource(this.token);
  @override
  Future<String?> getToken() async => token;
}

/// Фейковый верификатор — программируемый ответ или исключение.
class _FakeVerifier implements IapVerifier {
  IapVerifyResult? returnResult;
  Object? throwError;
  int callCount = 0;
  final List<Map<String, String>> calls = [];

  @override
  Future<IapVerifyResult> verifyPurchase({
    required String platform,
    required String productId,
    required String receipt,
  }) async {
    callCount++;
    calls.add({
      'platform': platform,
      'productId': productId,
      'receipt': receipt,
    });
    if (throwError != null) {
      throw throwError!;
    }
    if (returnResult != null) {
      return returnResult!;
    }
    throw StateError('FakeVerifier not configured');
  }
}

/// In-memory storage для pending queue — чтобы не таскать Hive в тесты.
class _MemoryQueueStorage implements PendingQueueStorage {
  List<PendingIapPurchase> items = [];
  @override
  List<PendingIapPurchase> read() =>
      List<PendingIapPurchase>.from(items);
  @override
  Future<void> write(List<PendingIapPurchase> items) async {
    this.items = List<PendingIapPurchase>.from(items);
  }
}

void main() {
  group('IapVerifyResult.fromJson', () {
    test('parses success with newBalance and rewards', () {
      final result = IapVerifyResult.fromJson({
        'status': 'success',
        'rewards': {'diamonds': 60},
        'newBalance': {'diamonds': 110, 'tickets': 5},
      });
      expect(result.status, 'success');
      expect(result.isSuccess, isTrue);
      expect(result.rewards?['diamonds'], 60);
      expect(result.newBalance?.diamonds, 110);
      expect(result.newBalance?.tickets, 5);
      expect(result.vipExpiresAt, isNull);
    });

    test('parses VIP expiration', () {
      final iso = DateTime.utc(2026, 5, 1, 12).toIso8601String();
      final result = IapVerifyResult.fromJson({
        'status': 'success',
        'vipExpiresAt': iso,
      });
      expect(result.vipExpiresAt, DateTime.parse(iso));
    });

    test('already_claimed counts as success', () {
      final result = IapVerifyResult.fromJson({'status': 'already_claimed'});
      expect(result.isSuccess, isTrue);
    });

    test('invalid factory builds rejection', () {
      final result = IapVerifyResult.invalid(error: 'bad receipt');
      expect(result.isSuccess, isFalse);
      expect(result.status, 'invalid');
      expect(result.error, 'bad receipt');
    });
  });

  group('IapApiClient', () {
    test('200 success returns parsed result', () async {
      final mock = MockClient((req) async {
        expect(req.url.path.endsWith('/iap/verify'), isTrue);
        expect(req.headers['Authorization'], 'Bearer tok');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['platform'], 'apple');
        expect(body['productId'], 'diamonds_60');
        expect(body['receipt'], 'r1');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'newBalance': {'diamonds': 60, 'tickets': 5},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = IapApiClient(
        baseUrl: 'http://test/v1',
        auth: const _FakeTokenSource('tok'),
        httpClient: mock,
      );
      final res = await client.verifyPurchase(
        platform: 'apple',
        productId: 'diamonds_60',
        receipt: 'r1',
      );
      expect(res.isSuccess, isTrue);
      expect(res.newBalance?.diamonds, 60);
    });

    test('400 returns invalid result (not exception)', () async {
      final mock = MockClient((req) async {
        return http.Response(
          jsonEncode({'status': 'invalid', 'error': 'bad'}),
          400,
        );
      });
      final client = IapApiClient(
        baseUrl: 'http://test/v1',
        auth: const _FakeTokenSource('tok'),
        httpClient: mock,
      );
      final res = await client.verifyPurchase(
        platform: 'apple',
        productId: 'p',
        receipt: 'r',
      );
      expect(res.isSuccess, isFalse);
      expect(res.status, 'invalid');
      expect(res.error, 'bad');
    });

    test('500 throws transient exception', () async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final client = IapApiClient(
        baseUrl: 'http://test/v1',
        auth: const _FakeTokenSource('tok'),
        httpClient: mock,
      );
      expect(
        () => client.verifyPurchase(
          platform: 'apple',
          productId: 'p',
          receipt: 'r',
        ),
        throwsA(isA<IapVerifyTransientException>()),
      );
    });

    test('401 throws unauthorized exception', () async {
      final mock = MockClient((req) async => http.Response('no', 401));
      final client = IapApiClient(
        baseUrl: 'http://test/v1',
        auth: const _FakeTokenSource('tok'),
        httpClient: mock,
      );
      expect(
        () => client.verifyPurchase(
          platform: 'apple',
          productId: 'p',
          receipt: 'r',
        ),
        throwsA(isA<IapVerifyUnauthorizedException>()),
      );
    });

    test('missing token throws unauthorized', () async {
      final mock = MockClient((req) async => http.Response('', 200));
      final client = IapApiClient(
        baseUrl: 'http://test/v1',
        auth: const _FakeTokenSource(null),
        httpClient: mock,
      );
      expect(
        () => client.verifyPurchase(
          platform: 'apple',
          productId: 'p',
          receipt: 'r',
        ),
        throwsA(isA<IapVerifyUnauthorizedException>()),
      );
    });

    test('client.ClientException maps to transient', () async {
      final mock = MockClient((req) async {
        throw http.ClientException('socket dead');
      });
      final client = IapApiClient(
        baseUrl: 'http://test/v1',
        auth: const _FakeTokenSource('tok'),
        httpClient: mock,
      );
      expect(
        () => client.verifyPurchase(
          platform: 'google',
          productId: 'p',
          receipt: 'r',
        ),
        throwsA(isA<IapVerifyTransientException>()),
      );
    });
  });

  group('IapPendingQueue', () {
    test('add dedupes by purchaseId', () async {
      final storage = _MemoryQueueStorage();
      final queue = IapPendingQueue(
        verifier: _FakeVerifier(),
        storage: storage,
      );
      final p = PendingIapPurchase(
        platform: 'apple',
        productId: 'diamonds_60',
        receipt: 'r1',
        purchaseId: 'tx-1',
        timestamp: 1,
      );
      await queue.add(p);
      await queue.add(p);
      expect(storage.items, hasLength(1));
    });

    test('processAll: success removes item and calls onApply', () async {
      final storage = _MemoryQueueStorage();
      final verifier = _FakeVerifier()
        ..returnResult = IapVerifyResult(
          status: 'success',
          newBalance: const IapNewBalance(diamonds: 110, tickets: 5),
        );

      var applied = 0;
      IapVerifyResult? appliedResult;
      final queue = IapPendingQueue(
        verifier: verifier,
        storage: storage,
        onApply: (purchase, result) async {
          applied++;
          appliedResult = result;
        },
      );

      await queue.add(PendingIapPurchase(
        platform: 'apple',
        productId: 'diamonds_60',
        receipt: 'r1',
        purchaseId: 'tx-1',
        timestamp: 1,
      ));

      final report = await queue.processAll();
      expect(report.succeeded, 1);
      expect(report.stillPending, 0);
      expect(storage.items, isEmpty);
      expect(applied, 1);
      expect(appliedResult?.newBalance?.diamonds, 110);
    });

    test('processAll: invalid result drops item without onApply', () async {
      final storage = _MemoryQueueStorage();
      final verifier = _FakeVerifier()
        ..returnResult = IapVerifyResult.invalid(error: 'bad');
      var applied = 0;
      final queue = IapPendingQueue(
        verifier: verifier,
        storage: storage,
        onApply: (_, _) async => applied++,
      );

      await queue.add(PendingIapPurchase(
        platform: 'apple',
        productId: 'p',
        receipt: 'r1',
        purchaseId: 'tx-1',
        timestamp: 1,
      ));

      final report = await queue.processAll();
      expect(report.dropped, 1);
      expect(report.succeeded, 0);
      expect(applied, 0);
      expect(storage.items, isEmpty);
    });

    test('processAll: transient exception keeps item in queue', () async {
      final storage = _MemoryQueueStorage();
      final verifier = _FakeVerifier()
        ..throwError = const IapVerifyTransientException('net');
      final queue = IapPendingQueue(
        verifier: verifier,
        storage: storage,
      );

      final item = PendingIapPurchase(
        platform: 'apple',
        productId: 'p',
        receipt: 'r1',
        purchaseId: 'tx-1',
        timestamp: 1,
      );
      await queue.add(item);

      final report = await queue.processAll();
      expect(report.stillPending, 1);
      expect(report.succeeded, 0);
      expect(storage.items, hasLength(1));
      expect(storage.items.first.purchaseId, 'tx-1');
    });

    test('processAll: unauthorized keeps item in queue', () async {
      final storage = _MemoryQueueStorage();
      final verifier = _FakeVerifier()
        ..throwError = const IapVerifyUnauthorizedException('no token');
      final queue = IapPendingQueue(
        verifier: verifier,
        storage: storage,
      );

      await queue.add(PendingIapPurchase(
        platform: 'google',
        productId: 'p',
        receipt: 'r1',
        purchaseId: 'tx-2',
        timestamp: 1,
      ));

      final report = await queue.processAll();
      expect(report.stillPending, 1);
      expect(storage.items, hasLength(1));
    });

    test('processAll: mixed batch — successes drained, transients kept',
        () async {
      final storage = _MemoryQueueStorage();
      // Verifier: первый вызов success, второй throws transient.
      final verifier = _MixedVerifier([
        _MixedAnswer.result(IapVerifyResult(
          status: 'success',
          newBalance: const IapNewBalance(diamonds: 60, tickets: 5),
        )),
        _MixedAnswer.error(const IapVerifyTransientException('flap')),
      ]);
      var applied = 0;
      final queue = IapPendingQueue(
        verifier: verifier,
        storage: storage,
        onApply: (_, _) async => applied++,
      );

      await queue.add(PendingIapPurchase(
        platform: 'apple',
        productId: 'a',
        receipt: 'r1',
        purchaseId: 'tx-1',
        timestamp: 1,
      ));
      await queue.add(PendingIapPurchase(
        platform: 'apple',
        productId: 'b',
        receipt: 'r2',
        purchaseId: 'tx-2',
        timestamp: 2,
      ));

      final report = await queue.processAll();
      expect(report.total, 2);
      expect(report.succeeded, 1);
      expect(report.stillPending, 1);
      expect(applied, 1);
      expect(storage.items, hasLength(1));
      expect(storage.items.first.purchaseId, 'tx-2');
    });
  });
}

/// Хелпер: верификатор, отдающий разные ответы по очереди.
class _MixedAnswer {
  final IapVerifyResult? result;
  final Object? error;
  _MixedAnswer.result(this.result) : error = null;
  _MixedAnswer.error(this.error) : result = null;
}

class _MixedVerifier implements IapVerifier {
  final List<_MixedAnswer> _answers;
  int _idx = 0;
  _MixedVerifier(this._answers);

  @override
  Future<IapVerifyResult> verifyPurchase({
    required String platform,
    required String productId,
    required String receipt,
  }) async {
    final ans = _answers[_idx++];
    if (ans.error != null) throw ans.error!;
    return ans.result!;
  }
}
