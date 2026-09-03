import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

const foldedTrackQueueKey = ValueKey('folded-track-queue');
const foldedQueueListKey = ValueKey('folded-queue-list');
const foldedQueueRevealKey = ValueKey('folded-queue-reveal');
const foldedQueueInteractionKey = ValueKey('folded-queue-interaction');
const foldedQueuePaletteSurfaceKey = ValueKey('folded-queue-palette-surface');

Key foldedQueueTrackKey(String trackId) {
  return ValueKey('folded-queue-track-$trackId');
}

Key foldedQueueScaleKey(String trackId) {
  return ValueKey('folded-queue-scale-$trackId');
}

String _compactTrackTitle(String title) {
  const characterLimit = 8;
  final characters = title.characters;
  if (characters.length <= characterLimit) return title;
  return '${characters.take(characterLimit).join()}…';
}

/// Small circular queue covers painted underneath the main record.
class FoldedTrackQueue extends StatefulWidget {
  const FoldedTrackQueue({
    super.key,
    required this.tracks,
    required this.currentTrackId,
    required this.onSelect,
    this.revealProgress = 1,
    this.onInteractionStart,
    this.onInteractionSettled,
    this.onScrollSettled,
    this.palette,
  });

  final List<Track> tracks;
  final String? currentTrackId;
  final ValueChanged<int> onSelect;
  final double revealProgress;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionSettled;
  final VoidCallback? onScrollSettled;
  final PlayerPalette? palette;

  @override
  State<FoldedTrackQueue> createState() => _FoldedTrackQueueState();
}

