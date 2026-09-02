import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/desktop_player_bar.dart';
import 'package:follow/shared/widgets/player/player_aurora_background.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

const _track = Track(
  id: 'desktop-track',
  title: 'Desktop track',
  durationSeconds: 180,
  artist: Artist(id: 'artist', name: 'Artist'),
);

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playNext() async {}

  @override
  Future<void> playPrevious() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}
}

class _FakeIsFavorite extends IsFavorite {
  @override
  Future<bool> build(String? trackId) async => false;
}

void main() {
  testWidgets('desktop player bar scopes dynamic atmosphere to its glass bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(
            _FakeAudioPlayerService(),
          ),
          isPlayingProvider.overrideWithValue(const AsyncData(false)),
          playerPositionProvider.overrideWithValue(
            const AsyncData(Duration(seconds: 10)),
          ),
          playerDurationProvider.overrideWithValue(
            const AsyncData(Duration(seconds: 180)),
          ),
          playerVolumeProvider.overrideWithValue(const AsyncData(0.65)),
          isFavoriteProvider.overrideWith(_FakeIsFavorite.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DesktopPlayerBar(currentTrack: _track),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final expectedPalette = PlayerPalette.fallback(
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );
    final backdrop = tester.widget<PlayerAuroraBackground>(
      find.byType(PlayerAuroraBackground),
    );
    expect(backdrop.track, _track);
    expect(backdrop.palette, expectedPalette);
    expect(find.byType(BackdropGroup), findsOneWidget);

    final glass = tester.widget<GlassPanel>(
      find.byKey(const ValueKey('desktop-player-bar-glass')),
    );
    expect(glass.tier, GlassTier.standard);
    expect(tester.getSize(find.byType(DesktopPlayerBar)).height, 80);
  });
}
