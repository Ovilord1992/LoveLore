import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navell/services/config_overrides.dart';
import 'package:navell/services/remote_config_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('remote_config_test');
    Hive.init(tempDir.path);
    await Hive.openBox<String>('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('app_settings').clear();
  });

  OverrideContext ctx({String platform = 'android', bool vip = false}) =>
      OverrideContext(deviceId: 'device-1', platform: platform, isVip: vip);

  Map<String, dynamic> rawConfig() => {
        'version': 7,
        'economy': {'maxTickets': 5, 'ticketRefillMinutes': 30},
        'ads': {'maxAdsPerDay': 5},
        'segments': [
          {
            'id': 'androids',
            'conditions': {'platform': 'android'},
            'overrides': {'ads.maxAdsPerDay': 2},
          },
        ],
        'experiments': [
          {
            'id': 'tickets_test',
            'enabled': true,
            'variants': [
              {
                'key': 'more',
                'weight': 100,
                'overrides': {'economy.maxTickets': 9},
              },
            ],
          },
        ],
      };

  group('RemoteConfigService + overrides (спека 4.6)', () {
    test('кешированный конфиг: overrides применяются до типизированных геттеров',
        () {
      Hive.box<String>('app_settings')
          .put('remote_config', jsonEncode(rawConfig()));

      final service = RemoteConfigService(contextProvider: ctx);

      // Эксперимент и сегмент применены к typed-конфигу
      expect(service.config.version, 7);
      expect(service.config.economy.maxTickets, 9);
      expect(service.config.ads.maxAdsPerDay, 2);
      expect(service.appliedExperiments, {'tickets_test': 'more'});
    });

    test('сегмент с неподходящей платформой не применяется', () {
      Hive.box<String>('app_settings')
          .put('remote_config', jsonEncode(rawConfig()));

      final service = RemoteConfigService(
          contextProvider: () => ctx(platform: 'ios'));

      expect(service.config.ads.maxAdsPerDay, 5); // сегмент android — мимо
      expect(service.config.economy.maxTickets, 9); // эксперимент применён
    });

    test('experiment_exposure — один раз за сессию на эксперимент', () {
      Hive.box<String>('app_settings')
          .put('remote_config', jsonEncode(rawConfig()));

      final service = RemoteConfigService(contextProvider: ctx);

      final events = <Map<String, dynamic>?>[];
      void logger(String name, [Map<String, dynamic>? params]) {
        expect(name, 'experiment_exposure');
        events.add(params);
      }

      service.attachExposureLogger(logger);
      expect(events, hasLength(1));
      expect(events.single, {
        'experimentId': 'tickets_test',
        'variant': 'more',
      });

      // Повторное подключение/дренаж не дублирует событие
      service.attachExposureLogger(logger);
      expect(events, hasLength(1));
    });

    test('first_launch_ts проставляется при первом старте и не перезаписывается',
        () async {
      final box = Hive.box<String>('app_settings');
      expect(box.get(RemoteConfigService.firstLaunchKey), isNull);

      RemoteConfigService(contextProvider: ctx);
      final first = box.get(RemoteConfigService.firstLaunchKey);
      expect(first, isNotNull);
      expect(int.tryParse(first!), isNotNull);

      // Второй запуск — значение остаётся прежним
      await Future<void>.delayed(const Duration(milliseconds: 5));
      RemoteConfigService(contextProvider: ctx);
      expect(box.get(RemoteConfigService.firstLaunchKey), first);
    });

    test('без кеша и сети — дефолтный конфиг без падений', () {
      final service = RemoteConfigService(contextProvider: ctx);
      expect(service.config.version, 0);
      expect(service.config.economy.maxTickets, 5);
      expect(service.appliedExperiments, isEmpty);
    });
  });
}
