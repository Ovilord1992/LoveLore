import 'package:flutter_test/flutter_test.dart';
import 'package:navell/app/theme.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    // Theme getters trigger Google Fonts loading which requires async handling.
    // Use testWidgets to properly manage the async font loading lifecycle.
    testWidgets('dark theme has correct primary color', (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.primaryColor, const Color(0xFFE91E63));
    });

    testWidgets('dark theme has correct scaffold background', (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A1A2E));
    });

    testWidgets('light theme has correct scaffold background', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F5FA));
    });

    testWidgets('dark theme brightness is dark', (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('light theme brightness is light', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
    });

    test('color constants are defined', () {
      expect(AppTheme.primary, const Color(0xFFE91E63));
      expect(AppTheme.secondary, const Color(0xFF9C27B0));
      expect(AppTheme.bgDark, const Color(0xFF1A1A2E));
      expect(AppTheme.surfaceDark, const Color(0xFF16213E));
      expect(AppTheme.deepDark, const Color(0xFF0F0F1E));
      expect(AppTheme.cyan, const Color(0xFF00BCD4));
      expect(AppTheme.success, const Color(0xFF4CAF50));
    });

    test('gradient has correct colors', () {
      expect(AppTheme.accentGradient.colors, [AppTheme.primary, AppTheme.secondary]);
    });
  });
}
