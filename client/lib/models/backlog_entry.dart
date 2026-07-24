/// Запись в логе диалогов (backlog): реплика, нарратив или сделанный выбор.
/// Хранится в памяти движка (кап 200), не сериализуется.
class BacklogEntry {
  final String? speakerName;
  final String? speakerColor; // HEX
  final String text;
  final bool isChoice;
  final bool isNarration;

  const BacklogEntry({
    this.speakerName,
    this.speakerColor,
    required this.text,
    this.isChoice = false,
    this.isNarration = false,
  });
}
