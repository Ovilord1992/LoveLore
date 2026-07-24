import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'scene.g.dart';

/// Позиция персонажа на экране
enum CharacterPosition { left, center, right }

/// Тип события в сцене
enum EventType { dialogue, narration, choice, changeBackground, playSound, changeSprite, effect, showCg, cameraMove, showEmotion, setVariable }

/// Тип перехода между сценами
enum TransitionType { fade, slideLeft, slideRight, dissolve, none }

/// Тип визуального эффекта
enum EffectType { shake, flash, fadeToBlack, rain, snow, particles }

/// Тип перехода CG-арта
enum CgTransition { fade, zoomIn }

/// Тип эмоции-иконки
enum EmotionType { heart, sweatDrop, question, exclamation, anger, sparkle, musicNote, zzz }

/// Тема диалогового окна — стиль рамки для каждой новеллы
enum DialogueFrameTheme {
  /// Золотая классика — L-углы, ромбы, филигрань
  ornate,
  /// Art Deco — геометрические ступеньки, 1920-е
  artDeco,
  /// Современный минимализм — чистые линии
  modern,
  /// Glassmorphism — стекло/blur
  glassmorphism,
  /// Фэнтези — завитки, звёзды, мистика
  fantasy,
  /// Викторианская эпоха — тёплый филигранный узор
  victorian,
  /// Готика — стрельчатые арки, тёмная романтика
  gothic,
  /// Нуар — минимализм, серый, типографика
  noir,
  /// Сакура — лепестки, японский стиль
  sakura,
  /// Небесная — луна, звёзды, серебро
  celestial,
  /// Киберпанк — неон, глитч, углы
  cyberpunk,
  /// Стимпанк — шестерёнки, медь, заклёпки
  steampunk,
  /// Пиратская — верёвки, компас, дерево
  pirate,
  /// Средневековье — пергамент, щиты, кресты
  medieval,
  /// Египетская — лотос, золото, лазурит
  egyptian,
  /// Барокко — акант, раковины, позолота
  baroque,
  /// Романтика — сердца, розовый, кружево
  romantic,
  /// Скандинавская — руны, ледяной узел
  nordic,
  /// Тропики — листья, волны, коралл
  tropical,
  /// Кровавая луна — шипы, багрянец, тьма
  bloodMoon,
}

/// Настройки перехода между сценами
@JsonSerializable()
class SceneTransition extends Equatable {
  @JsonKey(unknownEnumValue: TransitionType.fade)
  final TransitionType type;
  final int duration; // мс

  const SceneTransition({
    this.type = TransitionType.fade,
    this.duration = 800,
  });

  factory SceneTransition.fromJson(Map<String, dynamic> json) =>
      _$SceneTransitionFromJson(json);
  Map<String, dynamic> toJson() => _$SceneTransitionToJson(this);

  @override
  List<Object?> get props => [type, duration];
}

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

  /// v2: составные условия (приоритет над одиночным [condition])
  final List<Condition>? conditions;

  /// v2: логика составных условий: "and" (по умолчанию) | "or"
  final String? conditionsLogic;

  /// v2: сюжетная разблокировка аутфитов, формат "characterId:outfitId"
  final List<String>? unlockOutfits;

  const Choice({
    required this.text,
    required this.nextSceneId,
    this.effects,
    this.condition,
    this.premium = false,
    this.cost = 0,
    this.conditions,
    this.conditionsLogic,
    this.unlockOutfits,
  });

  factory Choice.fromJson(Map<String, dynamic> json) =>
      _$ChoiceFromJson(json);
  Map<String, dynamic> toJson() => _$ChoiceToJson(this);

  @override
  List<Object?> get props => [text, nextSceneId, effects, condition, premium, cost, conditions, conditionsLogic, unlockOutfits];
}

/// v2: ветка перехода в конце сцены (branches)
@JsonSerializable()
class SceneBranch extends Equatable {
  final List<Condition>? conditions;
  final String? conditionsLogic; // "and" | "or"
  final Condition? condition; // одиночное условие (легаси-стиль)
  final String nextSceneId;

  const SceneBranch({
    this.conditions,
    this.conditionsLogic,
    this.condition,
    required this.nextSceneId,
  });

  factory SceneBranch.fromJson(Map<String, dynamic> json) =>
      _$SceneBranchFromJson(json);
  Map<String, dynamic> toJson() => _$SceneBranchToJson(this);

  @override
  List<Object?> get props => [conditions, conditionsLogic, condition, nextSceneId];
}

