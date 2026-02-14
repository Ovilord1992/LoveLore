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
  final List<String> tags;
  final int totalChapters;

  const NovelMeta({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    this.coverImage,
    this.tags = const [],
    this.totalChapters = 0,
  });

  factory NovelMeta.fromJson(Map<String, dynamic> json) =>
      _$NovelMetaFromJson(json);
  Map<String, dynamic> toJson() => _$NovelMetaToJson(this);

  @override
  List<Object?> get props => [id, title, description, author, coverImage, tags, totalChapters];
}
