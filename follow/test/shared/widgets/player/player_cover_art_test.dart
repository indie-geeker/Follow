import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/player/player_cover_art.dart';

const _track = Track(id: 'track-1', title: 'Gesture Song');

void main() {
  Future<void> pumpCover(
    WidgetTester tester, {
    VoidCallback? onSwipeUp,
    VoidCallback? onSwipeDown,
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
    Offset restingOffset = Offset.zero,
    ValueChanged<Offset>? onVisualOffsetChanged,
    double maxVerticalVisualOffset = double.infinity,
    bool isPlaying = false,
    bool isBusy = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayerCoverArt(
              track: _track,
              onSwipeUp: onSwipeUp,
              onSwipeDown: onSwipeDown,
              onSwipeLeft: onSwipeLeft,
              onSwipeRight: onSwipeRight,
              restingOffset: restingOffset,
              onVisualOffsetChanged: onVisualOffsetChanged,
              maxVerticalVisualOffset: maxVerticalVisualOffset,
              isPlaying: isPlaying,
              isBusy: isBusy,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders a semantic circular vinyl with grooves and spindle', (
    tester,
  ) async {
    await pumpCover(tester);

    expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
    expect(find.byKey(vinylGroovesKey), findsOneWidget);
    expect(find.byKey(vinylSpindleKey), findsOneWidget);
    expect(find.byType(ClipOval), findsWidgets);
    expect(
      find.bySemanticsLabel('唱片封面：Gesture Song。上滑下一首，下滑上一首，左滑歌词，右滑播放队列'),
      findsOneWidget,
    );
  });

  testWidgets('reports each completed cardinal swipe exactly once', (
    tester,
  ) async {
    var up = 0;
    var down = 0;
    var left = 0;
    var right = 0;
    await pumpCover(
      tester,
      onSwipeUp: () => up++,
      onSwipeDown: () => down++,
      onSwipeLeft: () => left++,
      onSwipeRight: () => right++,
    );

    final record = find.byKey(vinylRecordSurfaceKey);
    await tester.drag(record, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(-100, 0));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(100, 0));
    await tester.pumpAndSettle();

    expect((up, down, left, right), (1, 1, 1, 1));
  });

  testWidgets('ignores short drags below the activation threshold', (
    tester,
  ) async {
    var calls = 0;
    await pumpCover(
      tester,
      onSwipeUp: () => calls++,
      onSwipeDown: () => calls++,
      onSwipeLeft: () => calls++,
      onSwipeRight: () => calls++,
    );

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(18, -20));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('locks a diagonal drag to one cardinal axis while moving', (
    tester,
  ) async {
    await pumpCover(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
    );
    await gesture.moveBy(const Offset(80, 36));
    await tester.pump();

    final visual = tester.widget<AnimatedContainer>(
      find.byKey(vinylRecordVisualKey),
    );
    expect(visual.transform!.storage[12], greaterThan(0));
    expect(visual.transform!.storage[13], 0);

    await gesture.up();
  });

  testWidgets('reports axis-projected visual positions from a resting offset', (
    tester,
  ) async {
    final positions = <Offset>[];
    await pumpCover(
      tester,
      restingOffset: const Offset(24, 0),
      onVisualOffsetChanged: positions.add,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
    );
    await gesture.moveBy(const Offset(40, 18));
    await tester.pump();

    expect(positions.last, const Offset(64, 0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(positions.last, const Offset(24, 0));
  });

  testWidgets('clamps vertical visual movement to its safe boundary', (
    tester,
  ) async {
    final positions = <Offset>[];
    await pumpCover(
      tester,
      maxVerticalVisualOffset: 32,
      onVisualOffsetChanged: positions.add,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
    );
    await gesture.moveBy(const Offset(8, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();

    expect(positions.last.dx, 0);
    expect(positions.last.dy, -32);
    await gesture.up();
  });

  testWidgets('bounded vertical drag still completes from raw distance', (
    tester,
  ) async {
    var nextCalls = 0;
    final positions = <Offset>[];
    await pumpCover(
      tester,
      maxVerticalVisualOffset: 24,
      onVisualOffsetChanged: positions.add,
      onSwipeUp: () => nextCalls++,
    );

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(positions.where((offset) => offset.dy < -24), isEmpty);
    expect(nextCalls, 1);
  });

  testWidgets('busy vinyl ignores completed gestures', (tester) async {
    var calls = 0;
    await pumpCover(tester, onSwipeUp: () => calls++, isBusy: true);

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('vinyl rotates slowly only while playback is active', (
    tester,
  ) async {
    await pumpCover(tester, isPlaying: true);
    final rotation = find.byKey(vinylRotationKey);
    expect(rotation, findsOneWidget);
    final initial = tester.widget<RotationTransition>(rotation).turns.value;

    await tester.pump(const Duration(seconds: 6));
    final playingAngle = tester
        .widget<RotationTransition>(rotation)
        .turns
        .value;
    expect(playingAngle, greaterThan(initial));
    expect(playingAngle - initial, closeTo(0.25, 0.03));

    await pumpCover(tester, isPlaying: false);
    final pausedAngle = tester.widget<RotationTransition>(rotation).turns.value;
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<RotationTransition>(rotation).turns.value,
      closeTo(pausedAngle, 0.001),
    );

    await pumpCover(tester, isPlaying: true);
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<RotationTransition>(rotation).turns.value,
      greaterThan(pausedAngle),
    );
  });

  testWidgets('active record drag pauses and then resumes vinyl rotation', (
    tester,
  ) async {
    await pumpCover(tester, isPlaying: true);
    await tester.pump(const Duration(seconds: 3));
    final rotation = find.byKey(vinylRotationKey);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    final heldAngle = tester.widget<RotationTransition>(rotation).turns.value;
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<RotationTransition>(rotation).turns.value,
      closeTo(heldAngle, 0.001),
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<RotationTransition>(rotation).turns.value,
      greaterThan(heldAngle),
    );
  });

  testWidgets('reduced motion keeps drag feedback stationary', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(child: PlayerCoverArt(track: _track)),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    final visual = tester.widget<AnimatedContainer>(
      find.byKey(vinylRecordVisualKey),
    );
    expect(visual.transform!.storage[12], 0);
    expect(visual.transform!.storage[13], 0);

    await gesture.up();
  });

  testWidgets('reduced motion disables playback rotation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(child: PlayerCoverArt(track: _track, isPlaying: true)),
          ),
        ),
      ),
    );

    final rotation = find.byKey(vinylRotationKey);
    expect(rotation, findsOneWidget);
    final initial = tester.widget<RotationTransition>(rotation).turns.value;
    await tester.pump(const Duration(seconds: 6));
    expect(
      tester.widget<RotationTransition>(rotation).turns.value,
      closeTo(initial, 0.001),
    );
  });
}
