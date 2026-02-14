import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'scene.g.dart';

/// Позиция персонажа на экране
enum CharacterPosition { left, center, right }

/// Тип события в сцене
enum EventType { dialogue, narration, choice, changeBackground, playSound, changeSprite }

/// Персонаж на экране в данный момент
@JsonSerializable()
class SceneCharacter extends Equatable {
  final String characterId;
  final String spriteId;
  @JsonKey(unknownEnumValue: CharacterPosition.center)
  final CharacterPosition position;
  final String? animation;

  const SceneCharacter({
    required this.characterId,
    required this.spriteId,
    this.position = CharacterPosition.center,
    this.animation,
  });

  factory SceneCharacter.fromJson(Map<String, dynamic> json) =>
      _$SceneCharacterFromJson(json);
  Map<String, dynamic> toJson() => _$SceneCharacterToJson(this);

  @override
  List<Object?> get props => [characterId, spriteId, position, animation];
}

/// Условие для показа варианта выбора или перехода
@JsonSerializable()
class Condition extends Equatable {
  final String variable;
  final String operator; // >=, <=, ==, !=, >, <
  final dynamic value;

  const Condition({
    required this.variable,
    required this.operator,
    required this.value,
  });

  factory Condition.fromJson(Map<String, dynamic> json) =>
      _$ConditionFromJson(json);
  Map<String, dynamic> toJson() => _$ConditionToJson(this);

  @override
  List<Object?> get props => [variable, operator, value];
}

/// Вариант выбора
@JsonSerializable()
class Choice extends Equatable {
  final String text;
  final String nextSceneId;
  final Map<String, dynamic>? effects;
  final Condition? condition;
  final bool premium;
  final int cost;

  const Choice({
    required this.text,
    required this.nextSceneId,
    this.effects,
    this.condition,
    this.premium = false,
    this.cost = 0,
  });

  factory Choice.fromJson(Map<String, dynamic> json) =>
      _$ChoiceFromJson(json);
  Map<String, dynamic> toJson() => _$ChoiceToJson(this);

  @override
  List<Object?> get props => [text, nextSceneId, effects, condition, premium, cost];
}

/// Событие в сцене (диалог, выбор, смена фона и т.д.)
@JsonSerializable()
class SceneEvent extends Equatable {
  @JsonKey(unknownEnumValue: EventType.dialogue)
  final EventType type;
  final String? speaker;
  final String? text;
  final List<Choice>? choices;
  final String? asset; // для changeBackground, playSound
  final String? characterId;
  final String? spriteId;
  final String? animation;

  const SceneEvent({
    required this.type,
    this.speaker,
    this.text,
    this.choices,
    this.asset,
    this.characterId,
    this.spriteId,
    this.animation,
  });

  factory SceneEvent.fromJson(Map<String, dynamic> json) =>
      _$SceneEventFromJson(json);
  Map<String, dynamic> toJson() => _$SceneEventToJson(this);

  @override
  List<Object?> get props => [type, speaker, text, choices, asset, characterId, spriteId, animation];
}

/// Сцена — основная единица новеллы
@JsonSerializable()
class Scene extends Equatable {
  final String id;
  final String? background;
  final String? music;
  final List<SceneCharacter> charactersOnScreen;
  final List<SceneEvent> events;
  final String? nextSceneId; // автоматический переход если нет выбора

  const Scene({
    required this.id,
    this.background,
    this.music,
    this.charactersOnScreen = const [],
    this.events = const [],
    this.nextSceneId,
  });

  factory Scene.fromJson(Map<String, dynamic> json) =>
      _$SceneFromJson(json);
  Map<String, dynamic> toJson() => _$SceneToJson(this);

  @override
  List<Object?> get props => [id, background, music, charactersOnScreen, events, nextSceneId];
}
