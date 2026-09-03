import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/shared/widgets/player/player_cover_art.dart';

const _track = Track(id: 'track-1', title: 'Gesture Song');
const _previousTrack = Track(id: 'track-0', title: 'Previous Song');
const _nextTrack = Track(id: 'track-2', title: 'Next Song');
const _trackPageSpanForTest = 292.0;
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
  Future<void> pumpCover(
    WidgetTester tester, {
    VoidCallback? onSwipeUp,
    VoidCallback? onSwipeDown,
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
    bool Function()? onInteractionAttempt,
    VoidCallback? onInteractionStart,
    VoidCallback? onTap,
    Offset restingOffset = Offset.zero,
    ValueChanged<Offset>? onVisualOffsetChanged,
    double maxVerticalVisualOffset = double.infinity,
    bool isPlaying = false,
    bool isBusy = false,
    Track? previousTrack,
    Track? nextTrack,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayerCoverArt(
              palette: _palette,
              track: _track,
              previousTrack: previousTrack,
              nextTrack: nextTrack,
              onSwipeUp: onSwipeUp,
              onSwipeDown: onSwipeDown,
              onSwipeLeft: onSwipeLeft,
              onSwipeRight: onSwipeRight,
              onInteractionAttempt: onInteractionAttempt,
              onInteractionStart: onInteractionStart,
              onTap: onTap,
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

  testWidgets('composes the track cover inside the supplied vinyl edge', (
    tester,
  ) async {
    await pumpCover(tester);

    expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
    expect(find.byKey(vinylCoverLayerKey), findsOneWidget);
    expect(find.byKey(vinylEdgeAssetKey), findsOneWidget);
    expect(find.byKey(vinylSpindleKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(vinylCoverLayerKey)),
      const Size.square(193.2),
    );
    final edgeImage = tester.widget<Image>(find.byKey(vinylEdgeAssetKey));
    expect(
      edgeImage.image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/images/music-circle.png',
      ),
    );
    expect(
      find.bySemanticsLabel('唱片封面：Gesture Song。点击播放，上滑下一首，下滑上一首，左滑歌词，右滑播放队列'),
      findsOneWidget,
    );
    final visual = tester.widget<AnimatedContainer>(
      find.byKey(vinylRecordVisualKey),
    );
    final decoration = visual.decoration as BoxDecoration;
    expect(
      decoration.boxShadow?.first.color,
      _palette.glow.withValues(alpha: 0.32),
    );
  });

  testWidgets('reports pointer start and toggles only for a stationary tap', (
    tester,
  ) async {
    var starts = 0;
    var taps = 0;
    await pumpCover(
      tester,
      onInteractionStart: () => starts++,
      onTap: () => taps++,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
    );
    await tester.pump();
    expect(starts, 1);
    expect(taps, 0);

    await gesture.up();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a record drag never also invokes tap', (tester) async {
    var starts = 0;
    var taps = 0;
    var swipes = 0;
    await pumpCover(
      tester,
      onInteractionStart: () => starts++,
      onTap: () => taps++,
      onSwipeLeft: () => swipes++,
    );

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(-100, 0));
    await tester.pumpAndSettle();

    expect(starts, 1);
    expect(swipes, 1);
    expect(taps, 0);
  });

  testWidgets('a consumed pointer sequence suppresses every record action', (
    tester,
  ) async {
    var taps = 0;
    var up = 0;
    var down = 0;
    var left = 0;
    var right = 0;
    final visualOffsets = <Offset>[];
    await pumpCover(
      tester,
      onInteractionAttempt: () => true,
      onTap: () => taps++,
      onSwipeUp: () => up++,
      onSwipeDown: () => down++,
      onSwipeLeft: () => left++,
      onSwipeRight: () => right++,
      onVisualOffsetChanged: visualOffsets.add,
    );

    final record = find.byKey(vinylRecordSurfaceKey);
    await tester.tap(record);
    await tester.drag(record, const Offset(0, -100));
    await tester.drag(record, const Offset(0, 100));
    await tester.drag(record, const Offset(-100, 0));
    await tester.drag(record, const Offset(100, 0));
    await tester.pumpAndSettle();

    expect((taps, up, down, left, right), (0, 0, 0, 0, 0));
    expect(visualOffsets, isEmpty);
  });

  testWidgets('the interaction after a consumed tap behaves normally', (
    tester,
  ) async {
    var attempts = 0;
    var taps = 0;
    await pumpCover(
      tester,
      onInteractionAttempt: () => attempts++ == 0,
      onTap: () => taps++,
    );

    final record = find.byKey(vinylRecordSurfaceKey);
    await tester.tap(record);
    await tester.tap(record);
    await tester.pump();

    expect(attempts, 2);
    expect(taps, 1);
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

  testWidgets('vertical drag pages current and adjacent records together', (
    tester,
  ) async {
    var nextCalls = 0;
    await pumpCover(
      tester,
      previousTrack: _previousTrack,
      nextTrack: _nextTrack,
      onSwipeUp: () => nextCalls++,
    );

    const currentPageKey = ValueKey('vinyl-record-page-current');
    const nextPageKey = ValueKey('vinyl-record-page-next');
    expect(find.byKey(currentPageKey), findsOneWidget);
    expect(find.byKey(nextPageKey), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -70));
    await tester.pump();

    final currentPage = tester.widget<AnimatedContainer>(
      find.byKey(currentPageKey),
    );
    final nextPage = tester.widget<AnimatedContainer>(find.byKey(nextPageKey));
    expect(currentPage.transform!.storage[13], closeTo(-100, 0.1));
    expect(nextPage.transform!.storage[13], greaterThan(0));
    expect(nextPage.transform!.storage[13], lessThan(_trackPageSpanForTest));
    expect(nextCalls, 0);

    await gesture.up();
    expect(nextCalls, 0);
    await tester.pumpAndSettle();
    expect(nextCalls, 1);
  });

  testWidgets(
    'settled adjacent record stays centered until track identity handoff',
    (tester) async {
      var currentTrack = _track;
      var nextCalls = 0;
      late StateSetter updateHarness;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateHarness = setState;
                return Center(
                  child: PlayerCoverArt(
                    track: currentTrack,
                    previousTrack: _previousTrack,
                    nextTrack: _nextTrack,
                    onSwipeUp: () => nextCalls++,
                  ),
                );
              },
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(vinylRecordSurfaceKey)),
      );
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 240));

      expect(nextCalls, 1);
      expect(
        tester
            .widget<AnimatedContainer>(find.byKey(vinylNextRecordPageKey))
            .transform!
            .storage[13],
        0,
      );

      updateHarness(() => currentTrack = _nextTrack);
      await tester.pump();

      final currentPage = tester.widget<AnimatedContainer>(
        find.byKey(vinylCurrentRecordPageKey),
      );
      expect(currentPage.transform!.storage[13], 0);
      expect(currentPage.duration, Duration.zero);
    },
  );

  testWidgets('busy vinyl ignores completed gestures', (tester) async {
    var calls = 0;
    await pumpCover(tester, onSwipeUp: () => calls++, isBusy: true);

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('tonearm base stays centered and follows playback state', (
    tester,
  ) async {
    await pumpCover(tester);

    expect(find.byKey(vinylTonearmKey), findsOneWidget);
    expect(find.byKey(vinylTonearmAssetKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(vinylTonearmAssetKey)),
      const Size(140, 210),
    );
    final tonearmImage = tester.widget<Image>(find.byKey(vinylTonearmAssetKey));
    expect(
      tonearmImage.image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/images/play-bar.png',
      ),
    );

    final paused = tester.widget<AnimatedRotation>(
      find.byKey(vinylTonearmRotationKey),
    );
    final positioned = tester.widget<Positioned>(find.byKey(vinylTonearmKey));
    final pivotFractionX = (paused.alignment.x + 1) / 2;
    final baseCenterX = positioned.left! + positioned.width! * pivotFractionX;
    expect(baseCenterX, closeTo(140, 0.001));
    expect(paused.turns, closeTo(-25 / 360, 0.0001));
    expect(paused.alignment, const Alignment(-0.78, -0.86));
    expect(paused.duration, const Duration(milliseconds: 350));
    expect(
      find.ancestor(
        of: find.byKey(vinylTonearmKey),
        matching: find.byKey(vinylRotationKey),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(vinylTonearmKey),
        matching: find.byKey(vinylCurrentRecordPageKey),
      ),
      findsNothing,
    );

    await pumpCover(tester, isPlaying: true);
    final playing = tester.widget<AnimatedRotation>(
      find.byKey(vinylTonearmRotationKey),
    );
    expect(playing.turns, closeTo(-3 / 360, 0.0001));
    expect((playing.turns - paused.turns) * 360, closeTo(22, 0.001));

    await pumpCover(tester, isPlaying: true, isBusy: true);
    final busy = tester.widget<AnimatedRotation>(
      find.byKey(vinylTonearmRotationKey),
    );
    expect(busy.turns, closeTo(-3 / 360, 0.0001));
  });

  testWidgets('reduced motion removes the tonearm transition', (tester) async {
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

    final tonearm = tester.widget<AnimatedRotation>(
      find.byKey(vinylTonearmRotationKey),
    );
    expect(tonearm.turns, closeTo(-3 / 360, 0.0001));
    expect(tonearm.duration, Duration.zero);
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

  testWidgets('isolates the rotating record from surrounding player paint', (
    tester,
  ) async {
    await pumpCover(tester, isPlaying: true);

    final boundary = find.byKey(vinylRecordRasterBoundaryKey);
    expect(boundary, findsOneWidget);
    expect(
      find.ancestor(of: boundary, matching: find.byKey(vinylRotationKey)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: boundary, matching: find.byKey(vinylGroovesKey)),
      findsOneWidget,
    );
  });

  testWidgets('a new track identity restarts record rotation from zero', (
    tester,
  ) async {
    var currentTrack = _track;
    late StateSetter updateHarness;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHarness = setState;
              return Center(
                child: PlayerCoverArt(track: currentTrack, isPlaying: true),
              );
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(
      tester
          .widget<RotationTransition>(find.byKey(vinylRotationKey))
          .turns
          .value,
      greaterThan(0),
    );

    updateHarness(() => currentTrack = _nextTrack);
    await tester.pump();

    expect(
      tester
          .widget<RotationTransition>(find.byKey(vinylRotationKey))
          .turns
          .value,
      closeTo(0, 0.001),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<RotationTransition>(find.byKey(vinylRotationKey))
          .turns
          .value,
      greaterThan(0),
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
