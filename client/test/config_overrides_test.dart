import 'package:flutter_test/flutter_test.dart';
import 'package:navell/services/config_overrides.dart';

const _ctx = OverrideContext(
  deviceId: 'device-1',
  platform: 'android',
);

void main() {
  group('fnv1a (спека 4.6)', () {
    test('известные вектора FNV-1a 32-bit — алгоритм закреплён', () {
      // Официальные тест-вектора FNV-1a (32 бита)
      expect(fnv1a(''), 0x811C9DC5); // offset basis
      expect(fnv1a('a'), 0xE40C292C);
      expect(fnv1a('foobar'), 0xBF9CF968);
    });

    test('стабильность: одинаковый вход — одинаковый выход', () {
      final first = fnv1a('device-1:price_test_1');
      for (var i = 0; i < 100; i++) {
        expect(fnv1a('device-1:price_test_1'), first);
      }
    });
  });

  group('pickVariantKey — бакетирование по кумулятивным весам', () {
    List<Map<String, dynamic>> variants(List<(String, int)> defs) => [
          for (final (key, weight) in defs)
            {'key': key, 'weight': weight, 'overrides': <String, dynamic>{}},
        ];

    test('стабильность между вызовами (детерминизм)', () {
      final v = variants([('control', 50), ('cheap', 50)]);
      final first = pickVariantKey(
          deviceId: 'device-1', experimentId: 'exp1', variants: v);
      expect(first, isNotNull);
      for (var i = 0; i < 50; i++) {
        expect(
          pickVariantKey(
              deviceId: 'device-1', experimentId: 'exp1', variants: v),
          first,
        );
      }
    });

    test('вариант соответствует ручному расчёту по кумулятивным весам', () {
      final v = variants([('a', 30), ('b', 70)]);
      for (final device in ['d1', 'd2', 'd3', 'abc', 'xyz']) {
        final bucket = fnv1a('$device:exp') % 100;
        final expected = bucket < 30 ? 'a' : 'b';
        expect(
          pickVariantKey(deviceId: device, experimentId: 'exp', variants: v),
          expected,
          reason: 'device=$device bucket=$bucket',
        );
      }
    });

    test('распределение 50/50 на 1000 устройств примерно поровну', () {
      final v = variants([('control', 50), ('cheap', 50)]);
      var control = 0;
      for (var i = 0; i < 1000; i++) {
        final key = pickVariantKey(
            deviceId: 'device-$i', experimentId: 'exp1', variants: v);
        if (key == 'control') control++;
      }
      // Допуск ±10% — fnv1a достаточно равномерен
      expect(control, inInclusiveRange(400, 600));
    });

    test('распределение 90/10 уважает веса', () {
      final v = variants([('big', 90), ('small', 10)]);
      var small = 0;
      for (var i = 0; i < 1000; i++) {
        final key = pickVariantKey(
            deviceId: 'device-$i', experimentId: 'exp2', variants: v);
        if (key == 'small') small++;
      }
      expect(small, inInclusiveRange(50, 200));
    });

    test('границы: вес 100/0 — всегда первый; нулевые веса — null', () {
      expect(
        pickVariantKey(
          deviceId: 'any',
          experimentId: 'e',
          variants: variants([('only', 100), ('never', 0)]),
        ),
        'only',
      );
      expect(
        pickVariantKey(
          deviceId: 'any',
          experimentId: 'e',
          variants: variants([('a', 0), ('b', 0)]),
        ),
        isNull,
      );
      expect(
        pickVariantKey(deviceId: 'any', experimentId: 'e', variants: []),
        isNull,
      );
    });

    test('вес 1: единственный валидный вариант всегда выбирается', () {
      expect(
        pickVariantKey(
          deviceId: 'whatever',
          experimentId: 'solo',
          variants: variants([('single', 1)]),
        ),
        'single',
      );
    });
  });

  group('setByDotPath', () {
    test('заменяет значение целиком по плоскому dot-пути', () {
      final target = <String, dynamic>{
        'economy': {'maxTickets': 5, 'startDiamonds': 50},
      };
      setByDotPath(target, 'economy.maxTickets', 9);
      expect(target['economy'], {'maxTickets': 9, 'startDiamonds': 50});
    });

    test('создаёт отсутствующие промежуточные секции', () {
      final target = <String, dynamic>{};
      setByDotPath(target, 'ads.maxAdsPerDay', 0);
      expect(target, {
        'ads': {'maxAdsPerDay': 0},
      });
    });

    test('значение-объект заменяется целиком, а не мержится', () {
      final target = <String, dynamic>{
        'iap': {'diamonds_20': {'diamonds': 20}},
      };
      setByDotPath(target, 'iap', {'x': 1});
      expect(target['iap'], {'x': 1});
    });
  });

  group('segmentMatches — условия сегментов', () {
    test('platform', () {
      expect(segmentMatches({'platform': 'android'}, _ctx), isTrue);
      expect(segmentMatches({'platform': 'ios'}, _ctx), isFalse);
    });

    test('vip', () {
      expect(segmentMatches({'vip': false}, _ctx), isTrue);
      expect(segmentMatches({'vip': true}, _ctx), isFalse);
      const vipCtx = OverrideContext(
          deviceId: 'd', platform: 'android', isVip: true);
      expect(segmentMatches({'vip': true}, vipCtx), isTrue);
    });

    test('installedAfter / installedBefore', () {
      final ctx = OverrideContext(
        deviceId: 'd',
        platform: 'android',
        firstLaunchAt: DateTime.utc(2026, 7, 15),
      );
      expect(
          segmentMatches({'installedAfter': '2026-07-01T00:00:00Z'}, ctx),
          isTrue);
      expect(
          segmentMatches({'installedAfter': '2026-07-20T00:00:00Z'}, ctx),
          isFalse);
      expect(
          segmentMatches({'installedBefore': '2026-07-20T00:00:00Z'}, ctx),
          isTrue);
      expect(
          segmentMatches({'installedBefore': '2026-07-01T00:00:00Z'}, ctx),
          isFalse);
      // Дата первого запуска неизвестна — условие по дате не выполняется
      expect(
          segmentMatches({'installedAfter': '2026-07-01T00:00:00Z'}, _ctx),
          isFalse);
    });

    test('пустые условия подходят всем', () {
      expect(segmentMatches({}, _ctx), isTrue);
    });
  });

  group('applyConfigOverrides — порядок и семантика (спека 4.6)', () {
    Map<String, dynamic> baseConfig() => {
          'version': 3,
          'economy': {'maxTickets': 5, 'premiumChoiceBaseCost': 15},
          'ads': {'maxAdsPerDay': 5},
        };

    test('подошедший сегмент применяет overrides по dot-путям', () {
      final raw = baseConfig()
        ..['segments'] = [
          {
            'id': 'androids',
            'conditions': {'platform': 'android'},
            'overrides': {'ads.maxAdsPerDay': 0},
          },
        ];
      final result = applyConfigOverrides(raw, context: _ctx);
      expect(result['ads'], {'maxAdsPerDay': 0});
      // Исходная карта не мутирована
      expect(raw['ads'], {'maxAdsPerDay': 5});
    });

    test('неподошедший сегмент не применяется', () {
      final raw = baseConfig()
        ..['segments'] = [
          {
            'id': 'ios_vip',
            'conditions': {'platform': 'ios', 'vip': true},
            'overrides': {'ads.maxAdsPerDay': 0},
          },
        ];
      final result = applyConfigOverrides(raw, context: _ctx);
      expect(result['ads'], {'maxAdsPerDay': 5});
    });

    test('сегменты применяются по порядку массива (последний побеждает)', () {
      final raw = baseConfig()
        ..['segments'] = [
          {
            'id': 's1',
            'conditions': <String, dynamic>{},
            'overrides': {'economy.maxTickets': 7},
          },
          {
            'id': 's2',
            'conditions': <String, dynamic>{},
            'overrides': {'economy.maxTickets': 8},
          },
        ];
      final result = applyConfigOverrides(raw, context: _ctx);
      expect((result['economy'] as Map)['maxTickets'], 8);
    });

    test('эксперименты применяются ПОСЛЕ сегментов', () {
      final raw = baseConfig()
        ..['segments'] = [
          {
            'id': 's1',
            'conditions': <String, dynamic>{},
            'overrides': {'economy.premiumChoiceBaseCost': 20},
          },
        ]
        ..['experiments'] = [
          {
            'id': 'price_test',
            'enabled': true,
            'variants': [
              {
                'key': 'cheap',
                'weight': 100,
                'overrides': {'economy.premiumChoiceBaseCost': 10},
              },
            ],
          },
        ];
      final applied = <AppliedExperiment>[];
      final result = applyConfigOverrides(raw,
          context: _ctx, appliedExperiments: applied);
      expect((result['economy'] as Map)['premiumChoiceBaseCost'], 10);
      expect(applied, hasLength(1));
      expect(applied.single.experimentId, 'price_test');
      expect(applied.single.variant, 'cheap');
    });

    test('выключенный эксперимент не применяется и не экспонируется', () {
      final raw = baseConfig()
        ..['experiments'] = [
          {
            'id': 'off_test',
            'enabled': false,
            'variants': [
              {
                'key': 'v',
                'weight': 100,
                'overrides': {'economy.maxTickets': 99},
              },
            ],
          },
        ];
      final applied = <AppliedExperiment>[];
      final result = applyConfigOverrides(raw,
          context: _ctx, appliedExperiments: applied);
      expect((result['economy'] as Map)['maxTickets'], 5);
      expect(applied, isEmpty);
    });

    test('контрольный вариант (пустые overrides) тоже считается применённым',
        () {
      final raw = baseConfig()
        ..['experiments'] = [
          {
            'id': 'control_only',
            'enabled': true,
            'variants': [
              {'key': 'control', 'weight': 100, 'overrides': <String, dynamic>{}},
            ],
          },
        ];
      final applied = <AppliedExperiment>[];
      applyConfigOverrides(raw, context: _ctx, appliedExperiments: applied);
      expect(applied.single.variant, 'control');
    });

    test('конфиг без секций segments/experiments проходит без изменений', () {
      final raw = baseConfig();
      final result = applyConfigOverrides(raw, context: _ctx);
      expect(result, raw);
    });
  });
}
