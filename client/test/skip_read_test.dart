import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navell/services/reading_progress_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('skip_read_test');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(ReadingProgressService.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>(ReadingProgressService.boxName).clear();
  });

  group('Skip-read: маркировка/проверка прочитанного', () {
    test('ключ события — sceneId:eventIndex', () {
      expect(ReadingProgressService.entryKey('scene_1', 4), 'scene_1:4');
    });

    test('markRead → isRead', () {
      final service = ReadingProgressService();
      expect(service.isRead('novel1', 'scene_1', 0), isFalse);
      service.markRead('novel1', 'scene_1', 0);
      expect(service.isRead('novel1', 'scene_1', 0), isTrue);
      // Соседний индекс не помечен
      expect(service.isRead('novel1', 'scene_1', 1), isFalse);
    });

    test('прогресс раздельный per novel', () {
      final service = ReadingProgressService();
      service.markRead('novel1', 'scene_1', 0);
      expect(service.isRead('novel2', 'scene_1', 0), isFalse);
    });

    test('повторный markRead не дублирует запись', () {
      final service = ReadingProgressService();
      service.markRead('novel1', 'scene_1', 0);
      service.markRead('novel1', 'scene_1', 0);
      final raw =
          Hive.box<String>(ReadingProgressService.boxName).get('novel1')!;
      expect('scene_1:0'.allMatches(raw).length, 1);
    });

    test('персистентность: новый инстанс читает из Hive', () {
      ReadingProgressService().markRead('novel1', 'scene_2', 3);
      final fresh = ReadingProgressService();
      expect(fresh.isRead('novel1', 'scene_2', 3), isTrue);
      expect(fresh.isRead('novel1', 'scene_2', 4), isFalse);
    });

    test('reset очищает прогресс новеллы', () {
      final service = ReadingProgressService();
      service.markRead('novel1', 'scene_1', 0);
      service.reset('novel1');
      expect(service.isRead('novel1', 'scene_1', 0), isFalse);
    });
  });
}
