import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final settingsServiceProvider =
    StateNotifierProvider<SettingsService, AppSettings>((ref) {
  return SettingsService();
});

/// Настройки приложения
class AppSettings {
  final double textSpeed; // 0.0 (мгновенно) - 1.0 (медленно)
  final double bgMusicVolume;
  final double sfxVolume;
  final bool autoPlay;
  final int autoPlayDelay; // секунды
  final bool isMuted;
  final int themeMode; // 0=system, 1=light, 2=dark

  const AppSettings({
    this.textSpeed = 0.5,
    this.bgMusicVolume = 0.7,
    this.sfxVolume = 1.0,
    this.autoPlay = false,
    this.autoPlayDelay = 3,
    this.isMuted = false,
    this.themeMode = 2, // dark by default
  });

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case 1: return ThemeMode.light;
      case 2: return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  AppSettings copyWith({
    double? textSpeed,
    double? bgMusicVolume,
    double? sfxVolume,
    bool? autoPlay,
    int? autoPlayDelay,
    bool? isMuted,
    int? themeMode,
  }) {
    return AppSettings(
      textSpeed: textSpeed ?? this.textSpeed,
      bgMusicVolume: bgMusicVolume ?? this.bgMusicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      autoPlay: autoPlay ?? this.autoPlay,
      autoPlayDelay: autoPlayDelay ?? this.autoPlayDelay,
      isMuted: isMuted ?? this.isMuted,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'textSpeed': textSpeed,
        'bgMusicVolume': bgMusicVolume,
        'sfxVolume': sfxVolume,
        'autoPlay': autoPlay,
        'autoPlayDelay': autoPlayDelay,
        'isMuted': isMuted,
        'themeMode': themeMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        textSpeed: (json['textSpeed'] as num?)?.toDouble() ?? 0.5,
        bgMusicVolume: (json['bgMusicVolume'] as num?)?.toDouble() ?? 0.7,
        sfxVolume: (json['sfxVolume'] as num?)?.toDouble() ?? 1.0,
        autoPlay: json['autoPlay'] as bool? ?? false,
        autoPlayDelay: json['autoPlayDelay'] as int? ?? 3,
        isMuted: json['isMuted'] as bool? ?? false,
        themeMode: json['themeMode'] as int? ?? 2,
      );

  /// Задержка печати одного символа в миллисекундах
  int get charDelayMs => (textSpeed * 60).toInt().clamp(0, 60);
}

class SettingsService extends StateNotifier<AppSettings> {
  static const _boxName = 'app_settings';
  static const _key = 'settings';

  SettingsService() : super(const AppSettings()) {
    _loadSync();
  }

  void setTextSpeed(double speed) {
    state = state.copyWith(textSpeed: speed);
    _save();
  }

  void setBgMusicVolume(double volume) {
    state = state.copyWith(bgMusicVolume: volume);
    _save();
  }

  void setSfxVolume(double volume) {
    state = state.copyWith(sfxVolume: volume);
    _save();
  }

  void toggleAutoPlay() {
    state = state.copyWith(autoPlay: !state.autoPlay);
    _save();
  }

  void setAutoPlayDelay(int seconds) {
    state = state.copyWith(autoPlayDelay: seconds);
    _save();
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
    _save();
  }

  void setThemeMode(int mode) {
    state = state.copyWith(themeMode: mode);
    _save();
  }

  Future<void> _save() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void _loadSync() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_key);
      if (data != null) {
        state = AppSettings.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }
}
