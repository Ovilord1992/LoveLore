import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Провайдер сервиса гардероба
final wardrobeServiceProvider =
    StateNotifierProvider<WardrobeService, WardrobeState>((ref) {
  return WardrobeService();
});

/// Наряд персонажа
class Outfit {
  final String id;
  final String characterId;
  final String name;
  final String spriteOverride; // файл спрайта в наряде
  final String? description;
  final bool isDefault;

  const Outfit({
    required this.id,
    required this.characterId,
    required this.name,
    required this.spriteOverride,
    this.description,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'characterId': characterId,
        'name': name,
        'spriteOverride': spriteOverride,
        'description': description,
        'isDefault': isDefault,
      };

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
        id: json['id'] as String,
        characterId: json['characterId'] as String,
        name: json['name'] as String,
        spriteOverride: json['spriteOverride'] as String,
        description: json['description'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

/// Состояние гардероба
class WardrobeState {
  final Set<String> unlockedOutfitIds;
  final Map<String, String> equippedOutfits; // characterId → outfitId

  const WardrobeState({
    this.unlockedOutfitIds = const {},
    this.equippedOutfits = const {},
  });

  WardrobeState copyWith({
    Set<String>? unlockedOutfitIds,
    Map<String, String>? equippedOutfits,
  }) =>
      WardrobeState(
        unlockedOutfitIds: unlockedOutfitIds ?? this.unlockedOutfitIds,
        equippedOutfits: equippedOutfits ?? this.equippedOutfits,
      );

  Map<String, dynamic> toJson() => {
        'unlockedOutfitIds': unlockedOutfitIds.toList(),
        'equippedOutfits': equippedOutfits,
      };

  factory WardrobeState.fromJson(Map<String, dynamic> json) => WardrobeState(
        unlockedOutfitIds:
            Set<String>.from(json['unlockedOutfitIds'] as List? ?? []),
        equippedOutfits: Map<String, String>.from(
            json['equippedOutfits'] as Map? ?? {}),
      );
}

/// Каталог доступных нарядов (загружаются из JSON новеллы)
/// Пример записи в characters.json:
/// {
///   "id": "alex",
///   "outfits": [
///     { "id": "alex_casual", "name": "Повседневный", "spriteOverride": "alex_casual.png", "isDefault": true },
///     { "id": "alex_formal", "name": "Костюм", "spriteOverride": "alex_formal.png" }
///   ]
/// }
class WardrobeService extends StateNotifier<WardrobeState> {
  static const _boxName = 'wardrobe';
  static const _key = 'state';

  WardrobeService() : super(const WardrobeState()) {
    _load();
  }

  /// Разблокировать наряд
  bool unlockOutfit(String outfitId) {
    if (state.unlockedOutfitIds.contains(outfitId)) return false;
    final ids = Set<String>.from(state.unlockedOutfitIds)..add(outfitId);
    state = state.copyWith(unlockedOutfitIds: ids);
    _save();
    return true;
  }

  /// Надеть наряд на персонажа
  void equipOutfit(String characterId, String outfitId) {
    final equipped = Map<String, String>.from(state.equippedOutfits);
    equipped[characterId] = outfitId;
    state = state.copyWith(equippedOutfits: equipped);
    _save();
  }

  /// Снять наряд (вернуть стандартный)
  void unequipOutfit(String characterId) {
    final equipped = Map<String, String>.from(state.equippedOutfits);
    equipped.remove(characterId);
    state = state.copyWith(equippedOutfits: equipped);
    _save();
  }

  /// Получить текущий наряд персонажа
  String? getEquippedOutfit(String characterId) {
    return state.equippedOutfits[characterId];
  }

  /// Проверить, разблокирован ли наряд
  bool isUnlocked(String outfitId) {
    return state.unlockedOutfitIds.contains(outfitId);
  }

  Future<void> _save() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      await box.put(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final data = box.get(_key);
      if (data != null) {
        state =
            WardrobeState.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }
}
