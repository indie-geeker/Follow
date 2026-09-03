import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/shared/widgets/player/folded_track_queue.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

final _tracks = List.generate(
  8,
  (index) => Track(id: 'track-$index', title: 'Track $index'),
);
const _palette = PlayerPalette(
  primaryControl: Color(0xFF173E89),
  onPrimaryControl: Colors.white,
  secondary: Color(0xFF8A2362),
  ambient: Color(0xFF16869B),
  progress: Color(0xFF8A2362),
  glow: Color(0xFF16869B),
  scrim: Color(0xFFF7F6FC),
);

void main() {
  Future<void> pumpQueue(
    WidgetTester tester, {
    List<Track> tracks = const [],
    String? currentTrackId,
    ValueChanged<int>? onSelect,
    VoidCallback? onInteractionStart,
    VoidCallback? onInteractionSettled,
    VoidCallback? onScrollSettled,
    double revealProgress = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 300,
              child: FoldedTrackQueue(
                palette: _palette,
                tracks: tracks,
                currentTrackId: currentTrackId,
                revealProgress: revealProgress,
                onSelect: onSelect ?? (_) {},
                onInteractionStart: onInteractionStart,
                onInteractionSettled: onInteractionSettled,
                onScrollSettled: onScrollSettled,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders an explanatory empty queue state', (tester) async {
    await pumpQueue(tester);

    final state = tester.widget<AppStateView>(find.byType(AppStateView));
    expect(state.kind, AppStateKind.nothingPlaying);
    expect(find.byKey(foldedQueueListKey), findsNothing);
  });

  testWidgets('leaves the folded queue backdrop fully transparent', (
    tester,
  ) async {
    await pumpQueue(
      tester,
      tracks: _tracks.take(3).toList(),
      currentTrackId: 'track-1',
    );

    expect(find.text('当前播放队列'), findsNothing);
    expect(find.byTooltip('收起歌曲列表'), findsNothing);
    expect(find.text('Track 0'), findsNothing);
    expect(find.text('Track 1'), findsNothing);
    final surfaceFinder = find.byKey(
      const ValueKey('folded-queue-palette-surface'),
    );
    expect(surfaceFinder, findsOneWidget);
    expect(tester.widget(surfaceFinder), isNot(isA<DecoratedBox>()));
    expect(
      find.descendant(
        of: find.byKey(foldedTrackQueueKey),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('marks current track and scales neighbors smaller', (
    tester,
  ) async {
    await pumpQueue(
      tester,
      tracks: _tracks.take(3).toList(),
      currentTrackId: 'track-1',
    );

    expect(find.bySemanticsLabel('当前歌曲：Track 1，点击播放'), findsOneWidget);

    final currentTransform = tester.widget<Transform>(
      find.byKey(foldedQueueScaleKey('track-1')),
    );
    final neighborTransform = tester.widget<Transform>(
      find.byKey(foldedQueueScaleKey('track-0')),
    );
    expect(
      currentTransform.transform.storage[0],
      greaterThan(neighborTransform.transform.storage[0]),
    );
    final currentAccent = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('folded-queue-accent-track-1')),
    );
    final decoration = currentAccent.decoration as BoxDecoration;
    expect(decoration.border?.top.color, _palette.secondary);
  });

  testWidgets('centers the current track in the queue viewport', (
    tester,
  ) async {
    await pumpQueue(tester, tracks: _tracks, currentTrackId: 'track-3');

    expect(
      tester.getCenter(find.byKey(foldedQueueTrackKey('track-3'))).dy,
      closeTo(tester.getCenter(find.byKey(foldedTrackQueueKey)).dy, 1),
    );
  });

  testWidgets('an upward drag moves the departing cover to the right arc', (
    tester,
  ) async {
    await pumpQueue(
      tester,
      tracks: _tracks.take(2).toList(),
      currentTrackId: 'track-0',
    );

    double largestHorizontalTranslation(String trackId) {
      return tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.byKey(foldedQueueTrackKey(trackId)),
              matching: find.byType(Transform),
            ),
          )
          .map((transform) => transform.transform.storage[12])
          .reduce((a, b) => a > b ? a : b);
    }

    final beforeDrag = largestHorizontalTranslation('track-0');
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(foldedQueueListKey)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -34));
    await tester.pump();

    expect(largestHorizontalTranslation('track-0'), greaterThan(beforeDrag));

    await gesture.cancel();
  });

  testWidgets('reveal progress controls queue opacity and interaction', (
    tester,
  ) async {
    await pumpQueue(
      tester,
      tracks: _tracks.take(3).toList(),
      currentTrackId: 'track-1',
      revealProgress: 0.35,
    );

    expect(
      tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity,
      closeTo(0.35, 0.001),
    );
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(foldedQueueInteractionKey))
          .ignoring,
      isTrue,
    );
  });

  testWidgets(
    'unchanged reveal target does not restart the closing animation',
    (tester) async {
      await pumpQueue(
        tester,
        tracks: _tracks.take(3).toList(),
        currentTrackId: 'track-1',
      );
      await pumpQueue(
        tester,
        tracks: _tracks.take(3).toList(),
        currentTrackId: 'track-1',
        revealProgress: 0,
      );
      await tester.pump(const Duration(milliseconds: 100));

      await pumpQueue(
        tester,
        tracks: _tracks.take(3).toList(),
        currentTrackId: 'track-1',
        revealProgress: 0,
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity,
        0,
      );
    },
  );

  testWidgets('shows the centered title while held and plays after settle', (
    tester,
  ) async {
    int? selectedIndex;
    await pumpQueue(
      tester,
      tracks: _tracks,
      currentTrackId: 'track-2',
      onSelect: (index) => selectedIndex = index,
    );

    const titleSlotKey = ValueKey('folded-queue-title-slot-track-3');
    expect(find.byKey(titleSlotKey), findsOneWidget);
    expect(tester.getSize(find.byKey(titleSlotKey)).height, 20);
    expect(find.text('Track 3'), findsNothing);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(foldedQueueListKey)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -72));
    await tester.pump();

    expect(find.text('Track 3'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Track 3')).dx,
      closeTo(
        tester.getCenter(find.byKey(foldedQueueTrackKey('track-3'))).dx,
        1,
      ),
    );
    expect(
      tester.getTopLeft(find.text('Track 3')).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(foldedQueueTrackKey('track-3'))).dy,
      ),
    );
    expect(selectedIndex, isNull);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Track 3'), findsNothing);
    expect(selectedIndex, 3);
    expect(
      tester.getCenter(find.byKey(foldedQueueTrackKey('track-3'))).dy,
      closeTo(tester.getCenter(find.byKey(foldedTrackQueueKey)).dy, 1),
    );
  });

  testWidgets('keeps an eight-character centered title unchanged while held', (
    tester,
  ) async {
    const title = '一二三四五六七八';
    const track = Track(id: 'exact-eight', title: title);
    await pumpQueue(tester, tracks: const [track], currentTrackId: track.id);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(foldedQueueListKey)),
    );
    await tester.pump();

    expect(find.text(title), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('folded-queue-title-slot-exact-eight')),
          )
          .width,
      112,
    );

    await gesture.cancel();
  });

  testWidgets('truncates a longer centered title after eight characters', (
    tester,
  ) async {
    const title = '一二三四五六七八九';
    const track = Track(id: 'over-eight', title: title);
    await pumpQueue(tester, tracks: const [track], currentTrackId: track.id);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(foldedQueueListKey)),
    );
    await tester.pump();

    expect(find.text('一二三四五六七八…'), findsOneWidget);
    expect(find.text(title), findsNothing);
    expect(find.bySemanticsLabel('当前歌曲：$title，点击播放'), findsOneWidget);

    await gesture.cancel();
  });

  testWidgets('tapping a cover centers and plays it once', (tester) async {
    final selections = <int>[];
    var starts = 0;
    var settles = 0;
    var scrollSettles = 0;
    await pumpQueue(
      tester,
      tracks: _tracks,
      currentTrackId: 'track-2',
      onSelect: selections.add,
      onInteractionStart: () => starts++,
      onInteractionSettled: () => settles++,
      onScrollSettled: () => scrollSettles++,
    );

    await tester.tap(find.byKey(foldedQueueTrackKey('track-3')));
    await tester.pumpAndSettle();

    expect(selections, [3]);
    expect(starts, 1);
    expect(settles, 1);
    expect(scrollSettles, 0);
    expect(
      tester.getCenter(find.byKey(foldedQueueTrackKey('track-3'))).dy,
      closeTo(tester.getCenter(find.byKey(foldedTrackQueueKey)).dy, 1),
    );
  });

  testWidgets('reports drag start immediately and settle after snapping', (
    tester,
  ) async {
    var starts = 0;
    var settles = 0;
    var scrollSettles = 0;
    await pumpQueue(
      tester,
      tracks: _tracks,
      currentTrackId: 'track-2',
      onInteractionStart: () => starts++,
      onInteractionSettled: () => settles++,
      onScrollSettled: () => scrollSettles++,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(foldedQueueListKey)),
    );
    await tester.pump();

    expect(starts, 1);
    expect(settles, 0);

    await gesture.moveBy(const Offset(0, -96));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(starts, 1);
    expect(settles, 1);
    expect(scrollSettles, 1);
  });

  testWidgets('every small cover remains at least 48dp tappable', (
    tester,
  ) async {
    await pumpQueue(
      tester,
      tracks: _tracks.take(3).toList(),
      currentTrackId: 'track-1',
    );

    for (final track in _tracks.take(3)) {
      expect(
        tester.getSize(find.byKey(foldedQueueTrackKey(track.id))).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }
  });
}
