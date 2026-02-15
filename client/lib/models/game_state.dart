import 'package:equatable/equatable.dart';

/// Состояние игры — хранит прогресс игрока в конкретной новелле
class GameState extends Equatable {
  final String novelId;
  final String currentChapterId;
  final String currentSceneId;
  final int currentEventIndex;
  final Map<String, dynamic> variables;
  final List<String> history; // история пройденных сцен
  final DateTime lastPlayed;

  const GameState({
    required this.novelId,
    required this.currentChapterId,
    required this.currentSceneId,
    this.currentEventIndex = 0,
    this.variables = const {},
    this.history = const [],
    required this.lastPlayed,
  });

  /// Создать начальное состояние для новеллы
  factory GameState.initial({
    required String novelId,
    required String firstChapterId,
    required String firstSceneId,
    Map<String, dynamic>? initialVariables,
  }) {
    return GameState(
      novelId: novelId,
      currentChapterId: firstChapterId,
      currentSceneId: firstSceneId,
      variables: initialVariables ?? {},
      lastPlayed: DateTime.now(),
    );
  }

  GameState copyWith({
    String? currentChapterId,
    String? currentSceneId,
    int? currentEventIndex,
    Map<String, dynamic>? variables,
    List<String>? history,
    DateTime? lastPlayed,
  }) {
    return GameState(
      novelId: novelId,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentSceneId: currentSceneId ?? this.currentSceneId,
      currentEventIndex: currentEventIndex ?? this.currentEventIndex,
      variables: variables ?? this.variables,
      history: history ?? this.history,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  /// Получить числовое значение переменной
  num getNumericVar(String key, [num defaultValue = 0]) {
    final value = variables[key];
    if (value is num) return value;
    return defaultValue;
  }

  /// Получить строковое значение переменной
  String getStringVar(String key, [String defaultValue = '']) {
    final value = variables[key];
    if (value is String) return value;
    return defaultValue;
  }

  /// Получить булево значение переменной
  bool getBoolVar(String key, [bool defaultValue = false]) {
    final value = variables[key];
    if (value is bool) return value;
    return defaultValue;
  }

  Map<String, dynamic> toJson() => {
        'novelId': novelId,
        'currentChapterId': currentChapterId,
        'currentSceneId': currentSceneId,
        'currentEventIndex': currentEventIndex,
        'variables': variables,
        'history': history,
        'lastPlayed': lastPlayed.toIso8601String(),
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        novelId: json['novelId'] as String,
        currentChapterId: json['currentChapterId'] as String,
        currentSceneId: json['currentSceneId'] as String,
        currentEventIndex: json['currentEventIndex'] as int? ?? 0,
        variables: Map<String, dynamic>.from(json['variables'] as Map? ?? {}),
        history: List<String>.from(json['history'] as List? ?? []),
        lastPlayed: DateTime.parse(json['lastPlayed'] as String),
      );

  @override
  List<Object?> get props => [
        novelId,
        currentChapterId,
        currentSceneId,
        currentEventIndex,
        variables,
        history,
        lastPlayed,
      ];
}
