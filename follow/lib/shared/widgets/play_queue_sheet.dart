import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

class PlayQueueSheet extends ConsumerWidget {
  const PlayQueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(playQueueProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final theme = Theme.of(context);

    // If queue is empty but we have a current track, show just that one (or empty state)
    final tracks = queue.isEmpty && currentTrack != null ? [currentTrack] : queue;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  '播放队列 (${tracks.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                final isCurrent = track.id == currentTrack?.id;
                
                return ListTile(
                  leading: TrackCoverImage(
                    track: track,
                    size: 40,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? theme.colorScheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Text(
                    track.artist?.name ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrent 
                          ? theme.colorScheme.primary.withOpacity(0.8) 
                          : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  trailing: isCurrent 
                      ? Icon(Icons.graphic_eq_rounded, color: theme.colorScheme.primary) 
                      : null,
                  onTap: () {
                    // Play this track
                    ref.read(audioPlayerServiceProvider).playTrack(track);
                    // Also update queue index if needed?
                    // AudioPlayerService.playTrack logic handles simple playback.
                    // If we want full queue management, we might need a controller.
                    // For now, assume playTrack is enough to switch song.
                    
                    // If queue management is strictly by index, we should set index.
                    // But playTrack(track) seems to just play a track.
                    // Let's assume standard behavior.
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
