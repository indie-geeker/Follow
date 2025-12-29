import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/core/config/app_config.dart';

/// Mini Player Widget - Shows at bottom of screen when playing
class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  
  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    
    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isPlaying = isPlayingAsync.when(
      data: (v) => v,
      loading: () => false,
      error: (_, __) => false,
    );
    final position = positionAsync.when(
      data: (v) => v ?? Duration.zero,
      loading: () => Duration.zero,
      error: (_, __) => Duration.zero,
    );
    final duration = durationAsync.when(
      data: (v) => v ?? const Duration(seconds: 1),
      loading: () => const Duration(seconds: 1),
      error: (_, __) => const Duration(seconds: 1),
    );
    final progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Cover
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildCover(currentTrack, 48),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTrack.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentTrack.artist?.name ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Controls
                    _PlayPauseButton(isPlaying: isPlaying),
                    const SizedBox(width: 8),
                    _NextButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(Track track, double size) {
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
      color: Colors.grey[300],
      child: Icon(Icons.music_note, size: size * 0.5, color: Colors.grey[500]),
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  final bool isPlaying;
  
  const _PlayPauseButton({required this.isPlaying});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    
    return IconButton(
      icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
      iconSize: 32,
      onPressed: () {
        if (isPlaying) {
          audioService.pause();
        } else {
          audioService.play();
        }
      },
    );
  }
}

class _NextButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.skip_next_rounded),
      iconSize: 28,
      onPressed: () {
        // TODO: Implement next track
      },
    );
  }
}
