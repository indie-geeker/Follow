import 'package:flutter/material.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/player/player_control_button.dart';

/// Main playback controls for lyrics overlay with play mode toggle.
class LyricsControls extends StatelessWidget {
  final bool isPlaying;
  final PlayMode playMode;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onModeToggle;

  const LyricsControls({
    super.key,
    required this.isPlaying,
    required this.playMode,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onModeToggle,
  });

  IconData get _modeIcon {
    switch (playMode) {
      case PlayMode.sequence:
        return Icons.repeat_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerControlButton(
          icon: _modeIcon,
          size: 24,
          onPressed: onModeToggle,
        ),
        const SizedBox(width: 24),
        PlayerControlButton(
          icon: Icons.skip_previous_rounded,
          size: 32,
          onPressed: onPrevious,
        ),
        const SizedBox(width: 24),
        _PlayPauseButton(isPlaying: isPlaying, onPressed: onPlayPause),
        const SizedBox(width: 24),
        PlayerControlButton(
          icon: Icons.skip_next_rounded,
          size: 32,
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// Gradient play/pause button used in lyrics controls.
class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
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
    );
  }
}
