import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import '../engine/scene_engine.dart';
import '../screens/consent_screen.dart';
import '../screens/library_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/analytics_service.dart';
import '../services/consent_service.dart';
import '../services/deep_link_service.dart';
import '../services/economy_service.dart';
import '../services/iap_service.dart';
import '../services/locale_service.dart';
import '../services/notification_service.dart';
import '../services/remote_config_service.dart';
import '../services/save_service.dart';
import '../services/settings_service.dart';
import '../services/vip_service.dart';

/// Глобальный ключ навигатора — используется диплинками (спека 4.10)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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
      // v2.1 (спека 4.6): experiment_exposure по применённым экспериментам —
      // один раз за сессию на эксперимент.
      ref
          .read(remoteConfigProvider.notifier)
          .attachExposureLogger(analytics.log);
      analytics.flush();
      ref.read(economyServiceProvider).flush();
      // Волна 3 (4.10): при открытии отменяем запланированные уведомления
      unawaited(ref.read(notificationServiceProvider.notifier).onAppResumed());
      // Волна 3 (4.10): диплинки amoria://novel/<id> — холодный старт + рантайм
      unawaited(ref.read(deepLinkServiceProvider).init(appNavigatorKey));
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
      // Волна 3 (4.10): планируем локальные напоминания на время отсутствия
      unawaited(ref.read(notificationServiceProvider.notifier).onAppPaused());
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
      // Волна 3 (4.10): вернулись — отменяем запланированные напоминания
      unawaited(ref.read(notificationServiceProvider.notifier).onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(settingsServiceProvider);
    final consent = ref.watch(consentServiceProvider);
    // Спека 4.10: экран согласий (16+, аналитика, реклама) — ДО онбординга
    final Widget home;
    if (!consent.ageConfirmed) {
      home = const ConsentScreen();
    } else if (settings.hasSeenOnboarding) {
      home = const LibraryScreen();
    } else {
      home = const OnboardingScreen();
    }
    return MaterialApp(
      title: 'Amoria',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.flutterThemeMode,
      locale: Locale(locale.name),
      home: home,
    );
  }
}
