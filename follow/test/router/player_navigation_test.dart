import 'dart:async';

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
}
