import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/core/theme/player_palette_provider.dart';
import 'package:follow/core/theme/player_palette_resolver.dart';
import 'package:follow/data/models/track.dart';

void main() {
  test('request key includes track cover identity and brightness', () {
    const track = Track(
      id: 'track-1',
      title: 'Song',
      coverUrl: 'covers/album.jpg',
    );

    final first = PlayerPaletteRequest.fromTrack(track, Brightness.light);
    final same = PlayerPaletteRequest.fromTrack(track, Brightness.light);
    final dark = PlayerPaletteRequest.fromTrack(track, Brightness.dark);

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(dark));
    expect(first.trackId, 'track-1');
    expect(
      first.coverUri?.path,
      contains('/api/tracks/cover/covers/album.jpg'),
    );
  });

  test('family delegates to the resolver with theme-matched tokens', () async {
    Brightness? extractedBrightness;
    final resolver = PlayerPaletteResolver(
      imageProviderFactory: (_) => const AssetImage('test-cover'),
      extractor: (_, brightness) async {
        extractedBrightness = brightness;
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF173E89),
          brightness: brightness,
          contrastLevel: 0.5,
        );
      },
    );
    final container = ProviderContainer(
      overrides: [playerPaletteResolverProvider.overrideWithValue(resolver)],
    );
    addTearDown(container.dispose);
    const track = Track(
      id: 'track-1',
      title: 'Song',
      coverUrl: 'covers/album.jpg',
    );

    final palette = await container.read(
      playerPaletteProvider(
        PlayerPaletteRequest.fromTrack(track, Brightness.dark),
      ).future,
    );

    expect(extractedBrightness, Brightness.dark);
    expect(
      contrastRatio(palette.onPrimaryControl, palette.primaryControl),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(palette.progress, FollowThemeTokens.dark.background),
      greaterThanOrEqualTo(3),
    );
  });
}
