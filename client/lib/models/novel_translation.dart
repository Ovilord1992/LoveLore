/// Модель перевода книги на один язык
class NovelTranslation {
  final String language;
  final String sourceLanguage;
  final String novelId;
  final int version;
  final String? novelTitle;
  final String? novelDescription;
  final Map<String, String> characterNames; // characterId → translated name
  final Map<String, String> chapterTitles;  // chapterId → translated title
  final Map<String, String> texts;          // original text → translated text

  const NovelTranslation({
    required this.language,
    required this.sourceLanguage,
    required this.novelId,
    this.version = 1,
    this.novelTitle,
    this.novelDescription,
    this.characterNames = const {},
    this.chapterTitles = const {},
    this.texts = const {},
  });

  factory NovelTranslation.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final novel = json['novel'] as Map<String, dynamic>? ?? {};
    final chars = json['characters'] as Map<String, dynamic>? ?? {};
    final chaps = json['chapters'] as Map<String, dynamic>? ?? {};
    final texts = json['texts'] as Map<String, dynamic>? ?? {};

    return NovelTranslation(
      language: meta['language'] as String? ?? '',
      sourceLanguage: meta['sourceLanguage'] as String? ?? '',
      novelId: meta['novelId'] as String? ?? '',
      version: meta['version'] as int? ?? 1,
      novelTitle: novel['title'] as String?,
      novelDescription: novel['description'] as String?,
      characterNames: chars.map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(k, m['name'] as String? ?? '');
      }),
      chapterTitles: chaps.map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(k, m['title'] as String? ?? '');
      }),
      texts: texts.map((k, v) => MapEntry(k, v as String)),
    );
  }

  /// Перевести текст (диалог, нарратив, выбор)
  String translate(String original) => texts[original] ?? original;

  /// Перевести имя персонажа
  String translateCharacter(String characterId, String originalName) =>
      characterNames[characterId] ?? originalName;

  /// Перевести название главы
  String translateChapter(String chapterId, String originalTitle) =>
      chapterTitles[chapterId] ?? originalTitle;
}
