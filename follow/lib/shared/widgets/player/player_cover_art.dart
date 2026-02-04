import 'package:flutter/material.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

/// Large cover art display for the player page with shadow effects.
class PlayerCoverArt extends StatelessWidget {
  final Track track;
  final double size;

  const PlayerCoverArt({
    super.key,
    required this.track,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? LoginColors.accentPurple : Colors.black)
                .withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 40,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: TrackCoverImage(
        track: track,
        size: size,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
