import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/play_queue_sheet.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  List<Track>? playedQueue;
  int? playedIndex;

  @override
  Future<void> playTrack(Track track) async {}

  @override
  Future<void> playAll(List<Track> tracks, {int startIndex = 0}) async {
    playedQueue = tracks;
    playedIndex = startIndex;
  }
}

void main() {
  testWidgets('selecting a queue row updates playback by queue index', (
    tester,
  ) async {
    const tracks = [
      Track(id: 'a', title: 'Song A'),
      Track(id: 'b', title: 'Song B'),
      Track(id: 'c', title: 'Song C'),
    ];
    final audioService = _FakeAudioPlayerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playQueueProvider.overrideWithValue(tracks),
          currentTrackProvider.overrideWithValue(tracks.first),
          audioPlayerServiceProvider.overrideWithValue(audioService),
        ],
        child: const MaterialApp(home: Scaffold(body: PlayQueueSheet())),
      ),
    );

    await tester.tap(find.text('Song C'));
    await tester.pump();

    expect(audioService.playedQueue, tracks);
    expect(audioService.playedIndex, 2);
  });
}
