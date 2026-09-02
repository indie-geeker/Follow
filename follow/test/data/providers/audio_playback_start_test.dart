import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';

void main() {
  test(
    'returns after playback starts while playback remains pending',
    () async {
      final playback = Completer<void>();
      var playInvoked = false;

      await startPlaybackWithoutWaitingForCompletion(
        play: () {
          playInvoked = true;
          return playback.future;
        },
        onError: (_, _) {},
      );

      expect(playInvoked, isTrue);
      expect(playback.isCompleted, isFalse);

      playback.complete();
      await playback.future;
    },
  );

  test('reports a deferred playback error exactly once', () async {
    final playback = Completer<void>();
    final reported = <Object>[];

    await startPlaybackWithoutWaitingForCompletion(
      play: () => playback.future,
      onError: (error, _) => reported.add(error),
    );

    playback.completeError(StateError('playback failed'), StackTrace.current);
    await Future<void>.delayed(Duration.zero);

    expect(reported, hasLength(1));
    expect(reported.single, isA<StateError>());
  });

  test(
    'publishes the selected track before asynchronous preparation',
    () async {
      const track = Track(id: 'track-1', title: 'Immediate');
      final preparation = Completer<String>();
      Track? published;

      final result = publishTrackBeforePreparation(
        track: track,
        publish: (value) => published = value,
        prepare: () => preparation.future,
      );

      expect(published, track);
      expect(preparation.isCompleted, isFalse);

      preparation.complete('tokens');
      expect(await result, 'tokens');
    },
  );
}
