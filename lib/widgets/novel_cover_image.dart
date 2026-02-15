import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Виджет обложки новеллы — загружает из файловой системы или assets
class NovelCoverImage extends StatefulWidget {
  final String novelId;
  final String? coverImage;
  final BoxFit fit;
  final Widget? placeholder;

  const NovelCoverImage({
    super.key,
    required this.novelId,
    required this.coverImage,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<NovelCoverImage> createState() => _NovelCoverImageState();
}

class _NovelCoverImageState extends State<NovelCoverImage> {
  File? _localFile;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  Future<void> _resolveImage() async {
    if (widget.coverImage == null) {
      setState(() => _checked = true);
      return;
    }

    // Проверяем скачанную новеллу
    final appDir = await getApplicationDocumentsDirectory();
    final localPath = '${appDir.path}/novels/${widget.novelId}/${widget.coverImage}';
    final file = File(localPath);
    if (await file.exists()) {
      if (mounted) setState(() { _localFile = file; _checked = true; });
      return;
    }

    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    // Файл из скачанной новеллы
    if (_localFile != null) {
      return Image.file(_localFile!, fit: widget.fit);
    }

    // Встроенный asset
    if (widget.coverImage != null && widget.coverImage!.startsWith('assets/')) {
      return Image.asset(widget.coverImage!, fit: widget.fit);
    }

    // Плейсхолдер
    return widget.placeholder ?? const SizedBox.shrink();
  }
}
