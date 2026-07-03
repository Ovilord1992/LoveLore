import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Сервис управления аудио — фоновая музыка и звуковые эффекты
class AudioService {
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  String? _currentBgTrack;
  double _bgVolume = 0.7;
  double _sfxVolume = 1.0;
  bool _isMuted = false;

  double get bgVolume => _bgVolume;
  double get sfxVolume => _sfxVolume;
  bool get isMuted => _isMuted;

  /// Играть фоновую музыку из bundle-ассета (с плавным переходом)
  Future<void> playBgMusic(String assetPath) async {
    await _playBg(assetPath, isFile: false);
  }

  /// Играть фоновую музыку из файла новеллы в Documents.
  /// [relativePath] — путь относительно `Documents/novels/`, напр.
  /// `my_novel/music/theme.mp3`.
  Future<void> playBgMusicFile(String relativePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/novels/$relativePath';
      if (!File(path).existsSync()) return;
      await _playBg(path, isFile: true);
    } catch (_) {}
  }

  Future<void> _playBg(String source, {required bool isFile}) async {
    if (_currentBgTrack == source) return;

    try {
      // Плавное затухание текущего трека
      if (_bgPlayer.playing) {
        await _fadeOut(_bgPlayer);
      }

      if (isFile) {
        await _bgPlayer.setFilePath(source);
      } else {
        await _bgPlayer.setAsset(source);
      }
      // Метку трека выставляем ТОЛЬКО после успешной загрузки, иначе при
      // ошибке загрузки early-return навсегда заблокирует повторный запуск.
      _currentBgTrack = source;
      _bgPlayer.setLoopMode(LoopMode.one);
      _bgPlayer.setVolume(_isMuted ? 0 : _bgVolume);
      _bgPlayer.play();

      // Плавное нарастание
      if (!_isMuted) {
        await _fadeIn(_bgPlayer, _bgVolume);
      }
    } catch (_) {
      // Файл может отсутствовать — не критично
    }
  }

  /// Остановить фоновую музыку
  Future<void> stopBgMusic() async {
    if (_bgPlayer.playing) {
      await _fadeOut(_bgPlayer);
      await _bgPlayer.stop();
    }
    _currentBgTrack = null;
  }

  /// Играть звуковой эффект из bundle-ассета
  Future<void> playSfx(String assetPath) async {
    try {
      await _sfxPlayer.setAsset(assetPath);
      _sfxPlayer.setVolume(_isMuted ? 0 : _sfxVolume);
      _sfxPlayer.play();
    } catch (_) {}
  }

  /// Играть звуковой эффект из файла новеллы в Documents.
  /// [relativePath] — путь относительно `Documents/novels/`.
  Future<void> playSfxFile(String relativePath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/novels/$relativePath';
      if (!File(path).existsSync()) return;
      await _sfxPlayer.setFilePath(path);
      _sfxPlayer.setVolume(_isMuted ? 0 : _sfxVolume);
      _sfxPlayer.play();
    } catch (_) {}
  }

  /// Установить громкость фоновой музыки (0.0 - 1.0)
  void setBgVolume(double volume) {
    _bgVolume = volume.clamp(0.0, 1.0);
    if (!_isMuted) _bgPlayer.setVolume(_bgVolume);
  }

  /// Установить громкость эффектов (0.0 - 1.0)
  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    if (!_isMuted) _sfxPlayer.setVolume(_sfxVolume);
  }

  /// Включить/выключить звук
  void toggleMute() {
    _isMuted = !_isMuted;
    _bgPlayer.setVolume(_isMuted ? 0 : _bgVolume);
    _sfxPlayer.setVolume(_isMuted ? 0 : _sfxVolume);
  }

  Future<void> _fadeOut(AudioPlayer player, {int durationMs = 500}) async {
    final steps = 10;
    final stepDuration = Duration(milliseconds: durationMs ~/ steps);
    final startVolume = player.volume;

    for (int i = steps; i >= 0; i--) {
      player.setVolume(startVolume * i / steps);
      await Future.delayed(stepDuration);
    }
  }

  Future<void> _fadeIn(AudioPlayer player, double targetVolume,
      {int durationMs = 500}) async {
    final steps = 10;
    final stepDuration = Duration(milliseconds: durationMs ~/ steps);

    for (int i = 0; i <= steps; i++) {
      player.setVolume(targetVolume * i / steps);
      await Future.delayed(stepDuration);
    }
  }

  void dispose() {
    _bgPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
