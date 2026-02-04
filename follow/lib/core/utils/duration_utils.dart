/// Duration formatting utilities
String formatDuration(Duration d) {
  final mins = d.inMinutes;
  final secs = d.inSeconds % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}

/// Format duration from seconds
String formatDurationFromSeconds(int seconds) {
  return formatDuration(Duration(seconds: seconds));
}
