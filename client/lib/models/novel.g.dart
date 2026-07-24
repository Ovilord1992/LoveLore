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
  recap: json['recap'] as String?,
);

Map<String, dynamic> _$ChapterToJson(Chapter instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'number': instance.number,
  'scenes': instance.scenes,
  'firstSceneId': instance.firstSceneId,
  'recap': instance.recap,
};

NovelEnding _$NovelEndingFromJson(Map<String, dynamic> json) => NovelEnding(
  id: json['id'] as String,
  title: json['title'] as String? ?? '',
  hidden: json['hidden'] as bool? ?? false,
);

Map<String, dynamic> _$NovelEndingToJson(NovelEnding instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'hidden': instance.hidden,
    };

StatDisplayConfig _$StatDisplayConfigFromJson(Map<String, dynamic> json) =>
    StatDisplayConfig(
      variable: json['variable'] as String,
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      max: json['max'] as num? ?? 100,
    );

Map<String, dynamic> _$StatDisplayConfigToJson(StatDisplayConfig instance) =>
    <String, dynamic>{
      'variable': instance.variable,
      'label': instance.label,
      'icon': instance.icon,
      'color': instance.color,
      'max': instance.max,
    };

PlayerNamePrompt _$PlayerNamePromptFromJson(Map<String, dynamic> json) =>
    PlayerNamePrompt(
      enabled: json['enabled'] as bool? ?? false,
      prompt: json['prompt'] as String?,
      defaultName: json['defaultName'] as String?,
    );

Map<String, dynamic> _$PlayerNamePromptToJson(PlayerNamePrompt instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'prompt': instance.prompt,
      'defaultName': instance.defaultName,
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
  chaptersCount:
      (_readChaptersCount(json, 'chaptersCount') as num?)?.toInt() ?? 0,
  releasedChapters: (json['releasedChapters'] as num?)?.toInt() ?? 0,
  dialogueTheme: json['dialogueTheme'] as String?,
  dialogueFrameColor: json['dialogueFrameColor'] as String?,
  dialogueBgColor: json['dialogueBgColor'] as String?,
  dialogueStyle: json['dialogueStyle'] as String?,
  endings:
      (json['endings'] as List<dynamic>?)
          ?.map((e) => NovelEnding.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  statsDisplay:
      (json['statsDisplay'] as List<dynamic>?)
          ?.map((e) => StatDisplayConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  playerNamePrompt: json['playerNamePrompt'] == null
      ? null
      : PlayerNamePrompt.fromJson(
          json['playerNamePrompt'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$NovelMetaToJson(NovelMeta instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'author': instance.author,
  'coverImage': instance.coverImage,
  'coverUrl': instance.coverUrl,
  'tags': instance.tags,
  'chaptersCount': instance.chaptersCount,
  'releasedChapters': instance.releasedChapters,
  'dialogueTheme': instance.dialogueTheme,
  'dialogueFrameColor': instance.dialogueFrameColor,
  'dialogueBgColor': instance.dialogueBgColor,
  'dialogueStyle': instance.dialogueStyle,
  'endings': instance.endings,
  'statsDisplay': instance.statsDisplay,
  'playerNamePrompt': instance.playerNamePrompt,
};
