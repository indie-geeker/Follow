import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

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
    // Use track's durationSeconds as fallback when player duration is not ready
    final trackDuration = Duration(seconds: currentTrack.durationSeconds);
    final fallbackDuration = trackDuration.inSeconds > 0
        ? trackDuration
        : const Duration(seconds: 1);
    final duration = durationAsync.when(
      data: (v) {
        if (v == null || v.inSeconds <= 1) {
          return fallbackDuration;
        }
        return v;
      },
      loading: () => fallbackDuration,
      error: (_, __) => fallbackDuration,
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
                    TrackCoverImage(
                      track: currentTrack,
                      size: 48,
                      borderRadius: BorderRadius.circular(6),
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
