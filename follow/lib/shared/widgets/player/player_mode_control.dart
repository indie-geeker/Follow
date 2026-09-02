import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/shared/widgets/player/player_control_button.dart';

const playerModePopupKey = Key('player-mode-popup');
const playerModeButtonAnchorKey = Key('player-mode-button-anchor');

Key playerModePopupItemKey(PlayMode mode) =>
    Key('player-mode-popup-item-${mode.name}');

Key playerModePopupCheckKey(PlayMode mode) =>
    Key('player-mode-popup-check-${mode.name}');

/// Playback-mode button with a short-lived, non-modal mode picker.
class PlayerModeControl extends ConsumerStatefulWidget {
  const PlayerModeControl({super.key});

  @override
  ConsumerState<PlayerModeControl> createState() => _PlayerModeControlState();
}

class _PlayerModeControlState extends ConsumerState<PlayerModeControl>
    with SingleTickerProviderStateMixin {
  static const _popupDuration = Duration(seconds: 2);
  static const _animationDuration = Duration(milliseconds: 160);
  static const _popupWidth = 112.0;
  static const _viewportMargin = 8.0;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
      reverseDuration: _animationDuration,
    )..addStatusListener(_handleAnimationStatus);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animationController.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _hideTimer != null) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showPopup() {
    _hideTimer?.cancel();

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: _buildPopupOverlay);
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      _animationController.value = 1;
    } else {
      unawaited(_animationController.forward());
    }

    _hideTimer = Timer(_popupDuration, () => unawaited(_hidePopup()));
  }

  Future<void> _hidePopup() async {
    _hideTimer?.cancel();
    _hideTimer = null;

    if (_overlayEntry == null) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _animationController.value = 0;
    } else {
      await _animationController.reverse();
    }

    // A new tap may have restarted the forward animation while reverse awaited.
    if (!mounted || _animationController.status != AnimationStatus.dismissed) {
      return;
    }
    _handleAnimationStatus(_animationController.status);
  }

  void _cycleMode() {
    unawaited(ref.read(playerModeProvider.notifier).nextMode());
    _showPopup();
  }

  void _selectMode(PlayMode mode) {
    if (ref.read(playerModeProvider) != mode) {
      unawaited(ref.read(playerModeProvider.notifier).setMode(mode));
    }
    _showPopup();
  }

  double _popupHorizontalCorrection() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return 0;

    final anchorCenter = renderObject.localToGlobal(
      Offset(renderObject.size.width / 2, 0),
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final desiredLeft = anchorCenter.dx - _popupWidth / 2;
    final correctedLeft = desiredLeft.clamp(
      _viewportMargin,
      viewportWidth - _popupWidth - _viewportMargin,
    );
    return correctedLeft - desiredLeft;
  }

  Widget _buildPopupOverlay(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(fade);

    return Positioned(
      width: _popupWidth,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: Offset(_popupHorizontalCorrection(), -8),
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: Consumer(
              builder: (context, ref, _) {
                final selectedMode = ref.watch(playerModeProvider);
                return Material(
                  key: playerModePopupKey,
                  elevation: 10,
                  color: Theme.of(context).colorScheme.surface,
                  shadowColor: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: PlayMode.values
                        .map(
                          (mode) => _ModePopupItem(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            onTap: () => _selectMode(mode),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(playerModeProvider);
    final (icon, tooltip) = switch (mode) {
      PlayMode.sequence => (Icons.repeat_rounded, '播放模式：顺序播放'),
      PlayMode.shuffle => (Icons.shuffle_rounded, '播放模式：随机播放'),
      PlayMode.single => (Icons.repeat_one_rounded, '播放模式：单曲循环'),
    };

    return CompositedTransformTarget(
      key: playerModeButtonAnchorKey,
      link: _layerLink,
      child: PlayerControlButton(
        icon: icon,
        size: 24,
        tooltip: tooltip,
        isActive: mode != PlayMode.sequence,
        onPressed: _cycleMode,
      ),
    );
  }
}

class _ModePopupItem extends StatelessWidget {
  const _ModePopupItem({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final PlayMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => switch (mode) {
    PlayMode.sequence => '列表播放',
    PlayMode.shuffle => '随机模式',
    PlayMode.single => '单曲循环',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticsLabel = isSelected ? '$_label，已选择' : _label;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            key: playerModePopupItemKey(mode),
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            key: playerModePopupCheckKey(mode),
                            size: 20,
                            color: colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
