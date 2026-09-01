import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/player/folded_track_queue.dart';

final _tracks = List.generate(
  8,
  (index) => Track(id: 'track-$index', title: 'Track $index'),
);

void main() {
  Future<void> pumpQueue(
    WidgetTester tester, {
    List<Track> tracks = const [],
    String? currentTrackId,
    ValueChanged<int>? onSelect,
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
                tracks: tracks,
                currentTrackId: currentTrackId,
                revealProgress: revealProgress,
                onSelect: onSelect ?? (_) {},
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

    expect(find.text('当前播放队列为空'), findsOneWidget);
    expect(find.byKey(foldedQueueListKey), findsNothing);
  });

  testWidgets('renders only transparent circular-cover queue content', (
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
    expect(
      tester
          .widget<Material>(
            find.descendant(
              of: find.byKey(foldedTrackQueueKey),
              matching: find.byType(Material),
            ),
          )
          .type,
      MaterialType.transparency,
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

  testWidgets('places the centered cover farther along the orbit arc', (
    tester,
  ) async {
    await pumpQueue(tester, tracks: _tracks, currentTrackId: 'track-3');

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

    expect(
      largestHorizontalTranslation('track-3'),
      greaterThan(largestHorizontalTranslation('track-2')),
    );
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

    expect(find.text('Track 3'), findsNothing);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(foldedQueueListKey)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -72));
    await tester.pump();

    expect(find.text('Track 3'), findsOneWidget);
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

  testWidgets('tapping a cover centers and plays it once', (tester) async {
    final selections = <int>[];
    await pumpQueue(
      tester,
      tracks: _tracks,
      currentTrackId: 'track-2',
      onSelect: selections.add,
    );

    await tester.tap(find.byKey(foldedQueueTrackKey('track-3')));
    await tester.pumpAndSettle();

    expect(selections, [3]);
    expect(
      tester.getCenter(find.byKey(foldedQueueTrackKey('track-3'))).dy,
      closeTo(tester.getCenter(find.byKey(foldedTrackQueueKey)).dy, 1),
    );
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
