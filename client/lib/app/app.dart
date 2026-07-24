import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import '../engine/scene_engine.dart';
import '../screens/library_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/analytics_service.dart';
import '../services/economy_service.dart';
import '../services/iap_service.dart';
import '../services/locale_service.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
import '../services/vip_service.dart';

class NavellApp extends ConsumerStatefulWidget {
  const NavellApp({super.key});

  @override
  ConsumerState<NavellApp> createState() => _NavellAppState();
}

class _NavellAppState extends ConsumerState<NavellApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // VIP-перки при входе: пересчёт истечения и начисление ежедневных алмазов.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vip = ref.read(vipServiceProvider.notifier);
      vip.refresh();
      vip.collectDailyDiamonds();
      // Аналитика: старт сессии + отправка накопленных очередей (спека 2.2/2.3)
      final analytics = ref.read(analyticsServiceProvider);
      analytics.log('session_start');
      analytics.flush();
      ref.read(economyServiceProvider).flush();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // ОС может убить приложение в фоне — сохраняем текущий прогресс игры,
      // чтобы не потерять сессию (выборы, потраченные алмазы, переменные).
      final gameState = ref.read(sceneEngineProvider);
      if (gameState != null) {
        ref.read(saveServiceProvider.notifier).saveGame(gameState);
      }
      // Флашим очереди аналитики и экономики перед возможным kill.
      ref.read(analyticsServiceProvider).onAppPaused();
      ref.read(economyServiceProvider).flush();
    }
    if (state == AppLifecycleState.resumed) {
      // Повторяем IAP-верификацию для покупок, не подтверждённых из-за
      // оффлайн / 5xx во время покупки.
      ref.read(iapServiceProvider.notifier).processPendingNow();
      // Пересчитываем VIP и выдаём ежедневные алмазы за новый день.
      final vip = ref.read(vipServiceProvider.notifier);
      vip.refresh();
      vip.collectDailyDiamonds();
      // Восстановление сети/возврат в приложение — пробуем отдать очереди.
      ref.read(economyServiceProvider).flush();
      ref.read(analyticsServiceProvider).flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(settingsServiceProvider);
    return MaterialApp(
      title: 'Amoria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.flutterThemeMode,
      locale: Locale(locale.name),
      home: settings.hasSeenOnboarding
          ? const LibraryScreen()
          : const OnboardingScreen(),
    );
  }
}
