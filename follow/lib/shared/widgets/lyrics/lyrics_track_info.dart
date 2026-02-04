import 'package:flutter/material.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/player_controls.dart';

/// Displays track title with like button and artist name.
class LyricsTrackInfo extends StatelessWidget {
  final Track? track;

  const LyricsTrackInfo({super.key, required this.track});

  Color _foregroundColor(BuildContext context, {double alpha = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    return alpha < 1.0 ? baseColor.withValues(alpha: alpha) : baseColor;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  track?.title ?? '',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _foregroundColor(context),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (track != null) ...[
                const SizedBox(width: 8),
                LikeButton(track: track!, size: 24),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            track?.artist?.name ?? '',
            style: TextStyle(
              fontSize: 14,
              color: _foregroundColor(context, alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
