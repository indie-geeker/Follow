import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';

const _lyrics = [
  LyricLine(timestamp: Duration(seconds: 0), text: 'Lyric 0'),
  LyricLine(timestamp: Duration(seconds: 5), text: 'Lyric 1'),
  LyricLine(timestamp: Duration(seconds: 10), text: 'Lyric 2'),
  LyricLine(timestamp: Duration(seconds: 15), text: 'Lyric 3'),
  LyricLine(timestamp: Duration(seconds: 20), text: 'Lyric 4'),
  LyricLine(timestamp: Duration(seconds: 25), text: 'Lyric 5'),
];

class _LyricsHarness extends StatelessWidget {
  const _LyricsHarness({required this.currentIndex, required this.seekCalls});

  final ValueNotifier<int> currentIndex;
  final List<Duration> seekCalls;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 300,
            child: ValueListenableBuilder<int>(
              valueListenable: currentIndex,
              builder: (context, index, _) {
                return InteractiveLyricsView(
                  lyrics: const AsyncData(_lyrics),
                  currentIndex: index,
                  foregroundColor: Colors.black,
                  onSeek: (position) async => seekCalls.add(position),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

double _verticalCenter(WidgetTester tester, Finder finder) {
  return tester.getRect(finder).center.dy;
}

void main() {
  testWidgets('centers the current lyric after initial layout', (tester) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(currentIndex: currentIndex, seekCalls: []),
    );
    await tester.pumpAndSettle();

    final viewportCenter = _verticalCenter(
      tester,
      find.byKey(lyricsViewportKey),
    );
    final currentRowCenter = _verticalCenter(
      tester,
      find.byKey(const ValueKey('lyric-row-2')),
    );

    expect(currentRowCenter, closeTo(viewportCenter, 2));
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('follows a changed current lyric index', (tester) async {
    final currentIndex = ValueNotifier(1);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(currentIndex: currentIndex, seekCalls: []),
    );
    await tester.pumpAndSettle();

    currentIndex.value = 4;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));

    final viewportCenter = _verticalCenter(
      tester,
      find.byKey(lyricsViewportKey),
    );
    final currentRowCenter = _verticalCenter(
      tester,
      find.byKey(const ValueKey('lyric-row-4')),
    );

    expect(currentRowCenter, closeTo(viewportCenter, 2));
  });
}
