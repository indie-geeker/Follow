import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

class PlayQueueSheet extends ConsumerWidget {
  const PlayQueueSheet({super.key, this.palette});

  final PlayerPalette? palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(playQueueProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final theme = Theme.of(context);
    final palette =
        this.palette ??
        PlayerPalette.fallback(
          brightness: theme.brightness,
          tokens: context.followTokens,
        );

    // If queue is empty but we have a current track, show just that one (or empty state)
    final tracks = queue.isEmpty && currentTrack != null
        ? [currentTrack]
        : queue;

    return BackdropGroup(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: GlassPanel(
          key: const ValueKey('play-queue-sheet-glass'),
          tier: GlassTier.strong,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: '清空队列',
                      onPressed: () {
                        // Show confirmation
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('清空播放队列'),
                            content: const Text('确定要清空所有播放记录吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(audioPlayerServiceProvider)
                                      .clearQueue();
                                  Navigator.pop(context); // Close dialog
                                  Navigator.pop(context); // Close sheet
                                },
                                child: const Text('清空'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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

                    return Material(
                      type: MaterialType.transparency,
                      child: ListTile(
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
                            color: isCurrent ? palette.secondary : null,
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
                                ? palette.secondary.withValues(alpha: 0.82)
                                : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCurrent)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: palette.secondary,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                ref
                                    .read(audioPlayerServiceProvider)
                                    .removeQueueItemAt(index);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          ref
                              .read(audioPlayerServiceProvider)
                              .playQueueItemAt(index);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
