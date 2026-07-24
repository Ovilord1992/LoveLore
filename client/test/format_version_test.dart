import 'package:flutter_test/flutter_test.dart';
import 'package:navell/models/novel.dart';
import 'package:navell/services/app_version.dart';

NovelMeta _meta({int? formatVersion, String? minAppVersion}) => NovelMeta(
      id: 'n1',
      title: 'Test',
      description: '',
      author: '',
      formatVersion: formatVersion ?? 1,
      minAppVersion: minAppVersion,
    );

void main() {
  group('formatVersion-гейт (спека 4.1)', () {
    test('при отсутствии formatVersion в JSON — дефолт 1, совместима', () {
      final meta = NovelMeta.fromJson({
        'id': 'n1',
        'title': 'T',
        'description': '',
        'author': '',
      });
      expect(meta.formatVersion, 1);
      expect(meta.minAppVersion, isNull);
      expect(isNovelFormatSupported(meta), isTrue);
      expect(meta.isFormatSupported, isTrue);
    });

    test('formatVersion == supportedFormatVersion — совместима', () {
      final meta = NovelMeta.fromJson({
        'id': 'n1',
        'title': 'T',
        'description': '',
        'author': '',
        'formatVersion': supportedFormatVersion,
      });
      expect(isNovelFormatSupported(meta), isTrue);
    });

    test('formatVersion выше поддерживаемого — несовместима', () {
      expect(
        isNovelFormatSupported(
            _meta(formatVersion: supportedFormatVersion + 1)),
        isFalse,
      );
    });

    test('minAppVersion ниже или равен версии приложения — совместима', () {
      expect(isNovelFormatSupported(_meta(minAppVersion: '0.9.0')), isTrue);
      expect(isNovelFormatSupported(_meta(minAppVersion: appVersion)), isTrue);
    });

    test('minAppVersion выше версии приложения — несовместима', () {
      expect(isNovelFormatSupported(_meta(minAppVersion: '99.0.0')), isFalse);
    });

    test('пустая/пробельная minAppVersion игнорируется', () {
      expect(isNovelFormatSupported(_meta(minAppVersion: '')), isTrue);
      expect(isNovelFormatSupported(_meta(minAppVersion: '  ')), isTrue);
    });

    test('formatVersion сериализуется в JSON и обратно', () {
      final meta = _meta(formatVersion: 2, minAppVersion: '1.2.3');
      final restored = NovelMeta.fromJson(meta.toJson());
      expect(restored.formatVersion, 2);
      expect(restored.minAppVersion, '1.2.3');
    });
  });

  group('compareSemver', () {
    test('равные версии', () {
      expect(compareSemver('1.0.0', '1.0.0'), 0);
      expect(compareSemver('1.0', '1.0.0'), 0); // недостающие части = 0
      expect(compareSemver('1', '1.0.0'), 0);
    });

    test('больше/меньше по компонентам', () {
      expect(compareSemver('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareSemver('1.0.0', '1.0.1'), lessThan(0));
      expect(compareSemver('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('числовое сравнение, а не лексикографическое', () {
      expect(compareSemver('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareSemver('0.10.0', '0.2.0'), greaterThan(0));
    });

    test('нечисловые компоненты считаются нулём', () {
      expect(compareSemver('abc', '0.0.0'), 0);
      expect(compareSemver('1.x.0', '1.0.0'), 0);
    });
  });
}
