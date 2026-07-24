import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navell/models/novel.dart';
import 'package:navell/services/http_client.dart';
import 'package:navell/services/rating_service.dart';

void main() {
  ProviderContainer buildContainer({
    required MockClient mock,
    bool loggedIn = true,
  }) {
    final container = ProviderContainer(overrides: [
      httpClientProvider.overrideWith(
        (ref) => ApiHttpClient(
          tokenProvider: () => loggedIn ? 'test-token' : null,
          refresher: () async => false,
          httpClient: mock,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('RatingService (волна 3, чеклист 4)', () {
    test('rate: POST /novels/:id/rate c value, парсит сводку', () async {
      String? path;
      Map<String, dynamic>? body;
      String? authHeader;
      final mock = MockClient((request) async {
        path = request.url.path;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        authHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({'averageRating': 4.5, 'ratingCount': 12}),
          200,
        );
      });
      final container = buildContainer(mock: mock);

      final summary =
          await container.read(ratingServiceProvider).rate('demo', 4);

      expect(path, endsWith('/novels/demo/rate'));
      expect(body?['value'], 4);
      expect(authHeader, 'Bearer test-token');
      expect(summary?.averageRating, 4.5);
      expect(summary?.ratingCount, 12);
    });

    test('rate гостем → RatingAuthRequiredException (предложение войти)',
        () async {
      final mock = MockClient((_) async => http.Response('{}', 200));
      final container = buildContainer(mock: mock, loggedIn: false);

      expect(
        () => container.read(ratingServiceProvider).rate('demo', 5),
        throwsA(isA<RatingAuthRequiredException>()),
      );
    });

    test('submitReview: POST текст, 201 → true, 409 (дубликат) → true',
        () async {
      Map<String, dynamic>? body;
      var status = 201;
      final mock = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', status);
      });
      final container = buildContainer(mock: mock);
      final service = container.read(ratingServiceProvider);

      expect(await service.submitReview('demo', '  Отличная история!  '),
          isTrue);
      expect(body?['text'], 'Отличная история!'); // триммится

      status = 409;
      expect(await service.submitReview('demo', 'Ещё раз'), isTrue);

      status = 400;
      expect(await service.submitReview('demo', 'Плохой запрос'), isFalse);
    });

    test('submitReview: пустой и >500 символов отклоняются без запроса',
        () async {
      var requests = 0;
      final mock = MockClient((_) async {
        requests++;
        return http.Response('{}', 201);
      });
      final container = buildContainer(mock: mock);
      final service = container.read(ratingServiceProvider);

      expect(await service.submitReview('demo', '   '), isFalse);
      expect(await service.submitReview('demo', 'a' * 501), isFalse);
      expect(requests, 0);
    });

    test('fetchReviews: парсит список отзывов', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/novels/demo/reviews'));
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'id': 'r1',
                'text': 'Супер!',
                'createdAt': '2026-07-01T10:00:00.000Z',
                'user': {'displayName': 'Аня'},
              },
              {'id': 'r2', 'text': 'Норм', 'user': {}},
            ],
          }),
          200,
          // Кириллица в body требует явной utf-8 кодировки в MockClient
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final container = buildContainer(mock: mock);

      final reviews =
          await container.read(ratingServiceProvider).fetchReviews('demo');

      expect(reviews, hasLength(2));
      expect(reviews[0].authorName, 'Аня');
      expect(reviews[0].text, 'Супер!');
      expect(reviews[0].createdAt, isNotNull);
      expect(reviews[1].authorName, 'Читатель'); // fallback
    });

    test('fetchSummary: берёт averageRating/ratingCount из деталей новеллы',
        () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/novels/demo'));
        return http.Response(
          jsonEncode({
            'novel': {'id': 'demo', 'averageRating': 4.8, 'ratingCount': 3},
          }),
          200,
        );
      });
      final container = buildContainer(mock: mock);

      final summary =
          await container.read(ratingServiceProvider).fetchSummary('demo');

      expect(summary?.averageRating, 4.8);
      expect(summary?.ratingCount, 3);
    });

    test('сетевая ошибка → null/[] без исключений', () async {
      final mock = MockClient((_) async => http.Response('oops', 500));
      final container = buildContainer(mock: mock);
      final service = container.read(ratingServiceProvider);

      expect(await service.fetchSummary('demo'), isNull);
      expect(await service.fetchReviews('demo'), isEmpty);
      expect(await service.rate('demo', 3), isNull);
      expect(await service.submitReview('demo', 'x'), isFalse);
    });
  });

  group('NovelMeta.isPublished (спека 4.9)', () {
    test('отсутствие поля → true (обычный каталог)', () {
      final meta = NovelMeta.fromJson(const {
        'id': 'demo',
        'title': 'Demo',
        'description': '',
        'author': 'a',
      });
      expect(meta.isPublished, isTrue);
    });

    test('isPublished: false парсится (тест-режим админа)', () {
      final meta = NovelMeta.fromJson(const {
        'id': 'draft',
        'title': 'Draft',
        'description': '',
        'author': 'a',
        'isPublished': false,
      });
      expect(meta.isPublished, isFalse);
      // Раунд-трип сохраняет флаг
      expect(NovelMeta.fromJson(meta.toJson()).isPublished, isFalse);
    });
  });
}
