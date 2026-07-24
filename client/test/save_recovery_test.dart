import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navell/engine/scene_engine.dart';
import 'package:navell/models/models.dart';
import 'package:navell/services/novel_api_service.dart';
import 'package:navell/services/novel_loader.dart';
import 'package:navell/services/reading_progress_service.dart';
import 'package:navell/services/save_service.dart';

/// Фейковый загрузчик новелл: главы из памяти, без assets и сети
class _FakeLoader extends NovelLoader {
  _FakeLoader(super.ref);

  NovelMeta meta = const NovelMeta(
    id: 'n1',
    title: 'Test',
    description: '',
    author: '',
  );
  final Map<String, Chapter> chapters = {};

  @override
  Future<NovelMeta> loadNovelMeta(String novelId) async => meta;

  @override
  Future<List<Character>> loadCharacters(String novelId) async => const [];

  @override
  Future<Map<String, dynamic>> loadInitialVariables(String novelId) async =>
      const {};

  @override
  Future<Chapter?> loadChapter(String novelId, String chapterId) async =>
      chapters[chapterId];

  @override
  Future<NovelTranslation?> loadTranslation(
          String novelId, String language) async =>
      null;
}

/// Фейковый API: список глав сервера без сети
class _FakeApi extends NovelApiService {
  final List<ChapterInfo>? serverChapters;
  _FakeApi(this.serverChapters);

  @override
  Future<List<ChapterInfo>?> fetchChaptersList(String novelId) async =>
      serverChapters;
}

Scene _scene(String id, {int eventCount = 2, String? nextSceneId}) => Scene(
      id: id,
      events: [
        for (var i = 0; i < eventCount; i++)
          SceneEvent(type: EventType.narration, text: '$id-e$i'),
      ],
      nextSceneId: nextSceneId,
    );

Chapter _chapter(int number, List<Scene> scenes) => Chapter(
      id: 'chapter_$number',
      title: 'Глава $number',
      number: number,
      scenes: scenes,
      firstSceneId: scenes.first.id,
    );

GameState _save({
  required String chapterId,
  required String sceneId,
  int eventIndex = 0,
  Map<String, dynamic> variables = const {},
}) =>
    GameState(
      novelId: 'n1',
      currentChapterId: chapterId,
      currentSceneId: sceneId,
      currentEventIndex: eventIndex,
      variables: variables,
      lastPlayed: DateTime(2026, 7, 1),
    );

