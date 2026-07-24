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

  /// v2: текст «Ранее…» — показывается один раз перед первой сценой главы
  final String? recap;

  const Chapter({
    required this.id,
    required this.title,
    required this.number,
    required this.scenes,
    required this.firstSceneId,
    this.recap,
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
  List<Object?> get props => [id, title, number, scenes, firstSceneId, recap];
}

/// v2: описание концовки в meta.json (для галереи «N из M»)
@JsonSerializable()
class NovelEnding extends Equatable {
  final String id;
  final String title;
  final bool hidden;

  const NovelEnding({
    required this.id,
    this.title = '',
    this.hidden = false,
  });

  factory NovelEnding.fromJson(Map<String, dynamic> json) =>
      _$NovelEndingFromJson(json);
  Map<String, dynamic> toJson() => _$NovelEndingToJson(this);

  @override
  List<Object?> get props => [id, title, hidden];
}

/// v2: конфиг отображения стата в панели отношений (meta.statsDisplay)
@JsonSerializable()
class StatDisplayConfig extends Equatable {
  final String variable;
  final String label;

  /// heart | star | flame | diamond | moon | sun | leaf
  final String? icon;
  final String? color; // HEX
  final num max;

  const StatDisplayConfig({
    required this.variable,
    this.label = '',
    this.icon,
    this.color,
    this.max = 100,
  });

  factory StatDisplayConfig.fromJson(Map<String, dynamic> json) =>
      _$StatDisplayConfigFromJson(json);
  Map<String, dynamic> toJson() => _$StatDisplayConfigToJson(this);

  @override
  List<Object?> get props => [variable, label, icon, color, max];
}

/// v2: запрос имени игрока при первом старте новеллы
@JsonSerializable()
class PlayerNamePrompt extends Equatable {
  final bool enabled;
  final String? prompt;
  final String? defaultName;

  const PlayerNamePrompt({
    this.enabled = false,
    this.prompt,
    this.defaultName,
  });

  factory PlayerNamePrompt.fromJson(Map<String, dynamic> json) =>
      _$PlayerNamePromptFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerNamePromptToJson(this);

  @override
  List<Object?> get props => [enabled, prompt, defaultName];
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
  // Back-compat: старые meta.json (и editor exporter <= v1) использовали "totalChapters".
  // Сервер и новый клиент пишут "chaptersCount". Принимаем оба ключа при чтении.
  @JsonKey(readValue: _readChaptersCount)
  final int chaptersCount;
  final int releasedChapters;
  final String? dialogueTheme;

  /// Цвет рамки диалога (hex, например "#B8860B"). Если задан — перекрывает тему.
  final String? dialogueFrameColor;

  /// Цвет фона диалога (hex, например "#1A1410"). Если задан — перекрывает тему.
  final String? dialogueBgColor;

  /// Стиль позиционирования диалога: "classic" (снизу), "center" (по центру как в Romance Club)
  final String? dialogueStyle;

  /// Локализованное название (заполняется из перевода если доступен)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? localizedTitle;

  /// Локализованное описание (заполняется из перевода если доступен)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? localizedDescription;

  /// v2: список всех концовок новеллы (для прогресса «N из M»)
  final List<NovelEnding> endings;

  /// v2: статы для панели отношений
  final List<StatDisplayConfig> statsDisplay;

  /// v2: запрос имени игрока при первом старте
  final PlayerNamePrompt? playerNamePrompt;

  const NovelMeta({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    this.coverImage,
    this.coverUrl,
    this.tags = const [],
    this.chaptersCount = 0,
    this.releasedChapters = 0,
    this.dialogueTheme,
    this.dialogueFrameColor,
    this.dialogueBgColor,
    this.dialogueStyle,
    this.localizedTitle,
    this.localizedDescription,
    this.endings = const [],
    this.statsDisplay = const [],
    this.playerNamePrompt,
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
      case 'victorian': return DialogueFrameTheme.victorian;
      case 'gothic': return DialogueFrameTheme.gothic;
      case 'noir': return DialogueFrameTheme.noir;
      case 'sakura': return DialogueFrameTheme.sakura;
      case 'celestial': return DialogueFrameTheme.celestial;
      case 'cyberpunk': return DialogueFrameTheme.cyberpunk;
      case 'steampunk': return DialogueFrameTheme.steampunk;
      case 'pirate': return DialogueFrameTheme.pirate;
      case 'medieval': return DialogueFrameTheme.medieval;
      case 'egyptian': return DialogueFrameTheme.egyptian;
      case 'baroque': return DialogueFrameTheme.baroque;
      case 'romantic': return DialogueFrameTheme.romantic;
      case 'nordic': return DialogueFrameTheme.nordic;
      case 'tropical': return DialogueFrameTheme.tropical;
      case 'bloodMoon': return DialogueFrameTheme.bloodMoon;
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
      chaptersCount: chaptersCount,
      releasedChapters: releasedChapters,
      dialogueTheme: dialogueTheme,
      dialogueFrameColor: dialogueFrameColor,
      dialogueBgColor: dialogueBgColor,
      dialogueStyle: dialogueStyle,
      localizedTitle: translatedTitle,
      localizedDescription: translatedDescription,
      endings: endings,
      statsDisplay: statsDisplay,
      playerNamePrompt: playerNamePrompt,
    );
  }

  @override
  List<Object?> get props => [id, title, description, author, coverImage, coverUrl, tags, chaptersCount, releasedChapters, dialogueTheme, dialogueFrameColor, dialogueBgColor, dialogueStyle, localizedTitle, localizedDescription, endings, statsDisplay, playerNamePrompt];
}

/// Читает количество глав из JSON, поддерживая legacy-ключ "totalChapters".
Object? _readChaptersCount(Map map, String key) {
  return map[key] ?? map['totalChapters'];
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
