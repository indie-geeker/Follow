import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:follow/core/network/cover_image_provider.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';

typedef PlayerColorSchemeExtractor =
    Future<ColorScheme> Function(
      ImageProvider<Object> imageProvider,
      Brightness brightness,
    );
typedef PlayerImageProviderFactory = ImageProvider<Object> Function(Uri uri);

class PlayerPaletteResolver {
  PlayerPaletteResolver({
    PlayerColorSchemeExtractor? extractor,
    PlayerImageProviderFactory? imageProviderFactory,
    this.capacity = 64,
  }) : assert(capacity > 0),
       _extractor = extractor ?? _extractColorScheme,
       _imageProviderFactory =
           imageProviderFactory ?? ((uri) => coverImageProviderForUri(uri)!);

  final int capacity;
  final PlayerColorSchemeExtractor _extractor;
  final PlayerImageProviderFactory _imageProviderFactory;
  final LinkedHashMap<_PaletteCacheKey, Future<PlayerPalette>> _cache =
      LinkedHashMap<_PaletteCacheKey, Future<PlayerPalette>>();

  Future<PlayerPalette> resolve({
    required Uri? coverUri,
    required Brightness brightness,
    required FollowThemeTokens tokens,
  }) {
    if (coverUri == null) {
      return Future.value(
        PlayerPalette.fallback(brightness: brightness, tokens: tokens),
      );
    }

    final key = _PaletteCacheKey(coverUri.toString(), brightness);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final pending = _resolveCover(
      coverUri: coverUri,
      brightness: brightness,
      tokens: tokens,
    );
    _cache[key] = pending;
    if (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return pending;
  }

  Future<PlayerPalette> _resolveCover({
    required Uri coverUri,
    required Brightness brightness,
    required FollowThemeTokens tokens,
  }) async {
    try {
      final scheme = await _extractor(
        _imageProviderFactory(coverUri),
        brightness,
      );
      return PlayerPalette.guard(
        candidatePrimary: scheme.primary,
        candidateOnPrimary: scheme.onPrimary,
        candidateSecondary: scheme.secondary,
        candidateAmbient: scheme.tertiary,
        brightness: brightness,
        tokens: tokens,
      );
    } catch (_) {
      return PlayerPalette.fallback(brightness: brightness, tokens: tokens);
    }
  }

  static Future<ColorScheme> _extractColorScheme(
    ImageProvider<Object> imageProvider,
    Brightness brightness,
  ) {
    return ColorScheme.fromImageProvider(
      provider: imageProvider,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      contrastLevel: 0.5,
    );
  }
}

@immutable
class _PaletteCacheKey {
  const _PaletteCacheKey(this.coverIdentity, this.brightness);

  final String coverIdentity;
  final Brightness brightness;

  @override
  bool operator ==(Object other) {
    return other is _PaletteCacheKey &&
        coverIdentity == other.coverIdentity &&
        brightness == other.brightness;
  }

  @override
  int get hashCode => Object.hash(coverIdentity, brightness);
}
