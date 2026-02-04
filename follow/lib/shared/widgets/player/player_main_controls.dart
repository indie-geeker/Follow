import 'package:flutter/material.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/shared/widgets/player/player_control_button.dart';

/// Main playback controls row including shuffle, prev, play/pause, next, repeat.
class PlayerMainControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  const PlayerMainControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PlayerControlButton(
          icon: Icons.shuffle_rounded,
          size: 24,
          onPressed: onShuffle,
        ),
        const SizedBox(width: 20),
        PlayerControlButton(
          icon: Icons.skip_previous_rounded,
          size: 36,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 20),

        // Play/Pause button with gradient
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [LoginColors.accentPurple, LoginColors.accentPink],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: LoginColors.accentPurple.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),

        const SizedBox(width: 20),
        PlayerControlButton(
          icon: Icons.skip_next_rounded,
          size: 36,
          onPressed: onNext,
        ),
        const SizedBox(width: 20),
        PlayerControlButton(
          icon: Icons.repeat_rounded,
          size: 24,
          onPressed: onRepeat,
        ),
      ],
    );
  }
}
