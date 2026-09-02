import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';

@immutable
class PlayerPalette {
  const PlayerPalette({
    required this.primaryControl,
    required this.onPrimaryControl,
    required this.secondary,
    required this.ambient,
    required this.progress,
    required this.glow,
    required this.scrim,
  });

  final Color primaryControl;
  final Color onPrimaryControl;
  final Color secondary;
  final Color ambient;
  final Color progress;
  final Color glow;
  final Color scrim;

  factory PlayerPalette.fallback({
    required Brightness brightness,
    required FollowThemeTokens tokens,
  }) {
    return PlayerPalette(
      primaryControl: tokens.brandPrimary,
      onPrimaryControl: tokens.onBrandPrimary,
      secondary: tokens.brandSecondary,
      ambient: tokens.auroraCyan,
      progress: tokens.brandPrimary,
      glow: tokens.brandSecondary,
      scrim: tokens.background,
    );
  }

  factory PlayerPalette.guard({
    required Color candidatePrimary,
    required Color candidateOnPrimary,
    required Color candidateSecondary,
    required Color candidateAmbient,
    required Brightness brightness,
    required FollowThemeTokens tokens,
  }) {
    final fallback = PlayerPalette.fallback(
      brightness: brightness,
      tokens: tokens,
    );
    final safeControl =
        _isOpaque(candidatePrimary) &&
        _isOpaque(candidateOnPrimary) &&
        contrastRatio(candidateOnPrimary, candidatePrimary) >= 4.5;
    final primary = safeControl ? candidatePrimary : fallback.primaryControl;
    final onPrimary = safeControl
        ? candidateOnPrimary
        : fallback.onPrimaryControl;
    final secondary =
        _isOpaque(candidateSecondary) &&
            contrastRatio(candidateSecondary, fallback.scrim) >= 3
        ? candidateSecondary
        : fallback.secondary;
    final ambient = _isOpaque(candidateAmbient)
        ? candidateAmbient
        : fallback.ambient;
    final progress = contrastRatio(secondary, fallback.scrim) >= 3
        ? secondary
        : contrastRatio(primary, fallback.scrim) >= 3
        ? primary
        : fallback.progress;

    return PlayerPalette(
      primaryControl: primary,
      onPrimaryControl: onPrimary,
      secondary: secondary,
      ambient: ambient,
      progress: progress,
      glow: ambient,
      scrim: fallback.scrim,
    );
  }

  static PlayerPalette lerp(PlayerPalette a, PlayerPalette b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return PlayerPalette(
      primaryControl: Color.lerp(a.primaryControl, b.primaryControl, t)!,
      onPrimaryControl: Color.lerp(a.onPrimaryControl, b.onPrimaryControl, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      ambient: Color.lerp(a.ambient, b.ambient, t)!,
      progress: Color.lerp(a.progress, b.progress, t)!,
      glow: Color.lerp(a.glow, b.glow, t)!,
      scrim: Color.lerp(a.scrim, b.scrim, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlayerPalette &&
            primaryControl == other.primaryControl &&
            onPrimaryControl == other.onPrimaryControl &&
            secondary == other.secondary &&
            ambient == other.ambient &&
            progress == other.progress &&
            glow == other.glow &&
            scrim == other.scrim;
  }

  @override
  int get hashCode => Object.hash(
    primaryControl,
    onPrimaryControl,
    secondary,
    ambient,
    progress,
    glow,
    scrim,
  );
}

double contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

bool _isOpaque(Color color) => color.a >= 0.98;
