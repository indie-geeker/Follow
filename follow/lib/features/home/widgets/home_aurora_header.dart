import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';

const homeHeroKey = ValueKey('home-aurora-hero');
const homeHeroArtworkKey = ValueKey('home-aurora-artwork');
const homeHeroBrandFallbackKey = ValueKey('home-aurora-brand-fallback');
const homeHeroCoverPaletteKey = ValueKey('home-aurora-cover-palette');
const homeHeroGroovesKey = ValueKey('home-aurora-grooves');
const homeHeroWaveformKey = ValueKey('home-aurora-waveform');
const homeHeroGreetingKey = ValueKey('home-aurora-greeting');

class HomeAuroraHeader extends StatelessWidget {
  const HomeAuroraHeader({
    required this.palette,
    required this.usesBrandFallback,
    required this.collapseProgress,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
    super.key,
  });

  final PlayerPalette palette;
  final bool usesBrandFallback;
  final double collapseProgress;
  final String title;
  final String subtitle;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final progress = collapseProgress.clamp(0.0, 1.0);
    final artworkVisibility = Curves.easeIn.transform(1 - progress);
    final contentVisibility = (1 - progress * 1.35).clamp(0.0, 1.0);
    final tokens = context.followTokens;

    return RepaintBoundary(
      child: SizedBox.expand(
        key: homeHeroKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              key: usesBrandFallback
                  ? homeHeroBrandFallbackKey
                  : homeHeroCoverPaletteKey,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.scrim.withValues(alpha: 0.06),
                    palette.secondary.withValues(
                      alpha: usesBrandFallback ? 0.14 : 0.18,
                    ),
                    palette.ambient.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5, 0.76, 1],
                ),
              ),
            ),
            Opacity(
              opacity: artworkVisibility,
              child: ExcludeSemantics(
                child: Transform.scale(
                  key: homeHeroArtworkKey,
                  scale: 1 - progress * 0.06,
                  alignment: Alignment.topRight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        key: homeHeroGroovesKey,
                        painter: _RecordGroovesPainter(
                          color: palette.secondary,
                        ),
                      ),
                      CustomPaint(
                        key: homeHeroWaveformKey,
                        painter: _WaveformPainter(
                          primary: palette.ambient,
                          accent: palette.glow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: contentVisibility,
              alwaysIncludeSemantics: true,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [leading, trailing],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 58,
                    child: Semantics(
                      key: homeHeroGreetingKey,
                      container: true,
                      label: '$title。$subtitle',
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordGroovesPainter extends CustomPainter {
  const _RecordGroovesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.92, size.height * 0.22);
    final baseRadius = math.min(size.width, size.height) * 0.48;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var index = 0; index < 9; index++) {
      paint.color = color.withValues(alpha: 0.055 + index * 0.009);
      canvas.drawCircle(center, baseRadius - index * 7.5, paint);
    }

    canvas.drawCircle(
      center,
      baseRadius * 0.18,
      Paint()..color = color.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_RecordGroovesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.primary, required this.accent});

  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final baseline = size.height * 0.72;
    const segments = 28;
    for (var index = 0; index <= segments; index++) {
      final x = size.width * index / segments;
      final envelope = math.sin(math.pi * index / segments);
      final y =
          baseline + math.sin(index * 1.52) * size.height * 0.035 * envelope;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = primary.withValues(alpha: 0.15),
    );

    final dotPaint = Paint()..color = accent.withValues(alpha: 0.18);
    for (var index = 3; index < segments; index += 6) {
      final x = size.width * index / segments;
      final envelope = math.sin(math.pi * index / segments);
      final y =
          baseline + math.sin(index * 1.52) * size.height * 0.035 * envelope;
      canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.accent != accent;
}
