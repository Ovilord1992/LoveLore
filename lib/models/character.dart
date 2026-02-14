import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'character.g.dart';

/// Спрайт (вариант отображения) персонажа
@JsonSerializable()
class CharacterSprite extends Equatable {
  final String id;
  final String image;
  final String? label;

  const CharacterSprite({
    required this.id,
    required this.image,
    this.label,
  });

  factory CharacterSprite.fromJson(Map<String, dynamic> json) =>
      _$CharacterSpriteFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterSpriteToJson(this);

  @override
  List<Object?> get props => [id, image, label];
}

/// Персонаж новеллы
@JsonSerializable()
class Character extends Equatable {
  final String id;
  final String name;
  final String? color; // HEX-цвет имени в диалоге
  final List<CharacterSprite> sprites;

  const Character({
    required this.id,
    required this.name,
    this.color,
    this.sprites = const [],
  });

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterToJson(this);

  /// Получить спрайт по id
  CharacterSprite? getSprite(String spriteId) {
    try {
      return sprites.firstWhere((s) => s.id == spriteId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [id, name, color, sprites];
}
