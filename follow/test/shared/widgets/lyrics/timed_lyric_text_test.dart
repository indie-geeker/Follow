import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/shared/widgets/lyrics/timed_lyric_text.dart';

const _highlightedColor = Color(0xFF112233);
const _inactiveColor = Color(0xFF778899);
const _baseStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

const _enhancedLyric = LyricLine(
  timestamp: Duration(seconds: 12),
  text: '我爱你',
  segments: [
    LyricSegment(timestamp: Duration(seconds: 12), text: '我'),
    LyricSegment(timestamp: Duration(milliseconds: 12300), text: '爱'),
    LyricSegment(timestamp: Duration(milliseconds: 12550), text: '你'),
  ],
);

Widget _buildText({
  LyricLine lyric = _enhancedLyric,
  Duration position = const Duration(milliseconds: 12400),
  bool enableTimedHighlight = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: TimedLyricText(
          lyric: lyric,
          playbackPosition: position,
          style: _baseStyle,
          highlightedColor: _highlightedColor,
          inactiveColor: _inactiveColor,
          enableTimedHighlight: enableTimedHighlight,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('highlights only segments reached by playback position', (
    tester,
  ) async {
    await tester.pumpWidget(_buildText());

    final text = tester.widget<Text>(find.byType(Text));
    final rootSpan = text.textSpan! as TextSpan;
    final segments = rootSpan.children!.cast<TextSpan>().toList();

    expect(segments.map((segment) => segment.text), ['我', '爱', '你']);
    expect(segments.map((segment) => segment.style!.color), [
      _highlightedColor,
      _highlightedColor,
      _inactiveColor,
    ]);
  });

  testWidgets('ordinary current lyric keeps one whole-line text style', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildText(
        lyric: const LyricLine(timestamp: Duration(seconds: 12), text: '普通歌词'),
      ),
    );

    final text = tester.widget<Text>(find.text('普通歌词'));
    expect(text.data, '普通歌词');
    expect(text.style, _baseStyle);
  });

  testWidgets('non-current enhanced lyric does not expose segment styling', (
    tester,
  ) async {
    await tester.pumpWidget(_buildText(enableTimedHighlight: false));

    final text = tester.widget<Text>(find.text('我爱你'));
    expect(text.data, '我爱你');
    expect(text.textSpan, isNull);
  });
}
