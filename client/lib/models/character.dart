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

/// v2: аутфит (наряд) персонажа для гардероба
@JsonSerializable()
class CharacterOutfit extends Equatable {
  final String id;
  final String name;

  /// Наряд по умолчанию — доступен сразу
  @JsonKey(name: 'default')
  final bool isDefault;

  /// Цена в алмазах (0/null — бесплатный)
  final int? priceDiamonds;

  /// Превью для экрана гардероба
  final String? thumbnail;

  /// Спрайты аутфита: spriteId → путь к картинке
  final Map<String, String> sprites;

  const CharacterOutfit({
    required this.id,
    this.name = '',
    this.isDefault = false,
    this.priceDiamonds,
    this.thumbnail,
    this.sprites = const {},
  });

  /// Бесплатен (default или без цены) — доступен без покупки
  bool get isFree => isDefault || (priceDiamonds ?? 0) <= 0;

  factory CharacterOutfit.fromJson(Map<String, dynamic> json) =>
      _$CharacterOutfitFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterOutfitToJson(this);

  @override
  List<Object?> get props => [id, name, isDefault, priceDiamonds, thumbnail, sprites];
}

/// Персонаж новеллы
@JsonSerializable()
class Character extends Equatable {
  final String id;
  final String name;
  final String? color; // HEX-цвет имени в диалоге
  final List<CharacterSprite> sprites;

  /// v2: аутфиты персонажа (гардероб)
  final List<CharacterOutfit> outfits;

  const Character({
    required this.id,
    required this.name,
    this.color,
    this.sprites = const [],
    this.outfits = const [],
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

  /// Получить аутфит по id
  CharacterOutfit? getOutfit(String outfitId) {
    try {
      return outfits.firstWhere((o) => o.id == outfitId);
    } catch (_) {
      return null;
    }
  }

  /// Резолв спрайта с учётом экипированного аутфита (спека 1.5):
  /// outfit.sprites[spriteId] → outfit.sprites["default"] → базовый спрайт.
  String? resolveSpriteImage(String spriteId, {String? equippedOutfitId}) {
    if (equippedOutfitId != null) {
      final outfit = getOutfit(equippedOutfitId);
      if (outfit != null) {
        final exact = outfit.sprites[spriteId];
        if (exact != null && exact.isNotEmpty) return exact;
        final def = outfit.sprites['default'];
        if (def != null && def.isNotEmpty) return def;
      }
    }
    return getSprite(spriteId)?.image;
  }

  @override
  List<Object?> get props => [id, name, color, sprites, outfits];
}
