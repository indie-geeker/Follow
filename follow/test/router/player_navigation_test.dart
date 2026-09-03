import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/router/player_navigation.dart';

void main() {
  test(
    'mobile navigation starts before the playback future completes',
    () async {
      final playback = Completer<void>();
      final events = <String>[];

      await coordinateTrackSelection(
        shouldOpenPlayer: true,
        play: () {
          events.add('play');
          return playback.future;
        },
        openPlayer: () async => events.add('open'),
      );

      expect(events, ['play', 'open']);
      expect(playback.isCompleted, isFalse);
      playback.complete();
    },
  );

  test(
    'desktop selection waits for playback and does not open player',
    () async {
      final playback = Completer<void>();
      var opened = false;
      var completed = false;

      final selection = coordinateTrackSelection(
        shouldOpenPlayer: false,
        play: () => playback.future,
        openPlayer: () async => opened = true,
      )..then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(opened, isFalse);

      playback.complete();
      await selection;
      expect(completed, isTrue);
      expect(opened, isFalse);
    },
  );

  testWidgets('player route slides from the bottom into its resting position', (
    tester,
  ) async {
    Future<Offset> pumpAt(double value) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => buildPlayerRouteTransition(
              context,
              AlwaysStoppedAnimation(value),
              kAlwaysDismissedAnimation,
              const SizedBox(key: ValueKey('transition-child')),
            ),
          ),
        ),
      );
      return tester
          .widget<SlideTransition>(find.byKey(playerRouteSlideTransitionKey))
          .position
          .value;
    }

    expect(await pumpAt(0), const Offset(0, 1));
    expect(await pumpAt(1), Offset.zero);
  });

  testWidgets('player route removes its slide when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => buildPlayerRouteTransition(
              context,
              kAlwaysDismissedAnimation,
              kAlwaysDismissedAnimation,
              const SizedBox(key: ValueKey('reduced-motion-child')),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('reduced-motion-child')), findsOneWidget);
    expect(find.byKey(playerRouteSlideTransitionKey), findsNothing);
  });
}
