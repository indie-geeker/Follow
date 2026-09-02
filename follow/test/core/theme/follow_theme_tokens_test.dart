import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';

void main() {
  test('uses the approved light and dark semantic colors', () {
    expect(FollowThemeTokens.light.background, const Color(0xFFF7F6FC));
    expect(FollowThemeTokens.light.surface, const Color(0xFFFFFBFF));
    expect(FollowThemeTokens.light.surfaceElevated, const Color(0xFFECEAF4));
    expect(FollowThemeTokens.light.textPrimary, const Color(0xFF181720));
    expect(FollowThemeTokens.light.textSecondary, const Color(0xFF5C5968));
    expect(FollowThemeTokens.light.brandPrimary, const Color(0xFF5B46F0));
    expect(FollowThemeTokens.light.brandSecondary, const Color(0xFFB62D71));
    expect(FollowThemeTokens.light.auroraCyan, const Color(0xFF2A8EAF));

    expect(FollowThemeTokens.dark.background, const Color(0xFF090D18));
    expect(FollowThemeTokens.dark.surface, const Color(0xFF141A2A));
    expect(FollowThemeTokens.dark.surfaceElevated, const Color(0xFF232B42));
    expect(FollowThemeTokens.dark.textPrimary, const Color(0xFFF4F2FA));
    expect(FollowThemeTokens.dark.textSecondary, const Color(0xFFC8C5D3));
    expect(FollowThemeTokens.dark.brandPrimary, const Color(0xFFA99CFF));
    expect(FollowThemeTokens.dark.brandSecondary, const Color(0xFFFF8FC5));
    expect(FollowThemeTokens.dark.auroraCyan, const Color(0xFF67D4FF));
  });

  test('approved text and action pairs meet WCAG AA', () {
    for (final pair in <(Color, Color)>[
      (FollowThemeTokens.light.textPrimary, FollowThemeTokens.light.background),
      (
        FollowThemeTokens.light.onBrandPrimary,
        FollowThemeTokens.light.brandPrimary,
      ),
      (FollowThemeTokens.dark.textPrimary, FollowThemeTokens.dark.background),
      (
        FollowThemeTokens.dark.onBrandPrimary,
        FollowThemeTokens.dark.brandPrimary,
      ),
    ]) {
      expect(_contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  });

  test('layout, icon, glass and motion tokens use the approved scales', () {
    final tokens = FollowThemeTokens.light;

    expect(tokens.spacing, const [4, 8, 12, 16, 24, 32, 48]);
    expect(tokens.radiusInput, 12);
    expect(tokens.radiusCard, 16);
    expect(tokens.radiusPanel, 24);
    expect(tokens.iconSizes, const [20, 24, 32]);
    expect(tokens.minimumTapTarget, 48);
    expect(tokens.glassLight.blurSigma, inInclusiveRange(12, 16));
    expect(tokens.glassStandard.blurSigma, inInclusiveRange(18, 24));
    expect(tokens.glassStrong.blurSigma, inInclusiveRange(24, 28));
    expect(tokens.motionFast, const Duration(milliseconds: 160));
    expect(tokens.motionStandard, const Duration(milliseconds: 240));
    expect(tokens.motionPalette, const Duration(milliseconds: 360));
  });

  test('copyWith and lerp preserve a complete animatable extension', () {
    final copied = FollowThemeTokens.light.copyWith(
      brandPrimary: const Color(0xFF123456),
    );
    final middle = FollowThemeTokens.light.lerp(FollowThemeTokens.dark, 0.5);

    expect(copied.brandPrimary, const Color(0xFF123456));
    expect(copied.background, FollowThemeTokens.light.background);
    expect(middle.background, isNot(FollowThemeTokens.light.background));
    expect(middle.glassStandard.blurSigma, greaterThan(0));
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = identical(lighter, foreground) ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
