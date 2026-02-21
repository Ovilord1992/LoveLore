import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:navell/services/settings_service.dart';

void main() {
  group('AppSettings', () {
    test('default values', () {
      const settings = AppSettings();
      expect(settings.textSpeed, 0.5);
      expect(settings.themeMode, 2); // dark default
      expect(settings.autoPlay, false);
    });

    test('themeMode to ThemeMode conversion', () {
      expect(const AppSettings(themeMode: 0).flutterThemeMode, ThemeMode.system);
      expect(const AppSettings(themeMode: 1).flutterThemeMode, ThemeMode.light);
      expect(const AppSettings(themeMode: 2).flutterThemeMode, ThemeMode.dark);
    });

    test('copyWith creates correct copy', () {
      const original = AppSettings();
      final modified = original.copyWith(themeMode: 1, textSpeed: 0.8);
      expect(modified.themeMode, 1);
      expect(modified.textSpeed, 0.8);
      expect(modified.bgMusicVolume, original.bgMusicVolume);
    });

    test('JSON serialization roundtrip', () {
      const original = AppSettings(themeMode: 1, textSpeed: 0.7, isMuted: true);
      final json = original.toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.themeMode, 1);
      expect(restored.textSpeed, 0.7);
      expect(restored.isMuted, true);
    });

    test('charDelayMs calculation', () {
      expect(const AppSettings(textSpeed: 0.0).charDelayMs, 0);
      expect(const AppSettings(textSpeed: 0.5).charDelayMs, 30);
      expect(const AppSettings(textSpeed: 1.0).charDelayMs, 60);
    });
  });
}
