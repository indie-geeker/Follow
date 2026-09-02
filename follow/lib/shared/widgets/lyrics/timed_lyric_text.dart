import 'package:flutter/material.dart';
import 'package:follow/data/models/lyric_line.dart';

class TimedLyricText extends StatelessWidget {
  const TimedLyricText({
    super.key,
    required this.lyric,
    required this.playbackPosition,
    required this.style,
    required this.highlightedColor,
    required this.inactiveColor,
    required this.enableTimedHighlight,
  });

  final LyricLine lyric;
  final Duration playbackPosition;
  final TextStyle style;
  final Color highlightedColor;
  final Color inactiveColor;
  final bool enableTimedHighlight;

  @override
  Widget build(BuildContext context) {
    if (!enableTimedHighlight || lyric.segments.isEmpty) {
      return Text(lyric.text, style: style, textAlign: TextAlign.center);
    }

    return Text.rich(
      TextSpan(
        children: [
          for (final segment in lyric.segments)
            TextSpan(
              text: segment.text,
              style: style.copyWith(
                color: playbackPosition >= segment.timestamp
                    ? highlightedColor
                    : inactiveColor,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
