import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:follow/core/network/cover_image_provider.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/models/track.dart';

const playerBackdropSwitcherKey = ValueKey('player-backdrop-switcher');
const playerBackdropVisualBoundaryKey = ValueKey(
  'player-backdrop-visual-boundary',
);
const playerBackdropBlurKey = ValueKey('player-backdrop-blur');
const playerBackdropScrimKey = ValueKey('player-backdrop-scrim');
const playerBackdropPrimaryGlowKey = ValueKey('player-backdrop-primary-glow');
const playerBackdropAmbientGlowKey = ValueKey('player-backdrop-ambient-glow');
const playerBackdropFallbackKey = ValueKey('player-backdrop-fallback');
const playerBackdropImageFallbackKey = ValueKey(
  'player-backdrop-image-fallback',
);

ValueKey<String> playerBackdropCoverKey(Track? track) => ValueKey<String>(
  'player-backdrop-cover:${coverImageIdentityForTrack(track) ?? 'missing'}',
);

class PlayerAuroraBackground extends StatelessWidget {
  const PlayerAuroraBackground({
    required this.track,
    required this.palette,
    required this.child,
    this.imageProviderOverride,
    super.key,
  });

  final Track? track;
  final PlayerPalette palette;
  final Widget child;
  final ImageProvider<Object>? imageProviderOverride;

  @override
  Widget build(BuildContext context) {
    final tokens = context.followTokens;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final identity = coverImageIdentityForTrack(track);
    final provider = identity == null
        ? null
        : imageProviderOverride ?? coverImageProviderForTrack(track);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: playerBackdropVisualBoundaryKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                key: playerBackdropSwitcherKey,
                duration: reducedMotion ? Duration.zero : tokens.motionPalette,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: provider == null
                    ? SizedBox.expand(
                        key: playerBackdropFallbackKey,
                        child: _BrandFallback(palette: palette),
                      )
                    : SizedBox.expand(
                        key: playerBackdropCoverKey(track),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
                          child: Transform.scale(
                            scale: 1.25,
                            child: Image(
                              key: playerBackdropBlurKey,
                              image: provider,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _BrandFallback(
                                key: playerBackdropImageFallbackKey,
                                palette: palette,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              DecoratedBox(
                key: playerBackdropScrimKey,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.scrim.withValues(alpha: 0.28),
                      palette.scrim.withValues(alpha: 0.82),
                      palette.scrim.withValues(alpha: 0.96),
                    ],
                    stops: const [0, 0.62, 1],
                  ),
                ),
              ),
              DecoratedBox(
                key: playerBackdropPrimaryGlowKey,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.72, -0.78),
                    radius: 1.05,
                    colors: [
                      palette.secondary.withValues(alpha: 0.34),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                key: playerBackdropAmbientGlowKey,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.82, -0.28),
                    radius: 0.92,
                    colors: [
                      palette.ambient.withValues(alpha: 0.26),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _BrandFallback extends StatelessWidget {
  const _BrandFallback({required this.palette, super.key});

  final PlayerPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.scrim, palette.secondary, palette.ambient],
        ),
      ),
    );
  }
}
