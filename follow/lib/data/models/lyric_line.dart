class LyricSegment {
  final Duration timestamp;
  final String text;

  const LyricSegment({required this.timestamp, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricSegment &&
          timestamp == other.timestamp &&
          text == other.text;

  @override
  int get hashCode => Object.hash(timestamp, text);
}

class LyricLine {
  final Duration timestamp;
  final String text;
  final List<LyricSegment> segments;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.segments = const [],
  });

  @override
  String toString() => 'LyricLine(${timestamp.inSeconds}s: $text)';
}
