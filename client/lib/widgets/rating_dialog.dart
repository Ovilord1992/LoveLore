import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../screens/auth_screen.dart';
import '../services/auth_service.dart';
import '../services/rating_service.dart';

/// Показать диалог оценки новеллы (5 звёзд + необязательный текст ≤500).
///
/// Гостю вместо формы предлагается войти. Возвращает обновлённую сводку
/// рейтинга при успешной оценке (иначе null).
Future<RatingSummary?> showRatingDialog(
  BuildContext context,
  WidgetRef ref,
  String novelId,
) async {
  final isLoggedIn = ref.read(authServiceProvider).isLoggedIn;
  if (!isLoggedIn) {
    await _showLoginPrompt(context);
    return null;
  }
  if (!context.mounted) return null;
  return showDialog<RatingSummary>(
    context: context,
    builder: (_) => _RatingDialog(novelId: novelId),
  );
}

Future<void> _showLoginPrompt(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceColor(ctx),
      title: const Text('Нужен аккаунт',
          style: TextStyle(color: Colors.white)),
      content: const Text(
        'Чтобы оценивать истории и оставлять отзывы, войдите в аккаунт.',
        style: TextStyle(color: Colors.white70, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Позже', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          },
          child: const Text('Войти', style: TextStyle(color: AppTheme.primary)),
        ),
      ],
    ),
  );
}

class _RatingDialog extends ConsumerStatefulWidget {
  final String novelId;

  const _RatingDialog({required this.novelId});

  @override
  ConsumerState<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<_RatingDialog> {
  int _stars = 0;
  final _textController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Предзаполняем текущую оценку пользователя (если была)
    ref
        .read(ratingServiceProvider)
        .fetchMyRating(widget.novelId)
        .then((value) {
      if (mounted && value != null && _stars == 0) {
        setState(() => _stars = value);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars < 1 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final service = ref.read(ratingServiceProvider);
    try {
      final summary = await service.rate(widget.novelId, _stars);
      if (summary == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = 'Не удалось отправить оценку. Попробуйте позже';
          });
        }
        return;
      }
      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        await service.submitReview(widget.novelId, text);
      }
      if (mounted) Navigator.of(context).pop(summary);
    } on RatingAuthRequiredException {
      if (mounted) {
        Navigator.of(context).pop();
        await _showLoginPrompt(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor(context),
      title: const Text('Оцените историю',
          style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 5 звёзд
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return IconButton(
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: filled ? AppTheme.gold : Colors.white38,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLength: 500,
              maxLines: 4,
              minLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Отзыв (необязательно)',
                hintStyle: const TextStyle(color: Colors.white24),
                counterStyle:
                    const TextStyle(color: Colors.white38, fontSize: 11),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _stars >= 1 && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary),
                )
              : Text(
                  'Отправить',
                  style: TextStyle(
                    color:
                        _stars >= 1 ? AppTheme.primary : Colors.white24,
                  ),
                ),
        ),
      ],
    );
  }
}