/// v2: концовка новеллы, привязанная к сцене
@JsonSerializable()
class SceneEnding extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? image;

  const SceneEnding({
    required this.id,
    this.title = '',
    this.description,
    this.image,
  });

  factory SceneEnding.fromJson(Map<String, dynamic> json) =>
      _$SceneEndingFromJson(json);
  Map<String, dynamic> toJson() => _$SceneEndingToJson(this);

  @override
  List<Object?> get props => [id, title, description, image];
}

/// Событие в сцене (диалог, выбор, смена фона, эффект и т.д.)
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
  // Установка переменной (событие setVariable)
  final String? variable;
  final dynamic value; // строка "+1"/"-2"/"toggle" или прямое значение
  // Поля для события effect
  @JsonKey(unknownEnumValue: EffectType.shake)
  final EffectType? effectType;
  final int? effectDuration; // мс
  final double? effectIntensity; // 0.0–1.0
  // CG-арт
  final String? cgImage;
  @JsonKey(unknownEnumValue: CgTransition.fade)
  final CgTransition? cgTransition;
  final int? cgDuration; // мс
  // Камера
  final double? zoom; // 0.5–2.0
  final double? panX; // смещение по X
  final double? panY; // смещение по Y
  final int? cameraDuration; // мс
  // Эмоции
  @JsonKey(unknownEnumValue: EmotionType.heart)
  final EmotionType? emotionType;
  // Cross-fade спрайтов
  final int? spriteDuration; // мс
  // Таймер на выбор
  final int? timeLimit; // секунды
  final int? defaultChoiceIndex;
  // v2: озвучка реплики (dialogue/narration), путь внутри новеллы
  final String? voice;
  // v2: эмоция картинкой (showEmotion), путь внутри новеллы
  final String? image;

  const SceneEvent({
    required this.type,
    this.speaker,
    this.text,
    this.choices,
    this.asset,
    this.characterId,
    this.spriteId,
    this.animation,
    this.variable,
    this.value,
    this.effectType,
    this.effectDuration,
    this.effectIntensity,
    this.cgImage,
    this.cgTransition,
    this.cgDuration,
    this.zoom,
    this.panX,
    this.panY,
    this.cameraDuration,
    this.emotionType,
    this.spriteDuration,
    this.timeLimit,
    this.defaultChoiceIndex,
    this.voice,
    this.image,
  });

  factory SceneEvent.fromJson(Map<String, dynamic> json) =>
      _$SceneEventFromJson(json);
  Map<String, dynamic> toJson() => _$SceneEventToJson(this);

  @override
  List<Object?> get props => [type, speaker, text, choices, asset, characterId, spriteId, animation, variable, value, effectType, effectDuration, effectIntensity, cgImage, cgTransition, cgDuration, zoom, panX, panY, cameraDuration, emotionType, spriteDuration, timeLimit, defaultChoiceIndex, voice, image];
}

/// Слой фона для параллакса
@JsonSerializable()
class BackgroundLayer extends Equatable {
  final String image;
  final double depth; // 0.0 (задний план) — 1.0 (передний)
  final double offsetX;
  final double offsetY;

  const BackgroundLayer({
    required this.image,
    this.depth = 0.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  factory BackgroundLayer.fromJson(Map<String, dynamic> json) =>
      _$BackgroundLayerFromJson(json);
  Map<String, dynamic> toJson() => _$BackgroundLayerToJson(this);

  @override
  List<Object?> get props => [image, depth, offsetX, offsetY];
}

/// Сцена — основная единица новеллы
@JsonSerializable()
class Scene extends Equatable {
  final String id;
  final String? background;
  final String? music;
  final SceneTransition? transition;
  final List<BackgroundLayer>? backgroundLayers;
  final List<SceneCharacter> charactersOnScreen;
  final List<SceneEvent> events;
  final String? nextSceneId; // автоматический переход если нет выбора
  // v2: ветвление по переменным в конце сцены (приоритет над nextSceneId)
  final List<SceneBranch>? branches;
  // v2: концовка — при достижении конца сцены завершает прохождение
  final SceneEnding? ending;

  const Scene({
    required this.id,
    this.background,
    this.music,
    this.transition,
    this.backgroundLayers,
    this.charactersOnScreen = const [],
    this.events = const [],
    this.nextSceneId,
    this.branches,
    this.ending,
  });

  factory Scene.fromJson(Map<String, dynamic> json) =>
      _$SceneFromJson(json);
  Map<String, dynamic> toJson() => _$SceneToJson(this);

  @override
  List<Object?> get props => [id, background, music, transition, backgroundLayers, charactersOnScreen, events, nextSceneId, branches, ending];
}
