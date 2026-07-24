import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navell/models/game_state.dart';
import 'package:navell/services/save_service.dart';

GameState _state(String novelId, {required DateTime lastPlayed, String scene = 's1'}) =>
    GameState(
      novelId: novelId,
      currentChapterId: 'chapter_1',
      currentSceneId: scene,
      lastPlayed: lastPlayed,
    );

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('save_slots_test');
    Hive.init(tempDir.path);
    await Hive.openBox<String>('game_saves');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('game_saves').clear();
  });

  group('Сейв-слоты (спека, часть 3)', () {
    test('формат ключа слота <novelId>#slot<N>', () {
      expect(SaveService.slotKey('novel1', 2), 'novel1#slot2');
    });

    test('слоты пишутся под своими ключами и читаются', () async {
      final service = SaveService();
      final now = DateTime(2026, 7, 1, 12);
      await service.saveGame(_state('novel1', lastPlayed: now));
      await service.saveToSlot(_state('novel1', lastPlayed: now, scene: 'slot_scene'), 2);

      final box = Hive.box<String>('game_saves');
      expect(box.containsKey('novel1'), isTrue);
      expect(box.containsKey('novel1#slot2'), isTrue);

      expect(service.loadSlot('novel1', 2)?.currentSceneId, 'slot_scene');
      expect(service.loadSlot('novel1', 1), isNull);
      expect(service.hasSlot('novel1', 2), isTrue);
      expect(service.hasAnySave('novel1'), isTrue);
    });

    test('loadLatest выбирает самый свежий из автосейва и слотов', () async {
      final service = SaveService();
      // saveToSlot штампует lastPlayed=now — пишем слоты в порядке старшинства
      await service.saveToSlot(
          _state('novel1', lastPlayed: DateTime(2026, 1, 1), scene: 'old_slot'), 1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.saveToSlot(
          _state('novel1', lastPlayed: DateTime(2026, 1, 1), scene: 'new_slot'), 2);
      // Автосейв — самый старый (lastPlayed сохраняется как есть)
      await service.saveGame(
          _state('novel1', lastPlayed: DateTime(2025, 1, 1), scene: 'auto'));

      expect(service.loadLatest('novel1')?.currentSceneId, 'new_slot');

      // Теперь автосейв самый свежий
      await service.saveGame(
          _state('novel1', lastPlayed: DateTime(2027, 1, 1), scene: 'auto2'));
      expect(service.loadLatest('novel1')?.currentSceneId, 'auto2');
    });

    test('loadLatest — только слот, без автосейва', () async {
      final service = SaveService();
      await service.saveToSlot(
          _state('novel1', lastPlayed: DateTime(2026, 1, 1), scene: 'slot_only'), 3);
      expect(service.loadGame('novel1'), isNull);
      expect(service.loadLatest('novel1')?.currentSceneId, 'slot_only');
      expect(service.hasSave('novel1'), isFalse);
      expect(service.hasAnySave('novel1'), isTrue);
    });

    test('getSavedNovelIds не включает слоты (для серверной синхронизации)',
        () async {
      final service = SaveService();
      await service.saveGame(_state('novel1', lastPlayed: DateTime(2026, 1, 1)));
      await service.saveToSlot(
          _state('novel1', lastPlayed: DateTime(2026, 1, 1)), 1);
      await service.saveToSlot(
          _state('novel2', lastPlayed: DateTime(2026, 1, 1)), 2);

      expect(service.getSavedNovelIds(), ['novel1']);
    });

    test('deleteAllSaves удаляет автосейв и все слоты', () async {
      final service = SaveService();
      await service.saveGame(_state('novel1', lastPlayed: DateTime(2026, 1, 1)));
      await service.saveToSlot(
          _state('novel1', lastPlayed: DateTime(2026, 1, 1)), 1);
      await service.saveToSlot(
          _state('novel1', lastPlayed: DateTime(2026, 1, 1)), 3);

      await service.deleteAllSaves('novel1');
      expect(service.hasAnySave('novel1'), isFalse);
      expect(service.loadLatest('novel1'), isNull);
    });
  });
}
