import 'package:flutter/material.dart';
import 'package:follow/core/theme/app_theme.dart';

/// Default music note placeholder for missing cover art.
class DefaultCover extends StatelessWidget {
  final double size;
  final double borderRadius;

  const DefaultCover({
    super.key,
    this.size = 48,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LoginColors.accentPurple.withValues(alpha: 0.3),
            LoginColors.accentPink.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: LoginColors.accentPurple,
        size: size * 0.5,
      ),
    );
  }
}
