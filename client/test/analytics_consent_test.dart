import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navell/services/analytics_service.dart';
import 'package:navell/services/consent_service.dart';
import 'package:navell/services/http_client.dart';

void main() {
  late Directory tempDir;

  const boxes = ['app_settings', 'analytics_queue'];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('analytics_consent_test');
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

  ProviderContainer buildContainer(MockClient mock) {
    final container = ProviderContainer(overrides: [
      httpClientProvider.overrideWith(
        (ref) => ApiHttpClient(
          tokenProvider: () => null,
          refresher: () async => false,
          httpClient: mock,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('Consent-гейт аналитики (спека 4.10)', () {
    test('согласие включено (default): события логируются и отправляются',
        () async {
      var requests = 0;
      List<dynamic>? sentEvents;
      final mock = MockClient((request) async {
        requests++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sentEvents = body['events'] as List<dynamic>;
        return http.Response('{}', 200);
      });
      final container = buildContainer(mock);
      final analytics = container.read(analyticsServiceProvider);

      analytics.log('session_start');
      expect(Hive.box<String>('analytics_queue').length, 1);

      await analytics.flush();
      expect(requests, 1);
      expect(sentEvents, hasLength(1));
      // Очередь очищена после успешной отправки
      expect(Hive.box<String>('analytics_queue').length, 0);
    });

    test('согласие выключено: log не пополняет очередь', () async {
      Hive.box<String>('app_settings')
          .put(ConsentService.analyticsKey, 'false');
      final mock = MockClient((_) async => http.Response('{}', 200));
      final container = buildContainer(mock);
      final analytics = container.read(analyticsServiceProvider);

      analytics.log('session_start');
      analytics.log('novel_start', {'novelId': 'x'});

      expect(Hive.box<String>('analytics_queue').length, 0);
    });

    test('согласие выключено: flush не отправляет накопленное', () async {
      // Событие попало в очередь, ПОКА согласие было включено
      var requests = 0;
      final mock = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      final container = buildContainer(mock);
      final analytics = container.read(analyticsServiceProvider);
      analytics.log('session_start');
      expect(Hive.box<String>('analytics_queue').length, 1);

      // Пользователь выключил согласие → flush молчит
      Hive.box<String>('app_settings')
          .put(ConsentService.analyticsKey, 'false');
      await analytics.flush();
      expect(requests, 0);
    });

    test('повторное включение согласия возобновляет логирование', () async {
      final settings = Hive.box<String>('app_settings');
      settings.put(ConsentService.analyticsKey, 'false');
      final mock = MockClient((_) async => http.Response('{}', 200));
      final container = buildContainer(mock);
      final analytics = container.read(analyticsServiceProvider);

      analytics.log('a');
      expect(Hive.box<String>('analytics_queue').length, 0);

      settings.put(ConsentService.analyticsKey, 'true');
      analytics.log('b');
      expect(Hive.box<String>('analytics_queue').length, 1);
    });
  });

  group('ConsentService', () {
    test('дефолты: возраст не подтверждён, аналитика/реклама включены', () {
      final service = ConsentService();
      expect(service.state.ageConfirmed, isFalse);
      expect(service.state.analytics, isTrue);
      expect(service.state.adsPersonalized, isTrue);
      expect(ConsentService.analyticsAllowed(), isTrue);
      expect(ConsentService.adsPersonalizationAllowed(), isTrue);
      service.dispose();
    });

    test('acceptConsents сохраняет выбор в app_settings', () {
      final service = ConsentService();
      service.acceptConsents(analytics: false, adsPersonalized: false);
      expect(service.state.ageConfirmed, isTrue);

      final box = Hive.box<String>('app_settings');
      expect(box.get(ConsentService.ageConfirmedKey), 'true');
      expect(box.get(ConsentService.analyticsKey), 'false');
      expect(box.get(ConsentService.adsPersonalizedKey), 'false');
      expect(ConsentService.analyticsAllowed(), isFalse);
      expect(ConsentService.adsPersonalizationAllowed(), isFalse);
      service.dispose();
    });
  });
}
