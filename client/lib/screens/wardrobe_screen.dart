import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../app/theme.dart';
import '../models/character.dart';
import '../services/currency_service.dart';
import '../services/locale_service.dart';
import '../services/wardrobe_service.dart';

/// Гардероб новеллы: персонажи → аутфиты (thumbnail, имя, цена),
/// покупка за алмазы (reason `spend_wardrobe`), экипировка per novel.
class WardrobeScreen extends ConsumerStatefulWidget {
  final String novelId;
  final List<Character> characters;

  /// Открыть сразу на конкретном персонаже (из игрового меню)
  final String? initialCharacterId;

  const WardrobeScreen({
    super.key,
    required this.novelId,
    required this.characters,
    this.initialCharacterId,
  });

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  late List<Character> _charactersWithOutfits;
  String? _selectedCharacterId;
  String? _docsPath;

  @override
  void initState() {
    super.initState();
    _charactersWithOutfits =
        widget.characters.where((c) => c.outfits.isNotEmpty).toList();
    if (_charactersWithOutfits.isNotEmpty) {
      final initial = widget.initialCharacterId;
      _selectedCharacterId = _charactersWithOutfits
              .any((c) => c.id == initial)
          ? initial
          : _charactersWithOutfits.first.id;
    }
    getApplicationDocumentsDirectory().then((dir) {
      if (mounted) setState(() => _docsPath = dir.path);
    });
  }

  Character? get _selected {
    if (_selectedCharacterId == null) return null;
    return _charactersWithOutfits
        .where((c) => c.id == _selectedCharacterId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final wardrobeState = ref.watch(wardrobeServiceProvider);
    final currency = ref.watch(currencyServiceProvider);
    final selected = _selected;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(ref.tr('wardrobe')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '💎 ${currency.diamonds}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _charactersWithOutfits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.checkroom, size: 80, color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    ref.tr('wardrobe_empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.white54),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Селектор персонажа
                SizedBox(
                  height: 52,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _charactersWithOutfits.length,
                    itemBuilder: (context, i) {
                      final c = _charactersWithOutfits[i];
                      final isActive = c.id == _selectedCharacterId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: isActive,
                          selectedColor: AppTheme.primary,
                          backgroundColor: const Color(0xFF16213E),
                          labelStyle: TextStyle(
                            color: isActive ? Colors.white : Colors.white54,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedCharacterId = c.id),
                        ),
                      );
                    },
                  ),
                ),
                if (selected != null)
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: selected.outfits.length,
                      itemBuilder: (context, index) {
                        final outfit = selected.outfits[index];
                        return _buildOutfitCard(
                            selected, outfit, wardrobeState);
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildOutfitCard(
    Character character,
    CharacterOutfit outfit,
    WardrobeState wardrobeState,
  ) {
    final wardrobe = ref.read(wardrobeServiceProvider.notifier);
    final isUnlocked = outfit.isFree ||
        wardrobe.isUnlocked(widget.novelId, character.id, outfit.id);
    final equippedId =
        wardrobeState.equippedOutfits[
            WardrobeService.equipKey(widget.novelId, character.id)];
    final isEquipped = equippedId == outfit.id;
    final price = outfit.priceDiamonds ?? 0;

    return GestureDetector(
      onTap: () {
        if (isUnlocked) {
          if (isEquipped) {
            wardrobe.unequipOutfit(widget.novelId, character.id);
          } else {
            wardrobe.equipOutfit(widget.novelId, character.id, outfit.id);
          }
        } else {
          _buyOutfit(character, outfit, price);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEquipped ? AppTheme.primary : Colors.white12,
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: _thumbnail(outfit, isUnlocked),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.name.isNotEmpty ? outfit.name : outfit.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnlocked ? Colors.white : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEquipped ? AppTheme.primary : Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isEquipped ? ref.tr('equipped') : ref.tr('equip'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isEquipped ? Colors.white : Colors.white70,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.lock,
                            size: 14, color: Colors.white38),
                        const SizedBox(width: 6),
                        Text(
                          '💎 $price',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.cyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(CharacterOutfit outfit, bool isUnlocked) {
    final placeholder = Container(
      color: const Color(0xFF2D1854).withValues(alpha: 0.4),
      child: Center(
        child: Icon(
          isUnlocked ? Icons.checkroom : Icons.lock,
          size: 40,
          color: isUnlocked ? Colors.white24 : Colors.white12,
        ),
      ),
    );

    // Превью: thumbnail → спрайт default из аутфита
    final imagePath = outfit.thumbnail ?? outfit.sprites['default'];
    if (imagePath == null || imagePath.isEmpty) return placeholder;

    final dim = isUnlocked ? null : Colors.black45;

    // Скачанные новеллы (Documents)
    if (_docsPath != null) {
      final file = File('$_docsPath/novels/${widget.novelId}/$imagePath');
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          color: dim,
          colorBlendMode: dim != null ? BlendMode.darken : null,
        );
      }
    }
    // Встроенные assets
    return Image.asset(
      'assets/novels/${widget.novelId}/$imagePath',
      fit: BoxFit.cover,
      color: dim,
      colorBlendMode: dim != null ? BlendMode.darken : null,
      errorBuilder: (_, _, _) => placeholder,
    );
  }

  void _buyOutfit(Character character, CharacterOutfit outfit, int price) {
    final currency = ref.read(currencyServiceProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          outfit.name.isNotEmpty ? outfit.name : outfit.id,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Купить наряд за $price 💎?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              ref.tr('cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!currency.canAfford(price)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${ref.tr('not_enough_diamonds')} 💎'),
                    backgroundColor: AppTheme.surfaceDark,
                  ),
                );
                return;
              }
              final refId = WardrobeService.outfitKey(
                  widget.novelId, character.id, outfit.id);
              final ok = currency.spendDiamonds(
                price,
                reason: 'spend_wardrobe',
                refId: refId,
              );
              if (!ok) return;
              ref
                  .read(wardrobeServiceProvider.notifier)
                  .unlockOutfit(widget.novelId, character.id, outfit.id);
              ref
                  .read(wardrobeServiceProvider.notifier)
                  .equipOutfit(widget.novelId, character.id, outfit.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Наряд «${outfit.name}» куплен!'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: Text(
              '💎 $price',
              style: const TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