class _FoldedTrackQueueState extends State<FoldedTrackQueue>
    with SingleTickerProviderStateMixin {
  static const _itemExtent = 88.0;
  static const _coverCenterOffset = 32.0;
  static const _titleWidth = 112.0;
  static const _scrollGestureThreshold = 10.0;

  late final ScrollController _controller;
  late final AnimationController _revealController;
  late int _centeredIndex;
  bool _pointerIsDown = false;
  bool _isSnapping = false;
  bool _settleScheduled = false;
  bool _userInteractionActive = false;
  bool _userScrolled = false;
  double _pointerVerticalDistance = 0;

  int get _currentIndex =>
      widget.tracks.indexWhere((track) => track.id == widget.currentTrackId);

  @override
  void initState() {
    super.initState();
    _centeredIndex = math.max(0, _currentIndex);
    _controller = ScrollController(
      initialScrollOffset: _centeredIndex * _itemExtent,
    )..addListener(_handleScrollPosition);
    _revealController = AnimationController(
      vsync: this,
      value: widget.revealProgress.clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(covariant FoldedTrackQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    final progress = widget.revealProgress.clamp(0.0, 1.0);
    if (progress > 0 && progress < 1) {
      _revealController.value = progress;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _revealController.value = progress;
    } else {
      _revealController.animateTo(progress, curve: Curves.easeOutCubic);
    }
    if (oldWidget.currentTrackId == widget.currentTrackId ||
        widget.tracks.isEmpty) {
      return;
    }
    final index = math.max(0, _currentIndex);
    _centeredIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients && !_pointerIsDown) {
        _controller.jumpTo(index * _itemExtent);
      }
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _controller
      ..removeListener(_handleScrollPosition)
      ..dispose();
    super.dispose();
  }

  void _handleScrollPosition() {
    if (!_controller.hasClients || widget.tracks.isEmpty) return;
    final index = (_controller.offset / _itemExtent).round().clamp(
      0,
      widget.tracks.length - 1,
    );
    if (index != _centeredIndex && mounted) {
      setState(() => _centeredIndex = index);
    }
  }

  Future<void> _snapAndSelect(int index) async {
    if (_isSnapping || widget.tracks.isEmpty) return;
    final targetIndex = index.clamp(0, widget.tracks.length - 1);
    final targetOffset = targetIndex * _itemExtent;
    _isSnapping = true;
    try {
      if (_controller.hasClients &&
          (_controller.offset - targetOffset).abs() > 0.5) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _controller.jumpTo(targetOffset);
        } else {
          await _controller.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      }
      if (!mounted) return;
      setState(() => _centeredIndex = targetIndex);
      if (targetIndex != _currentIndex) widget.onSelect(targetIndex);
    } finally {
      _isSnapping = false;
      if (_userInteractionActive) {
        final didScroll = _userScrolled;
        _userInteractionActive = false;
        _userScrolled = false;
        _pointerVerticalDistance = 0;
        widget.onInteractionSettled?.call();
        if (didScroll) widget.onScrollSettled?.call();
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        !_pointerIsDown &&
        !_settleScheduled &&
        !_isSnapping) {
      _settleScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _settleScheduled = false;
        if (mounted && !_pointerIsDown) {
          _snapAndSelect(_centeredIndex);
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        widget.palette ??
        PlayerPalette.fallback(
          brightness: theme.brightness,
          tokens: context.followTokens,
        );
    final progress = widget.revealProgress.clamp(0.0, 1.0);
    final queueContent = widget.tracks.isEmpty
        ? const AppStateView(
            kind: AppStateKind.nothingPlaying,
            title: '播放队列为空',
            description: '开始播放音乐后，接下来的歌曲会出现在这里。',
            illustrationSize: 96,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final topCenterPadding = math.max(
                0.0,
                constraints.maxHeight / 2 - _coverCenterOffset,
              );
              final bottomCenterPadding = math.max(
                0.0,
                constraints.maxHeight / 2 - (_itemExtent - _coverCenterOffset),
              );
              return Listener(
                onPointerDown: (_) {
                  if (!_pointerIsDown) {
                    setState(() {
                      _pointerIsDown = true;
                      _userInteractionActive = true;
                      _userScrolled = false;
                      _pointerVerticalDistance = 0;
                    });
                    widget.onInteractionStart?.call();
                  }
                },
                onPointerMove: (event) {
                  if (!_userInteractionActive || _userScrolled) return;
                  _pointerVerticalDistance += event.delta.dy.abs();
                  if (_pointerVerticalDistance >= _scrollGestureThreshold) {
                    _userScrolled = true;
                  }
                },
                onPointerUp: (_) {
                  if (_pointerIsDown) {
                    setState(() => _pointerIsDown = false);
                  }
                },
                onPointerCancel: (_) {
                  if (_pointerIsDown) {
                    setState(() => _pointerIsDown = false);
                  }
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: ListView.builder(
                    key: foldedQueueListKey,
                    controller: _controller,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: topCenterPadding,
                      bottom: bottomCenterPadding,
                    ),
                    itemExtent: _itemExtent,
                    itemCount: widget.tracks.length,
                    itemBuilder: (context, index) =>
                        _buildTrack(context, theme, palette, index),
                  ),
                ),
              );
            },
          );

    Widget reveal(double value, Widget child) => Opacity(
      key: foldedQueueRevealKey,
      opacity: value,
      child: Transform.translate(
        offset: Offset((1 - value) * 12, 0),
        child: child,
      ),
    );

    final transparentContentLayer = KeyedSubtree(
      key: foldedQueuePaletteSurfaceKey,
      child: queueContent,
    );

    final revealedQueue = AnimatedBuilder(
      animation: _revealController,
      builder: (context, child) => reveal(_revealController.value, child!),
      child: transparentContentLayer,
    );

    return SizedBox.expand(
      key: foldedTrackQueueKey,
      child: Material(
        type: MaterialType.transparency,
        child: IgnorePointer(
          key: foldedQueueInteractionKey,
          ignoring: progress < 0.98,
          child: revealedQueue,
        ),
      ),
    );
  }

  Widget _buildTrack(
    BuildContext context,
    ThemeData theme,
    PlayerPalette palette,
    int index,
  ) {
    final track = widget.tracks[index];
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final centeredPosition = _controller.hasClients
            ? _controller.offset / _itemExtent
            : _centeredIndex.toDouble();
        final distance = (index - centeredPosition).abs();
        final normalizedDistance = math.min(distance / 2.4, 1.0);
        final arcOffset = 42 * math.pow(normalizedDistance, 2);
        final scale = math.max(0.76, 1 - distance * 0.12);
        final opacity = math.max(0.52, 1 - distance * 0.16);
        final isCurrent = index == _currentIndex;
        final isCentered = index == centeredPosition.round();
        final showTitle = _pointerIsDown && isCentered;

        return Transform.translate(
          offset: Offset(arcOffset.toDouble(), 0),
          child: Opacity(
            opacity: opacity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  key: foldedQueueScaleKey(track.id),
                  alignment: Alignment.center,
                  scale: scale,
                  child: Semantics(
                    button: true,
                    selected: isCurrent,
                    label: isCurrent
                        ? '当前歌曲：${track.title}，点击播放'
                        : '歌曲：${track.title}，点击播放',
                    excludeSemantics: true,
                    child: SizedBox.square(
                      dimension: 64,
                      child: InkWell(
                        key: foldedQueueTrackKey(track.id),
                        onTap: () => _snapAndSelect(index),
                        customBorder: const CircleBorder(),
                        child: DecoratedBox(
                          key: ValueKey('folded-queue-accent-${track.id}'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: isCentered ? 3 : 1,
                              color: isCurrent
                                  ? palette.secondary
                                  : isCentered
                                  ? palette.secondary.withValues(alpha: 0.72)
                                  : theme.colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isCurrent ? palette.glow : Colors.black)
                                    .withValues(alpha: isCentered ? 0.34 : 0.2),
                                blurRadius: isCentered ? 14 : 8,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: TrackCoverImage(track: track, size: 58),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  key: ValueKey('folded-queue-title-slot-${track.id}'),
                  width: _titleWidth,
                  height: 20,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: showTitle
                        ? ExcludeSemantics(
                            child: Text(
                              _compactTrackTitle(track.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
