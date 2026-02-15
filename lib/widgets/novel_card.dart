import 'package:flutter/material.dart';
import '../models/novel.dart';
import 'novel_cover_image.dart';

/// Карточка новеллы в библиотеке
class NovelCard extends StatelessWidget {
  final NovelMeta novel;
  final VoidCallback onTap;

  const NovelCard({
    super.key,
    required this.novel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF16213E), Color(0xFF1A1A2E)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Обложка
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 200,
                width: double.infinity,
                color: const Color(0xFF0F3460),
                child: NovelCoverImage(
                    novelId: novel.id,
                    coverImage: novel.coverImage,
                    fit: BoxFit.cover,
                    placeholder: const Center(
                        child: Icon(Icons.auto_stories,
                            size: 60, color: Colors.white24),
                      ),
                  ),
              ),
            ),
            // Информация
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    novel.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    novel.author,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    novel.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Теги
                  Wrap(
                    spacing: 8,
                    children: novel.tags.map((tag) {
                      return Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(0xFF0F3460),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
