import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';

/// An animated indicator showing a track is currently playing.
/// Displays a gradient icon with optional animation.
class PlayingIndicator extends StatelessWidget {
  final double size;

  const PlayingIndicator({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.followTokens.brandPrimary,
            context.followTokens.brandSecondary,
          ],
        ),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        Icons.equalizer_rounded,
        size: size * 0.75,
        color: Colors.white,
      ),
    );
  }
}
