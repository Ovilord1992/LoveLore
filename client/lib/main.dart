import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<String>('game_saves'),
    Hive.openBox<String>('app_settings'),
    Hive.openBox<String>('app_locale'),
    Hive.openBox<String>('user_profile'),
    Hive.openBox<String>('currency'),
    Hive.openBox<String>('wardrobe'),
  ]);

  await AdService.initialize();

  runApp(
    const ProviderScope(
      child: NavellApp(),
    ),
  );
}
