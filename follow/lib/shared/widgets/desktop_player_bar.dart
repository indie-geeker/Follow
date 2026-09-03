import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/shared/widgets/player_controls.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/core/theme/player_palette_provider.dart';
import 'package:follow/core/utils/duration_utils.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/shared/widgets/player/player_aurora_background.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

class DesktopPlayerBar extends ConsumerWidget {
  final dynamic currentTrack;

  const DesktopPlayerBar({required this.currentTrack, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.followTokens;
    final paletteRequest = PlayerPaletteRequest.fromTrack(
      currentTrack,
      theme.brightness,
    );
    final palette =
        ref.watch(playerPaletteProvider(paletteRequest)).value ??
        PlayerPalette.fallback(brightness: theme.brightness, tokens: tokens);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);

    final isPlaying = isPlayingAsync.value ?? false;

    return SizedBox(
      height: 80,
      child: PlayerAuroraBackground(
        track: currentTrack,
        palette: palette,
        child: BackdropGroup(
          child: GlassPanel(
            key: const ValueKey('desktop-player-bar-glass'),
            tier: GlassTier.standard,
            borderRadius: BorderRadius.zero,
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
                            ref
                                .read(lyricsOverlayVisibleProvider.notifier)
                                .show();
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
                                backgroundColor: palette.primaryControl,
                                color: palette.onPrimaryControl,
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
                          child: _DesktopPlayerProgress(
                            trackDurationSeconds: currentTrack.durationSeconds,
                            palette: palette,
                            audioService: audioService,
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
                            ref
                                .read(lyricsOverlayVisibleProvider.notifier)
                                .show();
                          },
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.volume_up, size: 18),
                        const SizedBox(width: 4),
                        Flexible(
                          child: _DesktopVolumeSlider(
                            palette: palette,
                            audioService: audioService,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPlayerProgress extends ConsumerWidget {
  const _DesktopPlayerProgress({
    required this.trackDurationSeconds,
    required this.palette,
    required this.audioService,
  });

  final int trackDurationSeconds;
  final PlayerPalette palette;
  final AudioPlayerService audioService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final streamedDuration = ref.watch(playerDurationProvider).value;
    final trackDuration = Duration(seconds: trackDurationSeconds);
    final fallbackDuration = trackDuration.inSeconds > 0
        ? trackDuration
        : const Duration(seconds: 1);
    final duration = streamedDuration == null || streamedDuration.inSeconds <= 1
        ? fallbackDuration
        : streamedDuration;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              formatDuration(position),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: palette.progress,
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
                    audioService.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatDuration(duration),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopVolumeSlider extends ConsumerWidget {
  const _DesktopVolumeSlider({
    required this.palette,
    required this.audioService,
  });

  final PlayerPalette palette;
  final AudioPlayerService audioService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerVolumeProvider).value ?? 1.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: palette.progress,
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value: volume,
          onChanged: (value) {
            audioService.setVolume(value);
          },
        ),
      ),
    );
  }
}
