import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';

/// Default music note placeholder for missing cover art.
class DefaultCover extends StatelessWidget {
  final double size;
  final double borderRadius;

  const DefaultCover({super.key, this.size = 48, this.borderRadius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.followTokens.brandPrimary.withValues(alpha: 0.3),
            context.followTokens.brandSecondary.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: context.followTokens.brandPrimary,
        size: size * 0.5,
      ),
    );
  }
}
