import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_profile_service.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final cgs = profile.unlockedCGs.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Галерея'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: cgs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 80, color: Colors.white12),
                  const SizedBox(height: 16),
                  const Text(
                    'Галерея пуста',
                    style: TextStyle(fontSize: 20, color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Разблокируй CG-арты в историях,\nчтобы они появились здесь',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white38),
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
                childAspectRatio: 0.75,
              ),
              itemCount: cgs.length,
              itemBuilder: (context, index) {
                final cgId = cgs[index];
                return _CGCard(
                  cgId: cgId,
                  onTap: () => _showFullScreen(context, cgId),
                );
              },
            ),
    );
  }

  void _showFullScreen(BuildContext context, String cgId) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => _FullScreenCG(cgId: cgId),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _CGCard extends StatelessWidget {
  final String cgId;
  final VoidCallback onTap;

  const _CGCard({required this.cgId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            // Плейсхолдер для CG-арта (заменить на Image.asset/network)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2D1854),
                      const Color(0xFFE91E63).withValues(alpha: 0.5),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 40, color: Colors.white24),
                ),
              ),
            ),
            // Название
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                _formatCGName(cgId),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCGName(String id) {
    return id
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

class _FullScreenCG extends StatelessWidget {
  final String cgId;

  const _FullScreenCG({required this.cgId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Плейсхолдер (заменить на реальное изображение)
              Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2D1854), Color(0xFFE91E63)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 80, color: Colors.white24),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _formatCGName(cgId),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Нажмите, чтобы закрыть',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCGName(String id) {
    return id
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
