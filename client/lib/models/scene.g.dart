// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SceneTransition _$SceneTransitionFromJson(Map<String, dynamic> json) =>
    SceneTransition(
      type:
          $enumDecodeNullable(
            _$TransitionTypeEnumMap,
            json['type'],
            unknownValue: TransitionType.fade,
          ) ??
          TransitionType.fade,
      duration: (json['duration'] as num?)?.toInt() ?? 800,
    );

Map<String, dynamic> _$SceneTransitionToJson(SceneTransition instance) =>
    <String, dynamic>{
      'type': _$TransitionTypeEnumMap[instance.type]!,
      'duration': instance.duration,
    };

const _$TransitionTypeEnumMap = {
  TransitionType.fade: 'fade',
  TransitionType.slideLeft: 'slideLeft',
  TransitionType.slideRight: 'slideRight',
  TransitionType.dissolve: 'dissolve',
  TransitionType.none: 'none',
};

SceneCharacter _$SceneCharacterFromJson(Map<String, dynamic> json) =>
    SceneCharacter(
      characterId: json['characterId'] as String,
      spriteId: json['spriteId'] as String,
      position:
          $enumDecodeNullable(
            _$CharacterPositionEnumMap,
            json['position'],
            unknownValue: CharacterPosition.center,
          ) ??
          CharacterPosition.center,
      animation: json['animation'] as String?,
    );

Map<String, dynamic> _$SceneCharacterToJson(SceneCharacter instance) =>
    <String, dynamic>{
      'characterId': instance.characterId,
      'spriteId': instance.spriteId,
      'position': _$CharacterPositionEnumMap[instance.position]!,
      'animation': instance.animation,
    };

const _$CharacterPositionEnumMap = {
  CharacterPosition.left: 'left',
  CharacterPosition.center: 'center',
  CharacterPosition.right: 'right',
};

Condition _$ConditionFromJson(Map<String, dynamic> json) => Condition(
  variable: json['variable'] as String,
  operator: json['operator'] as String,
  value: json['value'],
);

Map<String, dynamic> _$ConditionToJson(Condition instance) => <String, dynamic>{
  'variable': instance.variable,
  'operator': instance.operator,
  'value': instance.value,
};

Choice _$ChoiceFromJson(Map<String, dynamic> json) => Choice(
  text: json['text'] as String,
  nextSceneId: json['nextSceneId'] as String,
  effects: json['effects'] as Map<String, dynamic>?,
  condition: json['condition'] == null
      ? null
      : Condition.fromJson(json['condition'] as Map<String, dynamic>),
  premium: json['premium'] as bool? ?? false,
  cost: (json['cost'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ChoiceToJson(Choice instance) => <String, dynamic>{
  'text': instance.text,
  'nextSceneId': instance.nextSceneId,
  'effects': instance.effects,
  'condition': instance.condition,
  'premium': instance.premium,
  'cost': instance.cost,
};

SceneEvent _$SceneEventFromJson(Map<String, dynamic> json) => SceneEvent(
  type: $enumDecode(
    _$EventTypeEnumMap,
    json['type'],
    unknownValue: EventType.dialogue,
  ),
  speaker: json['speaker'] as String?,
  text: json['text'] as String?,
  choices: (json['choices'] as List<dynamic>?)
      ?.map((e) => Choice.fromJson(e as Map<String, dynamic>))
      .toList(),
  asset: json['asset'] as String?,
  characterId: json['characterId'] as String?,
  spriteId: json['spriteId'] as String?,
  animation: json['animation'] as String?,
  effectType: $enumDecodeNullable(
    _$EffectTypeEnumMap,
    json['effectType'],
    unknownValue: EffectType.shake,
  ),
  effectDuration: (json['effectDuration'] as num?)?.toInt(),
  effectIntensity: (json['effectIntensity'] as num?)?.toDouble(),
);

Map<String, dynamic> _$SceneEventToJson(SceneEvent instance) =>
    <String, dynamic>{
      'type': _$EventTypeEnumMap[instance.type]!,
      'speaker': instance.speaker,
      'text': instance.text,
      'choices': instance.choices,
      'asset': instance.asset,
      'characterId': instance.characterId,
      'spriteId': instance.spriteId,
      'animation': instance.animation,
      'effectType': _$EffectTypeEnumMap[instance.effectType],
      'effectDuration': instance.effectDuration,
      'effectIntensity': instance.effectIntensity,
    };

const _$EventTypeEnumMap = {
  EventType.dialogue: 'dialogue',
  EventType.narration: 'narration',
  EventType.choice: 'choice',
  EventType.changeBackground: 'changeBackground',
  EventType.playSound: 'playSound',
  EventType.changeSprite: 'changeSprite',
  EventType.effect: 'effect',
};

const _$EffectTypeEnumMap = {
  EffectType.shake: 'shake',
  EffectType.flash: 'flash',
  EffectType.fadeToBlack: 'fadeToBlack',
  EffectType.rain: 'rain',
  EffectType.snow: 'snow',
  EffectType.particles: 'particles',
};

Scene _$SceneFromJson(Map<String, dynamic> json) => Scene(
  id: json['id'] as String,
  background: json['background'] as String?,
  music: json['music'] as String?,
  transition: json['transition'] == null
      ? null
      : SceneTransition.fromJson(json['transition'] as Map<String, dynamic>),
  charactersOnScreen:
      (json['charactersOnScreen'] as List<dynamic>?)
          ?.map((e) => SceneCharacter.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  events:
      (json['events'] as List<dynamic>?)
          ?.map((e) => SceneEvent.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  nextSceneId: json['nextSceneId'] as String?,
);

Map<String, dynamic> _$SceneToJson(Scene instance) => <String, dynamic>{
  'id': instance.id,
  'background': instance.background,
  'music': instance.music,
  'transition': instance.transition,
  'charactersOnScreen': instance.charactersOnScreen,
  'events': instance.events,
  'nextSceneId': instance.nextSceneId,
};
