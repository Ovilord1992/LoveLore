// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chapter _$ChapterFromJson(Map<String, dynamic> json) => Chapter(
  id: json['id'] as String,
  title: json['title'] as String,
  number: (json['number'] as num).toInt(),
  scenes: (json['scenes'] as List<dynamic>)
      .map((e) => Scene.fromJson(e as Map<String, dynamic>))
      .toList(),
  firstSceneId: json['firstSceneId'] as String,
);

Map<String, dynamic> _$ChapterToJson(Chapter instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'number': instance.number,
  'scenes': instance.scenes,
  'firstSceneId': instance.firstSceneId,
};

NovelMeta _$NovelMetaFromJson(Map<String, dynamic> json) => NovelMeta(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  author: json['author'] as String,
  coverImage: json['coverImage'] as String?,
  coverUrl: json['coverUrl'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  totalChapters: (json['totalChapters'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$NovelMetaToJson(NovelMeta instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'author': instance.author,
  'coverImage': instance.coverImage,
  'coverUrl': instance.coverUrl,
  'tags': instance.tags,
  'totalChapters': instance.totalChapters,
};
