import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'scene.dart';

part 'novel.g.dart';

/// Глава новеллы
@JsonSerializable()
class Chapter extends Equatable {
  final String id;
  final String title;
  final int number;
  final List<Scene> scenes;
  final String firstSceneId;

  const Chapter({
    required this.id,
    required this.title,
    required this.number,
    required this.scenes,
    required this.firstSceneId,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) =>
      _$ChapterFromJson(json);
  Map<String, dynamic> toJson() => _$ChapterToJson(this);

  Scene? getScene(String sceneId) {
    try {
      return scenes.firstWhere((s) => s.id == sceneId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [id, title, number, scenes, firstSceneId];
}

/// Метаданные новеллы
@JsonSerializable()
class NovelMeta extends Equatable {
  final String id;
  final String title;
  final String description;
  final String author;
  final String? coverImage;
  final String? coverUrl;
  final List<String> tags;
  final int totalChapters;
  final int releasedChapters;
  final String? dialogueTheme;

  /// Цвет рамки диалога (hex, например "#B8860B"). Если задан — перекрывает тему.
  final String? dialogueFrameColor;

  /// Цвет фона диалога (hex, например "#1A1410"). Если задан — перекрывает тему.
  final String? dialogueBgColor;

  /// Локализованное название (заполняется из перевода если доступен)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? localizedTitle;

  /// Локализованное описание (заполняется из перевода если доступен)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? localizedDescription;

  const NovelMeta({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    this.coverImage,
    this.coverUrl,
    this.tags = const [],
    this.totalChapters = 0,
    this.releasedChapters = 0,
    this.dialogueTheme,
    this.dialogueFrameColor,
    this.dialogueBgColor,
    this.localizedTitle,
    this.localizedDescription,
  });

  factory NovelMeta.fromJson(Map<String, dynamic> json) =>
      _$NovelMetaFromJson(json);
  Map<String, dynamic> toJson() => _$NovelMetaToJson(this);

  /// Возвращает отображаемое название (локализованное если есть, иначе оригинал)
  String get displayTitle => localizedTitle ?? title;

  /// Возвращает отображаемое описание (локализованное если есть, иначе оригинал)
  String get displayDescription => localizedDescription ?? description;

  /// Тема диалогового окна
  DialogueFrameTheme get frameTheme {
    switch (dialogueTheme) {
      case 'artDeco': return DialogueFrameTheme.artDeco;
      case 'modern': return DialogueFrameTheme.modern;
      case 'glassmorphism': return DialogueFrameTheme.glassmorphism;
      case 'fantasy': return DialogueFrameTheme.fantasy;
      default: return DialogueFrameTheme.ornate;
    }
  }

  /// Создать копию с переводом
  NovelMeta copyWithTranslation(String? translatedTitle, String? translatedDescription) {
    return NovelMeta(
      id: id,
      title: title,
      description: description,
      author: author,
      coverImage: coverImage,
      coverUrl: coverUrl,
      tags: tags,
      totalChapters: totalChapters,
      releasedChapters: releasedChapters,
      dialogueTheme: dialogueTheme,
      dialogueFrameColor: dialogueFrameColor,
      dialogueBgColor: dialogueBgColor,
      localizedTitle: translatedTitle,
      localizedDescription: translatedDescription,
    );
  }

  @override
  List<Object?> get props => [id, title, description, author, coverImage, coverUrl, tags, totalChapters, releasedChapters, dialogueTheme, dialogueFrameColor, dialogueBgColor, localizedTitle, localizedDescription];
}

/// Информация о главе с сервера
class ChapterInfo {
  final int number;
  final String title;
  final bool isReleased;
  final DateTime? releasedAt;
  bool isDownloaded;

  ChapterInfo({
    required this.number,
    required this.title,
    this.isReleased = false,
    this.releasedAt,
    this.isDownloaded = false,
  });

  factory ChapterInfo.fromJson(Map<String, dynamic> json) => ChapterInfo(
        number: json['number'] as int,
        title: (json['title'] as String?) ?? 'Глава ${json['number']}',
        isReleased: json['isReleased'] as bool? ?? false,
        releasedAt: json['releasedAt'] != null
            ? DateTime.parse(json['releasedAt'] as String)
            : null,
      );
}
