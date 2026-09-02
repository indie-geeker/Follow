import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/play_queue_sheet.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  int? selectedIndex;

  @override
  Future<void> playTrack(Track track) async {}

  @override
  Future<void> playQueueItemAt(int index) async {
    selectedIndex = index;
  }
}

void main() {
  const palette = PlayerPalette(
    primaryControl: Color(0xFF173E89),
    onPrimaryControl: Colors.white,
    secondary: Color(0xFF8A2362),
    ambient: Color(0xFF16869B),
    progress: Color(0xFF8A2362),
    glow: Color(0xFF16869B),
    scrim: Color(0xFFF7F6FC),
  );
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
        child: const MaterialApp(
          home: Scaffold(body: PlayQueueSheet(palette: palette)),
        ),
      ),
    );

    await tester.tap(find.text('Song C'));
    await tester.pump();

    expect(audioService.selectedIndex, 2);
    expect(
      tester
          .widget<GlassPanel>(
            find.byKey(const ValueKey('play-queue-sheet-glass')),
          )
          .tier,
      GlassTier.strong,
    );
    expect(
      tester.widget<Text>(find.text('Song A')).style?.color,
      palette.secondary,
    );
  });
}
