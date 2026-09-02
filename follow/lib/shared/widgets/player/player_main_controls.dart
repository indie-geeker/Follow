import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/shared/widgets/player/player_control_button.dart';
import 'package:follow/shared/widgets/player/player_mode_control.dart';

/// Main playback controls row including mode, prev, play/pause and next.
class PlayerMainControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShowQueue;
  final PlayerPalette? palette;

  const PlayerMainControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShowQueue,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final resolvedPalette =
        palette ??
        PlayerPalette.fallback(
          brightness: brightness,
          tokens: context.followTokens,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Row(
          children: [
            const Expanded(child: Center(child: PlayerModeControl())),
            Expanded(
              child: Center(
                child: PlayerControlButton(
                  icon: Icons.skip_previous_rounded,
                  size: 24,
                  tooltip: '上一首',
                  onPressed: onPrevious,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Tooltip(
                  message: isPlaying ? '暂停' : '播放',
                  child: Semantics(
                    button: true,
                    label: isPlaying ? '暂停' : '播放',
                    child: GestureDetector(
                      onTap: onPlayPause,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: DecoratedBox(
                          key: const ValueKey('player-primary-control'),
                          decoration: BoxDecoration(
                            color: resolvedPalette.primaryControl,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: resolvedPalette.glow.withValues(
                                  alpha: 0.36,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: resolvedPalette.onPrimaryControl,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: PlayerControlButton(
                  icon: Icons.skip_next_rounded,
                  size: 24,
                  tooltip: '下一首',
                  onPressed: onNext,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: PlayerControlButton(
                  icon: Icons.queue_music_rounded,
                  size: 24,
                  tooltip: '当前播放队列',
                  onPressed: onShowQueue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
