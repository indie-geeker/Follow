import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/config/app_config.dart';

/// Track list tile widget
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: showCover ? _buildCover(48) : null,
      title: Text(
        track.title,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
          color: isPlaying ? theme.colorScheme.primary : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${track.artist?.name ?? '未知艺术家'}${track.album != null ? ' · ${track.album!.title}' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.isDownloaded)
            Icon(
              Icons.download_done,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          Text(
            _formatDuration(track.durationSeconds),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onMorePressed != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              iconSize: 20,
              onPressed: onMorePressed,
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildCover(double size) {
    if (track.coverUrl != null && track.coverUrl!.isNotEmpty) {
      final url = track.coverUrl!.startsWith('http')
          ? track.coverUrl!
          : '${AppConfig.apiBaseUrl}/api/tracks/cover/${Uri.encodeComponent(track.coverUrl!)}';
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(size),
          errorWidget: (context, url, error) => _buildPlaceholder(size),
        ),
      );
    }
    return _buildPlaceholder(size);
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, size: size * 0.5, color: Colors.grey[500]),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
