import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import '../screens/library_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/iap_service.dart';
import '../services/locale_service.dart';
import '../services/settings_service.dart';

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // При возврате из фона — повторяем IAP-верификацию для покупок,
    // которые не подтвердились из-за оффлайн / 5xx во время покупки.
    if (state == AppLifecycleState.resumed) {
      ref.read(iapServiceProvider.notifier).processPendingNow();
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
