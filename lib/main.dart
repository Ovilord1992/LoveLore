import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/app.dart';
import 'services/save_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SaveService().init();
  // Открываем все Hive-боксы заранее
  await Hive.openBox<String>('app_settings');
  await Hive.openBox<String>('app_locale');

  runApp(
    const ProviderScope(
      child: NavellApp(),
    ),
  );
}
