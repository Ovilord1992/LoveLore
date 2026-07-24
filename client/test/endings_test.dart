import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navell/services/user_profile_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('endings_test');
    Hive.init(tempDir.path);
    await Hive.openBox<String>('user_profile');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('user_profile').clear();
  });

  group('Концовки — запись в профиль (спека 1.3)', () {
    test('формат ключа <novelId>:<endingId>', () {
      expect(UserProfile.endingKey('novel1', 'good_end'), 'novel1:good_end');
    });

    test('unlockEnding записывает ключ и идемпотентен', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(userProfileProvider.notifier);
      expect(service.unlockEnding('novel1', 'good_end'), isTrue);
      expect(
        container.read(userProfileProvider).unlockedEndings,
        contains('novel1:good_end'),
      );
      // Повторная разблокировка — false, дубликата нет
      expect(service.unlockEnding('novel1', 'good_end'), isFalse);
      expect(
          container.read(userProfileProvider).unlockedEndings, hasLength(1));
    });

    test('endingsForNovel фильтрует по новелле', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(userProfileProvider.notifier);
      service.unlockEnding('novel1', 'good_end');
      service.unlockEnding('novel1', 'bad_end');
      service.unlockEnding('novel2', 'secret_end');
      final profile = container.read(userProfileProvider);
      expect(
        profile.endingsForNovel('novel1'),
        {'good_end', 'bad_end'},
      );
      expect(
        profile.endingsForNovel('novel2'),
        {'secret_end'},
      );
      expect(profile.endingsForNovel('novel3'), isEmpty);
    });

    test('unlockedEndings переживает сериализацию профиля', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(userProfileProvider.notifier)
          .unlockEnding('novel1', 'good_end');

      final restored = UserProfile.fromJson(
          container.read(userProfileProvider).toJson());
      expect(restored.unlockedEndings, contains('novel1:good_end'));
    });

    test('mergeFromServer — union концовок', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(userProfileProvider.notifier);
      service.unlockEnding('novel1', 'local_end');
      service.mergeFromServer({
        'unlockedEndings': ['novel1:server_end', 'novel2:x'],
      });
      expect(
        container.read(userProfileProvider).unlockedEndings,
        containsAll(
            {'novel1:local_end', 'novel1:server_end', 'novel2:x'}),
      );
    });
  });
}
