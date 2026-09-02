import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class GlassSpec {
  const GlassSpec({
    required this.blurSigma,
    required this.fill,
    required this.border,
  });

  final double blurSigma;
  final Color fill;
  final Color border;

  static GlassSpec lerp(GlassSpec a, GlassSpec b, double t) => GlassSpec(
    blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
    fill: Color.lerp(a.fill, b.fill, t)!,
    border: Color.lerp(a.border, b.border, t)!,
  );
}

@immutable
class FollowThemeTokens extends ThemeExtension<FollowThemeTokens> {
  const FollowThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.brandPrimary,
    required this.onBrandPrimary,
    required this.brandSecondary,
    required this.auroraCyan,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.offline,
    required this.glassLight,
    required this.glassStandard,
    required this.glassStrong,
    this.spacing = const [4, 8, 12, 16, 24, 32, 48],
    this.iconSizes = const [20, 24, 32],
    this.radiusInput = 12,
    this.radiusCard = 16,
    this.radiusPanel = 24,
    this.minimumTapTarget = 48,
    this.motionFast = const Duration(milliseconds: 160),
    this.motionStandard = const Duration(milliseconds: 240),
    this.motionPalette = const Duration(milliseconds: 360),
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color brandPrimary;
  final Color onBrandPrimary;
  final Color brandSecondary;
  final Color auroraCyan;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color offline;
  final GlassSpec glassLight;
  final GlassSpec glassStandard;
  final GlassSpec glassStrong;
  final List<double> spacing;
  final List<double> iconSizes;
  final double radiusInput;
  final double radiusCard;
  final double radiusPanel;
  final double minimumTapTarget;
  final Duration motionFast;
  final Duration motionStandard;
  final Duration motionPalette;

  static const light = FollowThemeTokens(
    background: Color(0xFFF7F6FC),
    surface: Color(0xFFFFFBFF),
    surfaceElevated: Color(0xFFECEAF4),
    textPrimary: Color(0xFF181720),
    textSecondary: Color(0xFF5C5968),
    brandPrimary: Color(0xFF5B46F0),
    onBrandPrimary: Color(0xFFFFFFFF),
    brandSecondary: Color(0xFFB62D71),
    auroraCyan: Color(0xFF2A8EAF),
    success: Color(0xFF18794E),
    warning: Color(0xFF9A6700),
    error: Color(0xFFB3261E),
    info: Color(0xFF276EF1),
    offline: Color(0xFF6F6D78),
    glassLight: GlassSpec(
      blurSigma: 14,
      fill: Color(0xD9FFFBFF),
      border: Color(0xA6FFFFFF),
    ),
    glassStandard: GlassSpec(
      blurSigma: 20,
      fill: Color(0xCCFFFBFF),
      border: Color(0xB8FFFFFF),
    ),
    glassStrong: GlassSpec(
      blurSigma: 26,
      fill: Color(0xE0FFFBFF),
      border: Color(0xCCFFFFFF),
    ),
  );

  static const dark = FollowThemeTokens(
    background: Color(0xFF090D18),
    surface: Color(0xFF141A2A),
    surfaceElevated: Color(0xFF232B42),
    textPrimary: Color(0xFFF4F2FA),
    textSecondary: Color(0xFFC8C5D3),
    brandPrimary: Color(0xFFA99CFF),
    onBrandPrimary: Color(0xFF21145F),
    brandSecondary: Color(0xFFFF8FC5),
    auroraCyan: Color(0xFF67D4FF),
    success: Color(0xFF5FD3A2),
    warning: Color(0xFFF5C451),
    error: Color(0xFFFFB4AB),
    info: Color(0xFF8BB8FF),
    offline: Color(0xFFA5A3AD),
    glassLight: GlassSpec(
      blurSigma: 14,
      fill: Color(0x80141A2A),
      border: Color(0x2EFFFFFF),
    ),
    glassStandard: GlassSpec(
      blurSigma: 20,
      fill: Color(0x94141A2A),
      border: Color(0x3DFFFFFF),
    ),
    glassStrong: GlassSpec(
      blurSigma: 26,
      fill: Color(0xAD141A2A),
      border: Color(0x52FFFFFF),
    ),
  );

  @override
  FollowThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? brandPrimary,
    Color? onBrandPrimary,
    Color? brandSecondary,
    Color? auroraCyan,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? offline,
    GlassSpec? glassLight,
    GlassSpec? glassStandard,
    GlassSpec? glassStrong,
    List<double>? spacing,
    List<double>? iconSizes,
    double? radiusInput,
    double? radiusCard,
    double? radiusPanel,
    double? minimumTapTarget,
    Duration? motionFast,
    Duration? motionStandard,
    Duration? motionPalette,
  }) => FollowThemeTokens(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    brandPrimary: brandPrimary ?? this.brandPrimary,
    onBrandPrimary: onBrandPrimary ?? this.onBrandPrimary,
    brandSecondary: brandSecondary ?? this.brandSecondary,
    auroraCyan: auroraCyan ?? this.auroraCyan,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    info: info ?? this.info,
    offline: offline ?? this.offline,
    glassLight: glassLight ?? this.glassLight,
    glassStandard: glassStandard ?? this.glassStandard,
    glassStrong: glassStrong ?? this.glassStrong,
    spacing: spacing ?? this.spacing,
    iconSizes: iconSizes ?? this.iconSizes,
    radiusInput: radiusInput ?? this.radiusInput,
    radiusCard: radiusCard ?? this.radiusCard,
    radiusPanel: radiusPanel ?? this.radiusPanel,
    minimumTapTarget: minimumTapTarget ?? this.minimumTapTarget,
    motionFast: motionFast ?? this.motionFast,
    motionStandard: motionStandard ?? this.motionStandard,
    motionPalette: motionPalette ?? this.motionPalette,
  );

  @override
  FollowThemeTokens lerp(covariant FollowThemeTokens? other, double t) {
    if (other == null) return this;
    return FollowThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      onBrandPrimary: Color.lerp(onBrandPrimary, other.onBrandPrimary, t)!,
      brandSecondary: Color.lerp(brandSecondary, other.brandSecondary, t)!,
      auroraCyan: Color.lerp(auroraCyan, other.auroraCyan, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      glassLight: GlassSpec.lerp(glassLight, other.glassLight, t),
      glassStandard: GlassSpec.lerp(glassStandard, other.glassStandard, t),
      glassStrong: GlassSpec.lerp(glassStrong, other.glassStrong, t),
      spacing: t < 0.5 ? spacing : other.spacing,
      iconSizes: t < 0.5 ? iconSizes : other.iconSizes,
      radiusInput: lerpDouble(radiusInput, other.radiusInput, t)!,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t)!,
      radiusPanel: lerpDouble(radiusPanel, other.radiusPanel, t)!,
      minimumTapTarget: lerpDouble(
        minimumTapTarget,
        other.minimumTapTarget,
        t,
      )!,
      motionFast: _lerpDuration(motionFast, other.motionFast, t),
      motionStandard: _lerpDuration(motionStandard, other.motionStandard, t),
      motionPalette: _lerpDuration(motionPalette, other.motionPalette, t),
    );
  }
}

Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
  microseconds: lerpDouble(a.inMicroseconds, b.inMicroseconds, t)!.round(),
);

extension FollowThemeTokensContext on BuildContext {
  FollowThemeTokens get followTokens =>
      Theme.of(this).extension<FollowThemeTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? FollowThemeTokens.dark
          : FollowThemeTokens.light);
}
