import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Провайдер сервиса гардероба
final wardrobeServiceProvider =
    StateNotifierProvider<WardrobeService, WardrobeState>((ref) {
  return WardrobeService();
});

/// Состояние гардероба.
///
/// - [unlockedOutfitIds] — ключи `<novelId>:<characterId>:<outfitId>`
///   (купленные или сюжетно разблокированные аутфиты).
/// - [equippedOutfits] — `<novelId>:<characterId>` → outfitId (per novel).
class WardrobeState {
  final Set<String> unlockedOutfitIds;
  final Map<String, String> equippedOutfits;

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

/// Сервис гардероба: разблокировка (покупка/сюжет) и экипировка аутфитов.
/// Каталог аутфитов живёт в `characters.json` новеллы (Character.outfits).
class WardrobeService extends StateNotifier<WardrobeState> {
  static const _boxName = 'wardrobe';
  static const _key = 'state';

  WardrobeService() : super(const WardrobeState()) {
    _loadSync();
  }

  /// Ключ разблокированного аутфита
  static String outfitKey(String novelId, String characterId, String outfitId) =>
      '$novelId:$characterId:$outfitId';

  /// Ключ экипировки персонажа (per novel)
  static String equipKey(String novelId, String characterId) =>
      '$novelId:$characterId';

  /// Разблокировать аутфит (покупка или Choice.unlockOutfits).
  /// Возвращает true, если аутфит новый.
  bool unlockOutfit(String novelId, String characterId, String outfitId) {
    final key = outfitKey(novelId, characterId, outfitId);
    if (state.unlockedOutfitIds.contains(key)) return false;
    final ids = Set<String>.from(state.unlockedOutfitIds)..add(key);
    state = state.copyWith(unlockedOutfitIds: ids);
    _save();
    return true;
  }

  /// Надеть аутфит на персонажа (в рамках новеллы)
  void equipOutfit(String novelId, String characterId, String outfitId) {
    final equipped = Map<String, String>.from(state.equippedOutfits);
    equipped[equipKey(novelId, characterId)] = outfitId;
    state = state.copyWith(equippedOutfits: equipped);
    _save();
  }

  /// Снять аутфит (вернуть базовые спрайты)
  void unequipOutfit(String novelId, String characterId) {
    final equipped = Map<String, String>.from(state.equippedOutfits);
    equipped.remove(equipKey(novelId, characterId));
    state = state.copyWith(equippedOutfits: equipped);
    _save();
  }

  /// Текущий экипированный аутфит персонажа (или null — базовый)
  String? getEquippedOutfit(String novelId, String characterId) {
    return state.equippedOutfits[equipKey(novelId, characterId)];
  }

  /// Разблокирован ли аутфит
  bool isUnlocked(String novelId, String characterId, String outfitId) {
    return state.unlockedOutfitIds
        .contains(outfitKey(novelId, characterId, outfitId));
  }

  Future<void> _save() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.put(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void _loadSync() {
    try {
      final box = Hive.box<String>(_boxName);
      final data = box.get(_key);
      if (data != null) {
        state =
            WardrobeState.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (_) {}
  }
}
