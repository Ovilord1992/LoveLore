// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterSprite _$CharacterSpriteFromJson(Map<String, dynamic> json) =>
    CharacterSprite(
      id: json['id'] as String,
      image: json['image'] as String,
      label: json['label'] as String?,
    );

Map<String, dynamic> _$CharacterSpriteToJson(CharacterSprite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'image': instance.image,
      'label': instance.label,
    };

Character _$CharacterFromJson(Map<String, dynamic> json) => Character(
  id: json['id'] as String,
  name: json['name'] as String,
  color: json['color'] as String?,
  sprites:
      (json['sprites'] as List<dynamic>?)
          ?.map((e) => CharacterSprite.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$CharacterToJson(Character instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'color': instance.color,
  'sprites': instance.sprites,
};
