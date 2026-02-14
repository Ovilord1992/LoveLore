import 'package:flutter/material.dart';
import 'theme.dart';
import '../screens/library_screen.dart';

class NavellApp extends StatelessWidget {
  const NavellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navell',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LibraryScreen(),
    );
  }
}
