class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => 'LyricLine(${timestamp.inSeconds}s: $text)';
}
