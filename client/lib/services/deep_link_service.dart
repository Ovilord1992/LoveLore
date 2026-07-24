import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/novel.dart';
import '../screens/novel_detail_screen.dart';
import 'http_client.dart';
import 'novel_loader.dart';

/// Провайдер диплинков (спека 4.10): `amoria://novel/<id>` → экран деталей
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Допустимый id новеллы — как NOVEL_ID_RE на сервере
final RegExp _novelIdRe = RegExp(r'^[a-z0-9_-]{1,64}$');

/// Чистая функция парсинга диплинка. Возвращает id новеллы для ссылок вида
/// `amoria://novel/<id>` (или null для любых других/невалидных ссылок).
String? parseNovelDeepLink(Uri uri) {
  if (uri.scheme != 'amoria') return null;
  if (uri.host != 'novel') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 1) return null;
  final id = segments.first;
  if (!_novelIdRe.hasMatch(id)) return null;
  return id;
}

/// Обработка диплинков: холодный старт (getInitialLink) и рантайм-ссылки
/// (uriLinkStream). Невалидный или неизвестный id игнорируется молча.
class DeepLinkService {
  final Ref _ref;
  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;

  DeepLinkService(this._ref);

  /// Вызывается один раз после инициализации приложения (первый кадр).
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    try {
      final appLinks = AppLinks();
      // Холодный старт: приложение открыто по ссылке
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        // ignore: discarded_futures
        _handleUri(initial);
      }
      // Рантайм: ссылка пришла в работающее приложение
      _sub = appLinks.uriLinkStream.listen(
        (uri) {
          // ignore: discarded_futures
          _handleUri(uri);
        },
        onError: (Object e) => debugPrint('[DeepLink] stream error: $e'),
      );
    } catch (e) {
      // Плагин недоступен (тесты/десктоп) — фича просто выключена
      debugPrint('[DeepLink] init failed: $e');
    }
  }

  Future<void> _handleUri(Uri uri) async {
    final novelId = parseNovelDeepLink(uri);
    if (novelId == null) return;

    final meta = await _resolveNovel(novelId);
    if (meta == null) return; // неизвестный id — игнор

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => NovelDetailScreen(novel: meta)),
    );
  }

  /// Резолв меты: локально (assets/скачанные) → сервер GET /novels/:id
  Future<NovelMeta?> _resolveNovel(String novelId) async {
    try {
      return await _ref.read(novelLoaderProvider).loadNovelMeta(novelId);
    } catch (_) {}
    try {
      final client = _ref.read(httpClientProvider);
      final response =
          await client.get('/novels/$novelId', auth: true, optionalAuth: true);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final novelJson = data['novel'] as Map<String, dynamic>?;
      if (novelJson == null) return null;
      return NovelMeta.fromJson(novelJson);
    } catch (e) {
      debugPrint('[DeepLink] novel resolve failed: $e');
      return null;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
