import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/features/player/lyrics_overlay.dart';
import 'package:follow/shared/widgets/player_controls.dart';
import 'package:follow/core/extensions/async_value_ext.dart';
import 'package:follow/core/utils/duration_utils.dart';
import 'package:follow/data/providers/lyrics_provider.dart';

class DesktopPlayerBar extends ConsumerWidget {
  final dynamic currentTrack;

  const DesktopPlayerBar({required this.currentTrack, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);
    final volumeAsync = ref.watch(playerVolumeProvider);

    final isPlaying = isPlayingAsync.valueOr(false);
    final position = positionAsync.valueOrDefault(Duration.zero);
    final duration = durationAsync.valueOrDefault(const Duration(seconds: 1));

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Track info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Cover - tap to open lyrics overlay
                  TrackCoverImage(
                    track: currentTrack,
                    size: 56,
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      ref.read(lyricsOverlayVisibleProvider.notifier).show();
                    },
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
                ],
              ),
            ),
          ),
          // Controls
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Control buttons
                  SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const PlayModeButton(size: 20),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          iconSize: 24,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                            maxHeight: 32,
                          ),
                          onPressed: () {
                            audioService.playPrevious();
                          },
                        ),
                        const SizedBox(width: 4),
                        PlayPauseButton(
                          isPlaying: isPlaying,
                          size: 22,
                          backgroundColor: theme.colorScheme.primary,
                          color: theme.colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          iconSize: 24,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                            maxHeight: 32,
                          ),
                          onPressed: () {
                            audioService.playNext();
                          },
                        ),
                        const SizedBox(width: 12),
                        // Placeholder to balance layout if needed, or remove
                        // Original had repeat button here. Now PlayModeButton is on left.
                        // Let's keep it balanced or just empty.
                        const SizedBox(width: 20), 
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            formatDuration(position),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 4,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: position.inMilliseconds.toDouble().clamp(
                                  0,
                                  duration.inMilliseconds.toDouble(),
                                ),
                                max: duration.inMilliseconds.toDouble(),
                                onChanged: (value) {
                                  audioService.seek(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatDuration(duration),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Volume & actions
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  LikeButton(track: currentTrack, size: 20),
                  const SizedBox(width: 8),
                  const PlaylistButton(size: 20),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.lyrics),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () {
                       ref.read(lyricsOverlayVisibleProvider.notifier).show();
                    },
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.volume_up, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: volumeAsync.value ?? 1.0,
                          onChanged: (value) {
                            audioService.setVolume(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
