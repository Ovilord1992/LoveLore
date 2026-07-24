import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'services/ad_service.dart';
import 'services/remote_config_service.dart';

/// Открыть Hive-бокс с восстановлением при коррупции. Если файл бокса
/// повреждён (kill во время записи, заполненный диск), без recovery
/// приложение падало бы на старте при каждом запуске («кирпич»).
Future<void> _openBoxSafe(String name) async {
  try {
    await Hive.openBox<String>(name);
  } catch (e) {
    debugPrint('[Hive] Box "$name" corrupted ($e) — recreating');
    try {
      await Hive.deleteBoxFromDisk(name);
      await Hive.openBox<String>(name);
    } catch (e2) {
      debugPrint('[Hive] Failed to recover box "$name": $e2');
      rethrow;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    _openBoxSafe('game_saves'),
    _openBoxSafe('app_settings'),
    _openBoxSafe('app_locale'),
    _openBoxSafe('user_profile'),
    _openBoxSafe('currency'),
    _openBoxSafe('wardrobe'),
    // v2: очередь экономики (леджер), очередь аналитики, прогресс чтения
    _openBoxSafe('economy_queue'),
    _openBoxSafe('analytics_queue'),
    _openBoxSafe('reading_progress'),
  ]);

  // Реклама не критична для старта — инициализируем в фоне, не блокируя
  // запуск приложения (иначе на медленной сети — долгий белый экран).
  unawaited(AdService.initialize());

  // Загружаем Remote Config ДО запуска приложения (с таймаутом 5с)
  final configService = RemoteConfigService();
  await configService.fetch();
  debugPrint('[RemoteConfig] v=${configService.config.version}, '
      'maxTickets=${configService.config.economy.maxTickets}, '
      'refill=${configService.config.economy.ticketRefillMinutes}min');

  runApp(
    ProviderScope(
      overrides: [
        remoteConfigProvider.overrideWith((_) => configService),
      ],
      child: const NavellApp(),
    ),
  );
}
