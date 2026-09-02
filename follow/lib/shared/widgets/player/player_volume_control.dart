import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/providers/audio_provider.dart';

class PlayerVolumeControl extends ConsumerStatefulWidget {
  const PlayerVolumeControl({super.key, this.onInteractionStart, this.palette});

  final VoidCallback? onInteractionStart;
  final PlayerPalette? palette;

  @override
  ConsumerState<PlayerVolumeControl> createState() =>
      _PlayerVolumeControlState();
}

class _PlayerVolumeControlState extends ConsumerState<PlayerVolumeControl> {
  double? _observedVolume;
  double? _displayedVolume;
  double _lastAudibleVolume = 1.0;

  void _syncObservedVolume(double volume) {
    if (_observedVolume == volume) return;

    _observedVolume = volume;
    _displayedVolume = volume;
    if (volume > 0) _lastAudibleVolume = volume;
  }

  Future<void> _setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    setState(() {
      _displayedVolume = clampedVolume;
      if (clampedVolume > 0) _lastAudibleVolume = clampedVolume;
    });
    await ref.read(audioPlayerServiceProvider).setVolume(clampedVolume);
  }

  Future<void> _toggleMute() async {
    widget.onInteractionStart?.call();
    final current = _displayedVolume ?? 1.0;
    final (nextVolume, lastAudible) = nextMuteVolume(
      current: current,
      lastAudible: _lastAudibleVolume,
    );
    setState(() {
      _displayedVolume = nextVolume;
      _lastAudibleVolume = lastAudible;
    });
    await ref.read(audioPlayerServiceProvider).setVolume(nextVolume);
  }

  @override
  Widget build(BuildContext context) {
    final volumeAsync = ref.watch(playerVolumeProvider);
    _syncObservedVolume(volumeAsync.value ?? _displayedVolume ?? 1.0);
    final volume = _displayedVolume ?? 1.0;
    final isMuted = volume <= 0;
    final brightness = Theme.of(context).brightness;
    final palette =
        widget.palette ??
        PlayerPalette.fallback(
          brightness: brightness,
          tokens: context.followTokens,
        );

    return Row(
      children: [
        IconButton(
          tooltip: isMuted ? '取消静音' : '静音',
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          icon: Icon(
            isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          ),
          onPressed: _toggleMute,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: palette.secondary,
              thumbColor: palette.secondary,
              overlayColor: palette.secondary.withValues(alpha: 0.14),
            ),
            child: Slider(
              value: volume,
              onChangeStart: (_) => widget.onInteractionStart?.call(),
              onChanged: _setVolume,
            ),
          ),
        ),
      ],
    );
  }
}
