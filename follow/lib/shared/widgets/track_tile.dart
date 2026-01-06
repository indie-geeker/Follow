import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/config/app_config.dart';
import 'package:follow/core/theme/app_theme.dart';

/// Enhanced track list tile widget with premium styling
class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;
  final bool isPlaying;
  final bool showCover;

  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onMorePressed,
    this.isPlaying = false,
    this.showCover = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isPlaying && isDark
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        LoginColors.accentPurple.withValues(alpha: 0.15),
                        LoginColors.accentPink.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    )
                  : null,
              border: isPlaying
                  ? Border.all(
                      color: isDark
                          ? LoginColors.accentPurple.withValues(alpha: 0.3)
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Cover art with shadow
                if (showCover) ...[
                  _buildCover(56, isDark),
                  const SizedBox(width: 12),
                ],

                // Playing indicator
                if (isPlaying && !showCover) ...[
                  _buildPlayingIndicator(isDark),
                  const SizedBox(width: 12),
                ],

                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (isPlaying && showCover)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: _buildPlayingIndicator(isDark),
                            ),
                          Expanded(
                            child: Text(
                              track.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    isPlaying ? FontWeight.w600 : FontWeight.w500,
                                color: isPlaying
                                    ? (isDark
                                        ? LoginColors.accentPurple
                                        : theme.colorScheme.primary)
                                    : theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${track.artist?.name ?? '未知艺术家'}${track.album != null ? ' · ${track.album!.title}' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Duration and actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (track.isDownloaded)
                      Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? LoginColors.accentPurple.withValues(alpha: 0.2)
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.download_done_rounded,
                          size: 14,
                          color: isDark
                              ? LoginColors.accentPurple
                              : theme.colorScheme.primary,
                        ),
                      ),
                    Text(
                      _formatDuration(track.durationSeconds),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (onMorePressed != null)
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        onPressed: onMorePressed,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayingIndicator(bool isDark) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [LoginColors.accentPurple, LoginColors.accentPink]
              : [const Color(0xFF6750A4), const Color(0xFF9C4BB8)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.equalizer_rounded,
        size: 12,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCover(double size, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildCoverImage(size),
      ),
    );
  }

  Widget _buildCoverImage(double size) {
    if (track.coverUrl != null && track.coverUrl!.isNotEmpty) {
      final url = track.coverUrl!.startsWith('http')
          ? track.coverUrl!
          : '${AppConfig.apiBaseUrl}/api/tracks/cover/${Uri.encodeComponent(track.coverUrl!)}';
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(size),
        errorWidget: (context, url, error) => _buildPlaceholder(size),
      );
    }
    return _buildPlaceholder(size);
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LoginColors.gradientMid1,
            LoginColors.gradientMid2,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.4,
        color: LoginColors.textSecondary,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
