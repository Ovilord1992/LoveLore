import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/locale_service.dart';
import '../services/wardrobe_service.dart';

class WardrobeScreen extends ConsumerWidget {
  final String characterId;
  final String characterName;
  final List<Outfit> allOutfits;

  const WardrobeScreen({
    super.key,
    required this.characterId,
    required this.characterName,
    required this.allOutfits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeState = ref.watch(wardrobeServiceProvider);
    final wardrobe = ref.read(wardrobeServiceProvider.notifier);
    final equippedId = wardrobeState.equippedOutfits[characterId];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text('${ref.tr('wardrobe')} — $characterName'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: allOutfits.isEmpty
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
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: allOutfits.length,
              itemBuilder: (context, index) {
                final outfit = allOutfits[index];
                final isUnlocked =
                    outfit.isDefault || wardrobeState.unlockedOutfitIds.contains(outfit.id);
                final isEquipped = equippedId == outfit.id;

                return _OutfitCard(
                  outfit: outfit,
                  isUnlocked: isUnlocked,
                  isEquipped: isEquipped,
                  onTap: isUnlocked
                      ? () {
                          if (isEquipped) {
                            wardrobe.unequipOutfit(characterId);
                          } else {
                            wardrobe.equipOutfit(characterId, outfit.id);
                          }
                        }
                      : null,
                );
              },
            ),
    );
  }
}

class _OutfitCard extends ConsumerWidget {
  final Outfit outfit;
  final bool isUnlocked;
  final bool isEquipped;
  final VoidCallback? onTap;

  const _OutfitCard({
    required this.outfit,
    required this.isUnlocked,
    required this.isEquipped,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEquipped
                ? const Color(0xFFE91E63)
                : Colors.white12,
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Спрайт-плейсхолдер
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isUnlocked
                        ? [
                            const Color(0xFF2D1854).withValues(alpha: 0.5),
                            const Color(0xFF16213E),
                          ]
                        : [Colors.black45, Colors.black54],
                  ),
                ),
                child: Center(
                  child: Icon(
                    isUnlocked ? Icons.checkroom : Icons.lock,
                    size: 40,
                    color: isUnlocked ? Colors.white24 : Colors.white12,
                  ),
                ),
              ),
            ),

            // Название и кнопка
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit.name,
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (outfit.description != null)
                      Text(
                        outfit.description!,
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    if (isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isEquipped
                              ? const Color(0xFFE91E63)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isEquipped ? ref.tr('equipped') : ref.tr('equip'),
                          style: TextStyle(
                            fontSize: 11,
                            color: isEquipped ? Colors.white : Colors.white54,
                          ),
                        ),
                      )
                    else
                      const Row(
                        children: [
                          Icon(Icons.lock, size: 12, color: Colors.white24),
                          SizedBox(width: 4),
                          Text('Заблокировано',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white24)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
