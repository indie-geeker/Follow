import 'dart:async';

import 'package:flutter/gestures.dart';
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

final _manyLyrics = List.generate(
  12,
  (index) => LyricLine(
    timestamp: Duration(seconds: index * 5),
    text: 'Lyric $index',
  ),
);

class _LyricsHarness extends StatelessWidget {
  const _LyricsHarness({
    required this.currentIndex,
    required this.seekCalls,
    this.lyrics = const AsyncData(_lyrics),
    this.lyricsNotifier,
    this.onSeek,
  });

  final ValueNotifier<int> currentIndex;
  final List<Duration> seekCalls;
  final AsyncValue<List<LyricLine>> lyrics;
  final ValueNotifier<AsyncValue<List<LyricLine>>>? lyricsNotifier;
  final Future<void> Function(Duration)? onSeek;

  Widget _buildView(int index, AsyncValue<List<LyricLine>> lyrics) {
    return InteractiveLyricsView(
      lyrics: lyrics,
      currentIndex: index,
      foregroundColor: Colors.black,
      onSeek: onSeek ?? (position) async => seekCalls.add(position),
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

double _scrollOffset(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
}

Offset _viewportCenter(WidgetTester tester) {
  return tester.getCenter(find.byKey(lyricsViewportKey));
}

Listener _lyricsInputListener(WidgetTester tester) {
  Listener? listener;
  tester.element(find.byKey(lyricsViewportKey)).visitAncestorElements((
    ancestor,
  ) {
    if (ancestor.widget case final Listener candidate) {
      listener = candidate;
      return false;
    }
    return true;
  });
  return listener!;
}

TextStyle _lyricStyle(WidgetTester tester, int index) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('lyric-row-$index')),
          matching: find.byType(Text),
        ),
      )
      .style!;
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

  testWidgets('first lyric tap in follow mode seeks the tapped timestamp', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    final seekCalls = <Duration>[];
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(currentIndex: currentIndex, seekCalls: seekCalls),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lyric-row-4')));
    await tester.pump();

    expect(seekCalls, [const Duration(seconds: 20)]);
  });

  testWidgets('lyric row semantics activation uses the same seek path', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    final seekCalls = <Duration>[];
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(currentIndex: currentIndex, seekCalls: seekCalls),
    );
    await tester.pumpAndSettle();

    final rowSemantics = find.semantics.byLabel('跳转播放：Lyric 4');
    expect(rowSemantics, findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('lyric-row-4'))),
      isSemantics(label: '跳转播放：Lyric 4', isButton: true, hasTapAction: true),
    );

    tester.semantics.tap(rowSemantics);
    await tester.pump();

    expect(seekCalls, [const Duration(seconds: 20)]);
  });

  testWidgets('shows an accessible 44px center play control while browsing', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -96));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('从此处播放'), findsOneWidget);
    final playSemantics = find.bySemanticsLabel(RegExp(r'^从此处播放：Lyric 4$'));
    expect(playSemantics, findsOneWidget);
    expect(
      tester.getSemantics(playSemantics),
      isSemantics(label: '从此处播放：Lyric 4', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSize(find.byKey(lyricsCenterPlayKey)).shortestSide,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets(
    'center play seeks the visually selected lyric and exits browse',
    (tester) async {
      final currentIndex = ValueNotifier(2);
      final seekCalls = <Duration>[];
      addTearDown(currentIndex.dispose);

      await tester.pumpWidget(
        _LyricsHarness(
          currentIndex: currentIndex,
          lyrics: AsyncData(_manyLyrics),
          seekCalls: seekCalls,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -96));
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'^从此处播放：Lyric 4$')), findsOneWidget);

      await tester.tap(find.byKey(lyricsCenterPlayKey));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(seekCalls, [const Duration(seconds: 20)]);
      expect(find.byKey(lyricsCenterPlayKey), findsNothing);
      expect(
        _verticalCenter(tester, find.byKey(const ValueKey('lyric-row-4'))),
        closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
      );
    },
  );

  testWidgets('tapping a lyric while browsing uses the centered seek path', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    final seekCalls = <Duration>[];
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: seekCalls,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -48));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lyric-row-4')));
    await tester.pump();

    expect(seekCalls, [const Duration(seconds: 20)]);
    await tester.pump(const Duration(milliseconds: 219));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(microseconds: 1));
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    expect(
      _verticalCenter(tester, find.byKey(const ValueKey('lyric-row-4'))),
      closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
    );
  });

  testWidgets('ignores overlapping lyric seek activations', (tester) async {
    final currentIndex = ValueNotifier(2);
    final seekCalls = <Duration>[];
    final seekCompleter = Completer<void>();
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: seekCalls,
        onSeek: (position) {
          seekCalls.add(position);
          return seekCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lyric-row-4')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lyric-row-5')));
    await tester.pump();

    expect(seekCalls, [const Duration(seconds: 20)]);

    seekCompleter.complete();
    await tester.pumpAndSettle();

    expect(seekCalls, [const Duration(seconds: 20)]);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    expect(
      _verticalCenter(tester, find.byKey(const ValueKey('lyric-row-4'))),
      closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
    );
  });

  testWidgets('failed seek reports feedback then returns after fresh delay', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    final seekCalls = <Duration>[];
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: seekCalls,
        onSeek: (position) async {
          seekCalls.add(position);
          throw StateError('seek failed');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -96));
    await tester.pump();
    await tester.pump();
    final selectedSemantics = find.bySemanticsLabel(RegExp(r'^从此处播放：Lyric 4$'));
    expect(selectedSemantics, findsOneWidget);

    await tester.tap(find.byKey(lyricsCenterPlayKey));
    await tester.pump();
    await tester.pump();

    expect(seekCalls, [const Duration(seconds: 20)]);
    expect(find.byType(InteractiveLyricsView), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    expect(selectedSemantics, findsOneWidget);
    expect(find.text('无法跳转播放位置，请重试'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(microseconds: 1));
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('playing lyric style stays stronger than browse selection', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    _lyricsInputListener(tester).onPointerDown!(const PointerDownEvent());
    await tester.pump();
    expect(_lyricStyle(tester, 2).fontSize, 18);
    expect(_lyricStyle(tester, 2).fontWeight, FontWeight.bold);
    expect(_lyricStyle(tester, 2).color, Colors.black);

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -96));
    await tester.pump();
    await tester.pump();

    final playingStyle = _lyricStyle(tester, 2);
    final selectedStyle = _lyricStyle(tester, 4);
    final normalStyle = _lyricStyle(tester, 5);
    expect(playingStyle.fontSize, greaterThan(selectedStyle.fontSize!));
    expect(
      playingStyle.fontWeight!.value,
      greaterThan(selectedStyle.fontWeight!.value),
    );
    expect(playingStyle.color, Colors.black);
    expect(selectedStyle.fontSize, greaterThan(normalStyle.fontSize!));
    expect(
      selectedStyle.fontWeight!.value,
      greaterThan(normalStyle.fontWeight!.value),
    );
    expect(selectedStyle.color, Colors.black.withValues(alpha: 0.72));
    expect(normalStyle.color, Colors.black.withValues(alpha: 0.4));
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

  testWidgets(
    'dragging pauses playback follow and returns to the latest lyric after 3s',
    (tester) async {
      final currentIndex = ValueNotifier(2);
      addTearDown(currentIndex.dispose);

      await tester.pumpWidget(
        _LyricsHarness(
          currentIndex: currentIndex,
          lyrics: AsyncData(_manyLyrics),
          seekCalls: [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -160));
      await tester.pump();

      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
      final browsedOffset = _scrollOffset(tester);

      currentIndex.value = 7;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(_scrollOffset(tester), closeTo(browsedOffset, 0.01));
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(microseconds: 1));

      expect(find.byKey(lyricsCenterPlayKey), findsNothing);
      expect(
        _verticalCenter(tester, find.byKey(const ValueKey('lyric-row-7'))),
        closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
      );
    },
  );

  testWidgets('a second drag restarts the full inactivity delay', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -160));
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -48));
    await tester.pump(const Duration(milliseconds: 2900));

    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(microseconds: 1));
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('a no-movement pointer gesture returns after full inactivity', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    final viewport = tester.getRect(find.byKey(lyricsViewportKey));
    final gesture = await tester.startGesture(
      Offset(viewport.left + 4, viewport.center.dy),
    );
    await tester.pump();
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    await gesture.up();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('pointer-up defers inactivity delay to user scroll end', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    final listener = _lyricsInputListener(tester);
    final listContext = tester.element(find.byKey(lyricsViewportKey));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    listener.onPointerDown!(const PointerDownEvent());
    ScrollStartNotification(
      metrics: position,
      context: listContext,
      dragDetails: DragStartDetails(),
    ).dispatch(listContext);
    listener.onPointerUp!(const PointerUpEvent());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pumpAndSettle();
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    ScrollEndNotification(
      metrics: position,
      context: listContext,
      dragDetails: DragEndDetails(),
    ).dispatch(listContext);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('scale-only pan-zoom returns after full inactivity', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    final listener = _lyricsInputListener(tester);
    listener.onPointerPanZoomStart!(const PointerPanZoomStartEvent());
    await tester.pump();
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    listener.onPointerPanZoomUpdate!(
      const PointerPanZoomUpdateEvent(scale: 1.1),
    );
    listener.onPointerPanZoomEnd!(const PointerPanZoomEndEvent());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('pan-zoom with scrolling waits for scroll end inactivity', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    final listener = _lyricsInputListener(tester);
    final listContext = tester.element(find.byKey(lyricsViewportKey));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    listener.onPointerPanZoomStart!(const PointerPanZoomStartEvent());
    ScrollStartNotification(
      metrics: position,
      context: listContext,
    ).dispatch(listContext);
    listener.onPointerPanZoomUpdate!(
      const PointerPanZoomUpdateEvent(
        pan: Offset(0, 24),
        panDelta: Offset(0, 24),
      ),
    );
    listener.onPointerPanZoomEnd!(const PointerPanZoomEndEvent());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pumpAndSettle();
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    ScrollEndNotification(
      metrics: position,
      context: listContext,
    ).dispatch(listContext);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('return retries when playback advances during its animation', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -160));
    currentIndex.value = 7;
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    currentIndex.value = 9;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(microseconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    expect(
      _verticalCenter(tester, find.byKey(const ValueKey('lyric-row-9'))),
      closeTo(_verticalCenter(tester, find.byKey(lyricsViewportKey)), 2),
    );
  });

  testWidgets('fling starts the inactivity delay after ballistic scrolling', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    await tester.fling(
      find.byKey(lyricsViewportKey),
      const Offset(0, -360),
      1400,
    );
    await tester.pump();

    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    expect(position.isScrollingNotifier.value, isTrue);

    var ballisticFrames = 0;
    while (position.isScrollingNotifier.value && ballisticFrames < 180) {
      await tester.pump(const Duration(milliseconds: 16));
      ballisticFrames++;
    }
    expect(position.isScrollingNotifier.value, isFalse);
    final settledOffset = position.pixels;

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    expect(position.pixels, closeTo(settledOffset, 0.01));

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets(
    'pointer scroll enters browse mode and each signal resets delay',
    (tester) async {
      final currentIndex = ValueNotifier(2);
      addTearDown(currentIndex.dispose);

      await tester.pumpWidget(
        _LyricsHarness(
          currentIndex: currentIndex,
          lyrics: AsyncData(_manyLyrics),
          seekCalls: [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: _viewportCenter(tester),
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pump();
      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2900));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: _viewportCenter(tester),
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2900));

      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(microseconds: 1));
      expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    },
  );

  testWidgets('user input during return animation cancels the return', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(lyricsViewportKey), const Offset(0, -160));
    currentIndex.value = 9;
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));

    final gesture = await tester.startGesture(_viewportCenter(tester));
    await tester.pump();
    final interruptedOffset = _scrollOffset(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    expect(_scrollOffset(tester), closeTo(interruptedOffset, 0.01));
    await gesture.up();
  });

  testWidgets('programmatic follow notifications never enter browse mode', (
    tester,
  ) async {
    final currentIndex = ValueNotifier(2);
    addTearDown(currentIndex.dispose);

    await tester.pumpWidget(
      _LyricsHarness(
        currentIndex: currentIndex,
        lyrics: AsyncData(_manyLyrics),
        seekCalls: [],
      ),
    );
    await tester.pumpAndSettle();

    currentIndex.value = 9;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });
}
