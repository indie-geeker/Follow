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
  const _LyricsHarness({
    required this.currentIndex,
    required this.seekCalls,
    this.lyrics = const AsyncData(_lyrics),
    this.lyricsNotifier,
  });

  final ValueNotifier<int> currentIndex;
  final List<Duration> seekCalls;
  final AsyncValue<List<LyricLine>> lyrics;
  final ValueNotifier<AsyncValue<List<LyricLine>>>? lyricsNotifier;

  Widget _buildView(int index, AsyncValue<List<LyricLine>> lyrics) {
    return InteractiveLyricsView(
      lyrics: lyrics,
      currentIndex: index,
      foregroundColor: Colors.black,
      onSeek: (position) async => seekCalls.add(position),
    );
  }

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
                final notifier = lyricsNotifier;
                if (notifier == null) return _buildView(index, lyrics);

                return ValueListenableBuilder<AsyncValue<List<LyricLine>>>(
                  valueListenable: notifier,
                  builder: (context, value, _) => _buildView(index, value),
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
    await tester.pumpAndSettle();

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

  testWidgets('does not seek when a lyric row is tapped in follow mode', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    final seekCalls = <Duration>[];
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(currentIndex: currentIndex, seekCalls: seekCalls),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lyric-row-2')));
    await tester.pump();

    expect(seekCalls, isEmpty);
  });

  testWidgets('centers the current lyric when loading changes to data', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(4);
    final lyricsNotifier = ValueNotifier<AsyncValue<List<LyricLine>>>(
      const AsyncLoading(),
    );
    addTearDown(currentIndex.dispose);
    addTearDown(lyricsNotifier.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyricsNotifier: lyricsNotifier,
        seekCalls: [],
      ),
    );
    await tester.pump();

    lyricsNotifier.value = const AsyncData(_lyrics);
    await tester.pumpAndSettle();

    final rowFinder = find.byKey(const ValueKey('lyric-row-4'));
    expect(rowFinder, findsOneWidget);
    expect(
      _verticalCenter(tester, rowFinder),
      closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
    );
  });

  testWidgets('uses updated wrapped-row geometry when the index changes', (
    tester,
  ) async {
    const wrappedLyrics = [
      LyricLine(timestamp: Duration.zero, text: 'Lyric 0'),
      LyricLine(timestamp: Duration(seconds: 5), text: 'Lyric 1'),
      LyricLine(
        timestamp: Duration(seconds: 10),
        text:
            'This wrapped lyric changes height when its larger bold current '
            'style is applied to the newly selected row',
      ),
      LyricLine(timestamp: Duration(seconds: 15), text: 'Lyric 3'),
      LyricLine(timestamp: Duration(seconds: 20), text: 'Lyric 4'),
      LyricLine(timestamp: Duration(seconds: 25), text: 'Lyric 5'),
    ];
    final currentIndex = ValueNotifier(0);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: const AsyncData(wrappedLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();
    final heightBefore = tester
        .getRect(find.byKey(const ValueKey('lyric-row-2')))
        .height;

    currentIndex.value = 2;
    await tester.pumpAndSettle();

    final rowFinder = find.byKey(const ValueKey('lyric-row-2'));
    expect(tester.getRect(rowFinder).height, greaterThan(heightBefore));
    expect(
      _verticalCenter(tester, rowFinder),
      closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
    );
  });

  testWidgets('centers a distant lyric that was not rendered', (tester) async {
    final manyLyrics = List.generate(
      120,
      (index) => LyricLine(
        timestamp: Duration(seconds: index * 5),
        text: index < 8
            ? 'Lyric $index'
            : List.filled(8, 'extended lyric $index').join(' '),
      ),
    );
    final currentIndex = ValueNotifier(1);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();
    const targetKey = ValueKey('lyric-row-110');
    expect(find.byKey(targetKey), findsNothing);

    currentIndex.value = 110;
    await tester.pumpAndSettle();

    expect(find.byKey(targetKey), findsOneWidget);
    expect(
      _verticalCenter(tester, find.byKey(targetKey)),
      closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
    );
  });
}