void main() {
  late Directory tempDir;

  const boxes = [
    'game_saves',
    'user_profile',
    'app_settings',
    'app_locale',
    'reading_progress',
    'analytics_queue',
    'economy_queue',
    'currency',
    'wardrobe',
  ];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('save_recovery_test');
    Hive.init(tempDir.path);
    for (final box in boxes) {
      await Hive.openBox<String>(box);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    for (final box in boxes) {
      await Hive.box<String>(box).clear();
    }
  });

  ProviderContainer buildContainer({
    required Map<String, Chapter> chapters,
    List<ChapterInfo>? serverChapters,
  }) {
    final container = ProviderContainer(overrides: [
      novelLoaderProvider.overrideWith((ref) {
        final loader = _FakeLoader(ref);
        loader.chapters.addAll(chapters);
        return loader;
      }),
      novelApiServiceProvider.overrideWith((ref) => _FakeApi(serverChapters)),
    ]);
    return container;
  }

  group('Восстановление битых сейвов (спека 4.2)', () {
    test('4.2.1: сцена из сейва не найдена → откат к firstSceneId + notice',
        () async {
      final container = buildContainer(chapters: {
        'chapter_1': _chapter(1, [_scene('s1'), _scene('s2')]),
      });
      addTearDown(container.dispose);

      await container
          .read(saveServiceProvider.notifier)
          .saveGame(_save(
            chapterId: 'chapter_1',
            sceneId: 'ghost_scene',
            eventIndex: 1,
            variables: {'love': 5},
          ));

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1');

      final state = container.read(sceneEngineProvider);
      expect(state, isNotNull);
      expect(state!.currentSceneId, 's1');
      expect(state.currentEventIndex, 0);
      // Переменные сейва сохранены (это откат, а не новая игра)
      expect(state.variables['love'], 5);
      expect(engine.currentScene?.id, 's1');
      // Snackbar-уведомление выставлено
      expect(container.read(saveRestoreNoticeProvider), isNotNull);
    });

    test('4.2.2: глава из сейва отсутствует → последняя доступная + notice',
        () async {
      final container = buildContainer(chapters: {
        'chapter_1': _chapter(1, [_scene('c1s1')]),
        'chapter_2': _chapter(2, [_scene('c2s1')]),
      });
      addTearDown(container.dispose);

      await container.read(saveServiceProvider.notifier).saveGame(_save(
            chapterId: 'chapter_3',
            sceneId: 'c3s1',
            variables: {'brave': 2},
          ));

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1');

      final state = container.read(sceneEngineProvider);
      expect(state, isNotNull);
      expect(state!.currentChapterId, 'chapter_2');
      expect(state.currentSceneId, 'c2s1');
      expect(state.currentEventIndex, 0);
      expect(state.variables['brave'], 2);
      expect(engine.currentChapter?.id, 'chapter_2');
      expect(container.read(saveRestoreNoticeProvider), isNotNull);
    });

    test('4.2.2: доступна только глава 1 → откат к главе 1', () async {
      final container = buildContainer(chapters: {
        'chapter_1': _chapter(1, [_scene('c1s1')]),
      });
      addTearDown(container.dispose);

      await container.read(saveServiceProvider.notifier).saveGame(
          _save(chapterId: 'chapter_5', sceneId: 'whatever'));

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1');

      final state = container.read(sceneEngineProvider);
      expect(state, isNotNull);
      expect(state!.currentChapterId, 'chapter_1');
      expect(state.currentSceneId, 'c1s1');
      expect(container.read(saveRestoreNoticeProvider), isNotNull);
    });

    test('4.2.3: eventIndex вне диапазона → кламп к началу сцены (без notice)',
        () async {
      final container = buildContainer(chapters: {
        'chapter_1': _chapter(1, [_scene('s1', eventCount: 3)]),
      });
      addTearDown(container.dispose);

      await container.read(saveServiceProvider.notifier).saveGame(
          _save(chapterId: 'chapter_1', sceneId: 's1', eventIndex: 99));

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1');

      final state = container.read(sceneEngineProvider);
      expect(state, isNotNull);
      expect(state!.currentSceneId, 's1');
      expect(state.currentEventIndex, 0);
      // Тихий кламп: сцена и глава на месте — snackbar не показываем
      expect(container.read(saveRestoreNoticeProvider), isNull);
    });

    test('валидный сейв восстанавливается без изменений и без notice',
        () async {
      final container = buildContainer(chapters: {
        'chapter_1': _chapter(1, [_scene('s1', eventCount: 3), _scene('s2')]),
      });
      addTearDown(container.dispose);

      await container.read(saveServiceProvider.notifier).saveGame(
          _save(chapterId: 'chapter_1', sceneId: 's1', eventIndex: 2));

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1');

      final state = container.read(sceneEngineProvider);
      expect(state!.currentSceneId, 's1');
      expect(state.currentEventIndex, 2);
      expect(container.read(saveRestoreNoticeProvider), isNull);
    });

    test('4.2.4: рантайм-переход в несуществующую сцену → поток конца главы',
        () async {
      final container = buildContainer(
        chapters: {
          'chapter_1':
              _chapter(1, [_scene('s1', eventCount: 1, nextSceneId: 'void')]),
        },
        serverChapters: const [], // сервер отвечает: глав больше нет
      );
      addTearDown(container.dispose);

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1', forceNew: true);
      expect(container.read(sceneEngineProvider)?.currentSceneId, 's1');

      // Конец сцены: nextSceneId указывает в никуда — не крэш,
      // а стандартный поток конца главы (глав больше нет → completed).
      engine.nextEvent();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(chapterTransitionProvider),
        ChapterTransition.completed,
      );
    });

    test('4.2.5: рассинхрон ключей skip-read не падает', () async {
      final container = buildContainer(chapters: {
        'chapter_1': _chapter(1, [_scene('s1')]),
      });
      addTearDown(container.dispose);

      // Прогресс чтения от старой версии контента (сцены больше нет)
      final progress = container.read(readingProgressProvider);
      progress.markRead('n1', 'deleted_scene', 5);
      progress.markRead('n1', 's1', 42); // индекс за пределами сцены

      await container.read(saveServiceProvider.notifier).saveGame(
          _save(chapterId: 'chapter_1', sceneId: 's1'));

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1');

      // Не совпало — событие считается непрочитанным, без крэша
      expect(container.read(sceneEngineProvider), isNotNull);
      expect(progress.isRead('n1', 'deleted_scene', 5), isTrue);
      // Текущее событие уже помечено прочитанным движком (s1:0)
      expect(progress.isRead('n1', 's1', 0), isTrue);
    });

    test('restoreFromState (ручной слот): откаты сцены и клампа индекса',
        () async {
      final container = buildContainer(chapters: {
        'chapter_1': _chapter(1, [_scene('s1', eventCount: 2)]),
      });
      addTearDown(container.dispose);

      final engine = container.read(sceneEngineProvider.notifier);
      await engine.startNovel('n1', forceNew: true);

      // Слот со сценой, которой больше нет
      final ok = await engine.restoreFromState(
          _save(chapterId: 'chapter_1', sceneId: 'gone', eventIndex: 7));
      expect(ok, isTrue);
      final state = container.read(sceneEngineProvider);
      expect(state!.currentSceneId, 's1');
      expect(state.currentEventIndex, 0);
      expect(container.read(saveRestoreNoticeProvider), isNotNull);
    });
  });
}
