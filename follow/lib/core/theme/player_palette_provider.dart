import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/core/theme/player_palette_resolver.dart';
import 'package:follow/data/models/track.dart';

@immutable
class PlayerPaletteRequest {
  const PlayerPaletteRequest({
    required this.trackId,
    required this.coverUri,
    required this.brightness,
  });

  factory PlayerPaletteRequest.fromTrack(Track? track, Brightness brightness) {
    return PlayerPaletteRequest(
      trackId: track?.id ?? '',
      coverUri: resolveCoverUri(track?.coverUrl),
      brightness: brightness,
    );
  }

  final String trackId;
  final Uri? coverUri;
  final Brightness brightness;

  @override
  bool operator ==(Object other) {
    return other is PlayerPaletteRequest &&
        trackId == other.trackId &&
        coverUri == other.coverUri &&
        brightness == other.brightness;
  }

  @override
  int get hashCode => Object.hash(trackId, coverUri, brightness);
}

final playerPaletteResolverProvider = Provider<PlayerPaletteResolver>(
  (ref) => PlayerPaletteResolver(),
);

final playerPaletteProvider =
    FutureProvider.family<PlayerPalette, PlayerPaletteRequest>((ref, request) {
      final tokens = request.brightness == Brightness.dark
          ? FollowThemeTokens.dark
          : FollowThemeTokens.light;
      return ref
          .watch(playerPaletteResolverProvider)
          .resolve(
            coverUri: request.coverUri,
            brightness: request.brightness,
            tokens: tokens,
          );
    });
