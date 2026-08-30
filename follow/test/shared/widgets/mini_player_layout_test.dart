import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/mini_player.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  int nextCalls = 0;

  @override
  Future<void> playNext() async {
    nextCalls++;
  }
}

void main() {
  late _FakeAudioPlayerService audioService;

  setUp(() {
    audioService = _FakeAudioPlayerService();
  });

  Future<void> pumpMiniPlayer(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    const track = Track(
      id: 'track-1',
      title: 'A title that still needs room on a narrow phone',
      durationSeconds: 180,
      artist: Artist(id: 'artist-1', name: 'Artist'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTrackProvider.overrideWithValue(track),
          audioPlayerServiceProvider.overrideWithValue(audioService),
          isPlayingProvider.overrideWithValue(const AsyncData(false)),
          playerPositionProvider.overrideWithValue(
            const AsyncData(Duration.zero),
          ),
          playerDurationProvider.overrideWithValue(
            const AsyncData(Duration(seconds: 180)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('320dp mini player keeps only accessible playback controls', (
    tester,
  ) async {
    await pumpMiniPlayer(tester);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(find.byTooltip('下一首'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsNothing);

    for (final icon in [Icons.play_arrow_rounded, Icons.skip_next_rounded]) {
      final button = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('next button delegates to the audio service', (tester) async {
    await pumpMiniPlayer(tester);

    await tester.tap(find.byTooltip('下一首'));
    await tester.pump();

    expect(audioService.nextCalls, 1);
  });
}
