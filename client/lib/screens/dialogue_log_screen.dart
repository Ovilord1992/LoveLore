import 'package:flutter/material.dart';
import '../models/backlog_entry.dart';

/// Лог диалогов (backlog): реплики, нарратив и сделанные выборы.
/// Данные — [SceneEngine.backlog] (кап 200), открывается из игрового UI.
class DialogueLogScreen extends StatelessWidget {
  final List<BacklogEntry> entries;

  const DialogueLogScreen({super.key, required this.entries});

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.white70;
    try {
      final cleaned = hex.replaceFirst('#', '');
      final value = int.parse(cleaned, radix: 16);
      return Color(cleaned.length == 6 ? (0xFF000000 | value) : value);
    } catch (_) {
      return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Лог диалогов',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: entries.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 48, color: Colors.white38),
          SizedBox(height: 12),
          Text(
            'Лог пуст',
            style: TextStyle(fontSize: 16, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildEntry(entries[index]),
    );
  }

  Widget _buildEntry(BacklogEntry entry) {
    final speakerColor = _parseColor(entry.speakerColor);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.isChoice
            ? const Color(0xFF2D1854)
            : const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: entry.isChoice
            ? Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.isNarration
                  ? Colors.white12
                  : speakerColor.withValues(alpha: 0.2),
            ),
            child: Center(
              child: entry.isNarration
                  ? const Icon(Icons.menu_book,
                      size: 16, color: Colors.white38)
                  : entry.isChoice
                      ? const Icon(Icons.arrow_forward,
                          size: 16, color: Color(0xFFE91E63))
                      : Text(
                          entry.speakerName?[0] ?? '?',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!entry.isNarration && entry.speakerName != null)
                  Text(
                    entry.speakerName!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: speakerColor,
                    ),
                  ),
                if (entry.isChoice)
                  Text(
                    '→ ${entry.text}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE91E63),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (entry.isNarration)
                  Text(
                    entry.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (!entry.isChoice && !entry.isNarration)
                  Text(
                    entry.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
