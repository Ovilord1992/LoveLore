import 'package:flutter_test/flutter_test.dart';
import 'package:navell/engine/text_interpolator.dart';
import 'package:navell/models/novel_translation.dart';

void main() {
  group('TextInterpolator — {name} цепочка (спека 1.4)', () {
    test('1) переменная player_name', () {
      expect(
        TextInterpolator.interpolate(
          'Привет, {name}!',
          variables: {'player_name': 'Аня'},
          profileName: 'Профиль',
          promptDefaultName: 'Алиса',
        ),
        'Привет, Аня!',
      );
    });

    test('2) displayName профиля, если переменной нет', () {
      expect(
        TextInterpolator.interpolate(
          'Привет, {name}!',
          variables: {},
          profileName: 'Профиль',
          promptDefaultName: 'Алиса',
        ),
        'Привет, Профиль!',
      );
    });

    test('3) defaultName из playerNamePrompt', () {
      expect(
        TextInterpolator.interpolate(
          'Привет, {name}!',
          variables: {},
          promptDefaultName: 'Алиса',
        ),
        'Привет, Алиса!',
      );
    });

    test('4) фолбэк «Ты»', () {
      expect(
        TextInterpolator.interpolate('Привет, {name}!'),
        'Привет, Ты!',
      );
    });

    test('пустая строка в player_name не считается именем', () {
      expect(
        TextInterpolator.interpolate(
          '{name}',
          variables: {'player_name': '   '},
          promptDefaultName: 'Алиса',
        ),
        'Алиса',
      );
    });
  });

  group('TextInterpolator — {var:key}', () {
    test('число: целое без дробной части', () {
      expect(
        TextInterpolator.interpolate(
          'Очков: {var:love}',
          variables: {'love': 7},
        ),
        'Очков: 7',
      );
      expect(
        TextInterpolator.interpolate(
          'Очков: {var:love}',
          variables: {'love': 7.0},
        ),
        'Очков: 7',
      );
      expect(
        TextInterpolator.interpolate(
          'Очков: {var:love}',
          variables: {'love': 7.5},
        ),
        'Очков: 7.5',
      );
    });

    test('строка и bool', () {
      expect(
        TextInterpolator.interpolate(
          '{var:route} / {var:met}',
          variables: {'route': 'mia', 'met': true},
        ),
        'mia / true',
      );
    });

    test('отсутствующая переменная → пустая строка', () {
      expect(
        TextInterpolator.interpolate('X{var:missing}Y', variables: {}),
        'XY',
      );
    });

    test('несколько плейсхолдеров в одном тексте', () {
      expect(
        TextInterpolator.interpolate(
          '{name}: {var:a}+{var:b}',
          variables: {'player_name': 'Аня', 'a': 1, 'b': 2},
        ),
        'Аня: 1+2',
      );
    });

    test('текст без плейсхолдеров не меняется', () {
      expect(
        TextInterpolator.interpolate('Просто текст', variables: {'a': 1}),
        'Просто текст',
      );
    });
  });

  group('Порядок «перевод → интерполяция»', () {
    test('ключ перевода содержит плейсхолдеры как есть', () {
      final translation = NovelTranslation.fromJson({
        'meta': {'language': 'en', 'sourceLanguage': 'ru', 'novelId': 'n1'},
        'texts': {'Привет, {name}! Очков: {var:love}': 'Hi, {name}! Score: {var:love}'},
      });

      // Шаг 1: перевод по оригинальной строке С плейсхолдерами
      final translated =
          translation.translate('Привет, {name}! Очков: {var:love}');
      expect(translated, 'Hi, {name}! Score: {var:love}');

      // Шаг 2: интерполяция ПОСЛЕ перевода
      final result = TextInterpolator.interpolate(
        translated,
        variables: {'player_name': 'Аня', 'love': 3},
      );
      expect(result, 'Hi, Аня! Score: 3');
    });
  });
}
