import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import '../screens/library_screen.dart';
import '../services/locale_service.dart';

class NavellApp extends ConsumerWidget {
  const NavellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'Amoria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: Locale(locale.name),
      home: const LibraryScreen(),
    );
  }
}
