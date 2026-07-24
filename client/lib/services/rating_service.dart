import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_client.dart';

/// Провайдер сервиса оценок и отзывов (волна 3, чеклист 4)
final ratingServiceProvider = Provider<RatingService>((ref) {
  return RatingService(ref);
});

/// Сводка рейтинга новеллы (из GET /v1/novels/:id)
class RatingSummary {
  final double averageRating;
  final int ratingCount;

  const RatingSummary({this.averageRating = 0, this.ratingCount = 0});

  factory RatingSummary.fromNovelJson(Map<String, dynamic> json) =>
      RatingSummary(
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      );
}

/// Отзыв (из GET /v1/novels/:id/reviews)
class NovelReview {
  final String id;
  final String text;
  final DateTime? createdAt;
  final String authorName;

  const NovelReview({
    required this.id,
    required this.text,
    this.createdAt,
    this.authorName = 'Читатель',
  });

  factory NovelReview.fromJson(Map<String, dynamic> json) => NovelReview(
        id: '${json['id']}',
        text: json['text'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse('${json['createdAt']}')
            : null,
        authorName: ((json['user'] as Map<String, dynamic>?)?['displayName']
                as String?) ??
            'Читатель',
      );
}

/// Требуется вход (гость пытается оценить/оставить отзыв)
class RatingAuthRequiredException implements Exception {
  const RatingAuthRequiredException();
}

/// Оценки и отзывы: GET/POST /v1/novels/:id/{rate,rating,reviews}.
/// GET-ручки работают и для гостя; POST требуют авторизацию — при её
/// отсутствии бросается [RatingAuthRequiredException] (UI предлагает войти).
class RatingService {
  final Ref _ref;

  RatingService(this._ref);

  ApiHttpClient get _client => _ref.read(httpClientProvider);

  /// Средний рейтинг и количество оценок — из деталей новеллы
  Future<RatingSummary?> fetchSummary(String novelId) async {
    try {
      final response =
          await _client.get('/novels/$novelId', optionalAuth: true);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final novel = data['novel'] as Map<String, dynamic>?;
      if (novel == null) return null;
      return RatingSummary.fromNovelJson(novel);
    } catch (e) {
      debugPrint('[Rating] summary fetch failed: $e');
      return null;
    }
  }

  /// Список одобренных отзывов
  Future<List<NovelReview>> fetchReviews(String novelId) async {
    try {
      final response =
          await _client.get('/novels/$novelId/reviews', optionalAuth: true);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['reviews'] as List? ?? [];
      return list
          .map((j) => NovelReview.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Rating] reviews fetch failed: $e');
      return [];
    }
  }

  /// Моя оценка (или null, если не ставил / гость)
  Future<int?> fetchMyRating(String novelId) async {
    try {
      final response = await _client.get('/novels/$novelId/rating');
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['rating'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Поставить оценку 1..5. Возвращает обновлённую сводку.
  /// Гость → [RatingAuthRequiredException].
  Future<RatingSummary?> rate(String novelId, int value) async {
    assert(value >= 1 && value <= 5);
    try {
      final response = await _client.post(
        '/novels/$novelId/rate',
        body: {'value': value},
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RatingSummary(
        averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
        ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      );
    } on ApiUnauthorizedException {
      throw const RatingAuthRequiredException();
    } catch (e) {
      debugPrint('[Rating] rate failed: $e');
      return null;
    }
  }

  /// Оставить текстовый отзыв (≤500 символов). true — принят (или уже был).
  /// Гость → [RatingAuthRequiredException].
  Future<bool> submitReview(String novelId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 500) return false;
    try {
      final response = await _client.post(
        '/novels/$novelId/reviews',
        body: {'text': trimmed},
      );
      // 409 — отзыв уже существует: для UX считаем успехом
      return response.statusCode == 201 || response.statusCode == 409;
    } on ApiUnauthorizedException {
      throw const RatingAuthRequiredException();
    } catch (e) {
      debugPrint('[Rating] review submit failed: $e');
      return false;
    }
  }
}
