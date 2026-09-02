import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';

void main() {
  test('brand fallbacks are deterministic in both themes', () {
    final light = PlayerPalette.fallback(
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );
    final dark = PlayerPalette.fallback(
      brightness: Brightness.dark,
      tokens: FollowThemeTokens.dark,
    );

    expect(light.primaryControl, FollowThemeTokens.light.brandPrimary);
    expect(light.onPrimaryControl, FollowThemeTokens.light.onBrandPrimary);
    expect(light.secondary, FollowThemeTokens.light.brandSecondary);
    expect(light.ambient, FollowThemeTokens.light.auroraCyan);
    expect(dark.primaryControl, FollowThemeTokens.dark.brandPrimary);
    expect(dark.onPrimaryControl, FollowThemeTokens.dark.onBrandPrimary);
    expect(dark.secondary, FollowThemeTokens.dark.brandSecondary);
    expect(dark.ambient, FollowThemeTokens.dark.auroraCyan);
  });

  test('unsafe control accent falls back to the brand pair', () {
    final palette = PlayerPalette.guard(
      candidatePrimary: const Color(0xFFF7F6FC),
      candidateOnPrimary: Colors.white,
      candidateSecondary: const Color(0xFFF4F2FA),
      candidateAmbient: const Color(0x2200FFFF),
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );

    expect(palette.primaryControl, FollowThemeTokens.light.brandPrimary);
    expect(palette.onPrimaryControl, FollowThemeTokens.light.onBrandPrimary);
    expect(
      contrastRatio(palette.onPrimaryControl, palette.primaryControl),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(palette.progress, palette.scrim),
      greaterThanOrEqualTo(3),
    );
  });

  test('safe cover colors remain available for player emphasis', () {
    final palette = PlayerPalette.guard(
      candidatePrimary: const Color(0xFF173E89),
      candidateOnPrimary: Colors.white,
      candidateSecondary: const Color(0xFF8A2362),
      candidateAmbient: const Color(0xFF16869B),
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );

    expect(palette.primaryControl, const Color(0xFF173E89));
    expect(palette.onPrimaryControl, Colors.white);
    expect(palette.secondary, const Color(0xFF8A2362));
    expect(palette.ambient, const Color(0xFF16869B));
  });

  test('palette interpolation preserves stable endpoints', () {
    final light = PlayerPalette.fallback(
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );
    final dark = PlayerPalette.fallback(
      brightness: Brightness.dark,
      tokens: FollowThemeTokens.dark,
    );

    expect(PlayerPalette.lerp(light, dark, 0), light);
    expect(PlayerPalette.lerp(light, dark, 1), dark);
    expect(PlayerPalette.lerp(light, dark, 0.5), isNot(light));
  });

  test('player palette source contains no functional status roles', () {
    final source = File(
      'lib/core/theme/player_palette.dart',
    ).readAsStringSync();

    for (final forbidden in [
      'success',
      'warning',
      'error',
      'info',
      'offline',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });
}
