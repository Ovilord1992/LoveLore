import 'package:flutter/material.dart';

/// Виджет диалогового окна с анимацией печати текста
class DialogueBox extends StatefulWidget {
  final String? speakerName;
  final Color? speakerColor;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onComplete;

  const DialogueBox({
    super.key,
    this.speakerName,
    this.speakerColor,
    required this.text,
    required this.onTap,
    this.onComplete,
  });

  @override
  State<DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<DialogueBox> {
  String _displayedText = '';
  int _charIndex = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(DialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _displayedText = '';
      _charIndex = 0;
      _isComplete = false;
      _startTyping();
    }
  }

  void _startTyping() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return false;
      if (_charIndex >= widget.text.length) {
        setState(() => _isComplete = true);
        widget.onComplete?.call();
        return false;
      }
      setState(() {
        _displayedText = widget.text.substring(0, _charIndex + 1);
        _charIndex++;
      });
      return true;
    });
  }

  void _skipToEnd() {
    setState(() {
      _displayedText = widget.text;
      _charIndex = widget.text.length;
      _isComplete = true;
    });
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_isComplete) {
          _skipToEnd();
        } else {
          widget.onTap();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.speakerName != null) ...[
              Text(
                widget.speakerName!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.speakerColor ?? const Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _displayedText,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            if (_isComplete)
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
