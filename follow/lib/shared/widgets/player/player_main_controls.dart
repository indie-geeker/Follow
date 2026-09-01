import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/player/player_control_button.dart';

/// Main playback controls row including mode, prev, play/pause and next.
class PlayerMainControls extends ConsumerWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShowQueue;

  const PlayerMainControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShowQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(playerModeProvider);
    final (modeIcon, modeTooltip) = switch (mode) {
      PlayMode.sequence => (Icons.repeat_rounded, '播放模式：顺序播放'),
      PlayMode.shuffle => (Icons.shuffle_rounded, '播放模式：随机播放'),
      PlayMode.single => (Icons.repeat_one_rounded, '播放模式：单曲循环'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PlayerControlButton(
                icon: modeIcon,
                size: 24,
                tooltip: modeTooltip,
                isActive: mode != PlayMode.sequence,
                onPressed: () {
                  ref.read(playerModeProvider.notifier).nextMode();
                },
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerControlButton(
                  icon: Icons.skip_previous_rounded,
                  size: 36,
                  tooltip: '上一首',
                  onPressed: onPrevious,
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: isPlaying ? '暂停' : '播放',
                  child: Semantics(
                    button: true,
                    label: isPlaying ? '暂停' : '播放',
                    child: GestureDetector(
                      onTap: onPlayPause,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              LoginColors.accentPurple,
                              LoginColors.accentPink,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: LoginColors.accentPurple.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PlayerControlButton(
                  icon: Icons.skip_next_rounded,
                  size: 36,
                  tooltip: '下一首',
                  onPressed: onNext,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PlayerControlButton(
                icon: Icons.queue_music_rounded,
                size: 24,
                tooltip: '当前播放队列',
                onPressed: onShowQueue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
