import 'package:flutter_test/flutter_test.dart';
import 'package:navell/services/deep_link_service.dart';

void main() {
  group('parseNovelDeepLink (спека 4.10)', () {
    test('валидная ссылка amoria://novel/<id>', () {
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/moonlight-secrets')),
        'moonlight-secrets',
      );
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/demo_novel_1')),
        'demo_novel_1',
      );
    });

    test('чужая схема → null', () {
      expect(
        parseNovelDeepLink(Uri.parse('https://novel/abc')),
        isNull,
      );
      expect(
        parseNovelDeepLink(Uri.parse('other://novel/abc')),
        isNull,
      );
    });

    test('не novel-хост → null', () {
      expect(
        parseNovelDeepLink(Uri.parse('amoria://shop/abc')),
        isNull,
      );
      expect(parseNovelDeepLink(Uri.parse('amoria://novel')), isNull);
    });

    test('пустой или составной путь → null', () {
      expect(parseNovelDeepLink(Uri.parse('amoria://novel/')), isNull);
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/a/b')),
        isNull,
      );
    });

    test('невалидные символы id → null', () {
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/UPPERCASE')),
        isNull,
      );
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/id%20space')),
        isNull,
      );
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/..')),
        isNull,
      );
    });

    test('id длиннее 64 символов → null', () {
      final longId = 'a' * 65;
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/$longId')),
        isNull,
      );
      final maxId = 'a' * 64;
      expect(
        parseNovelDeepLink(Uri.parse('amoria://novel/$maxId')),
        maxId,
      );
    });
  });
}
