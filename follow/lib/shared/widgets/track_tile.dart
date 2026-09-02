import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/network/media_url.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/utils/duration_utils.dart';
import 'package:follow/shared/widgets/indicators/playing_indicator.dart';

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
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
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
                      context.followTokens.brandPrimary.withValues(alpha: 0.15),
                      context.followTokens.brandSecondary.withValues(
                        alpha: 0.08,
                      ),
                      Colors.transparent,
                    ],
                  )
                : null,
            border: isPlaying
                ? Border.all(
                    color: isDark
                        ? context.followTokens.brandPrimary.withValues(
                            alpha: 0.3,
                          )
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
                _buildCover(context, 56, isDark),
                const SizedBox(width: 12),
              ],

              // Playing indicator
              if (isPlaying && !showCover) ...[
                const PlayingIndicator(),
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
                            child: const PlayingIndicator(),
                          ),
                        Expanded(
                          child: Text(
                            track.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: isPlaying
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isPlaying
                                  ? (isDark
                                        ? context.followTokens.brandPrimary
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
                      style: theme.textTheme.bodySmall?.copyWith(
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
                            ? context.followTokens.brandPrimary.withValues(
                                alpha: 0.2,
                              )
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.download_done_rounded,
                        size: 14,
                        color: isDark
                            ? context.followTokens.brandPrimary
                            : theme.colorScheme.primary,
                      ),
                    ),
                  Text(
                    formatDurationFromSeconds(track.durationSeconds),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onFavoriteToggle != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? context.followTokens.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onFavoriteToggle!(!isFavorite),
                    ),
                  ],
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
    );
  }

  Widget _buildCover(BuildContext context, double size, bool isDark) {
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
        child: _buildCoverImage(context, size),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, double size) {
    final coverUri = resolveCoverUri(track.coverUrl);
    if (coverUri != null) {
      return CachedNetworkImage(
        imageUrl: coverUri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(context, size),
        errorWidget: (context, url, error) => _buildPlaceholder(context, size),
      );
    }
    return _buildPlaceholder(context, size);
  }

  Widget _buildPlaceholder(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.followTokens.surface,
            context.followTokens.surfaceElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.4,
        color: context.followTokens.textSecondary,
      ),
    );
  }
}
