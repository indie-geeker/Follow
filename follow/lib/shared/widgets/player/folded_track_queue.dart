import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

const foldedTrackQueueKey = ValueKey('folded-track-queue');
const foldedQueueListKey = ValueKey('folded-queue-list');
const foldedQueueRevealKey = ValueKey('folded-queue-reveal');
const foldedQueueInteractionKey = ValueKey('folded-queue-interaction');

Key foldedQueueTrackKey(String trackId) {
  return ValueKey('folded-queue-track-$trackId');
}

Key foldedQueueScaleKey(String trackId) {
  return ValueKey('folded-queue-scale-$trackId');
}

/// Small circular queue covers painted underneath the main record.
class FoldedTrackQueue extends StatefulWidget {
  const FoldedTrackQueue({
    super.key,
    required this.tracks,
    required this.currentTrackId,
    required this.onSelect,
    this.revealProgress = 1,
  });

  final List<Track> tracks;
  final String? currentTrackId;
  final ValueChanged<int> onSelect;
  final double revealProgress;

  @override
  State<FoldedTrackQueue> createState() => _FoldedTrackQueueState();
}

class _FoldedTrackQueueState extends State<FoldedTrackQueue> {
  static const _itemExtent = 68.0;

  late final ScrollController _controller;
  late int _centeredIndex;
  bool _pointerIsDown = false;
  bool _isSnapping = false;
  bool _settleScheduled = false;

  int get _currentIndex =>
      widget.tracks.indexWhere((track) => track.id == widget.currentTrackId);

  @override
  void initState() {
    super.initState();
    _centeredIndex = math.max(0, _currentIndex);
    _controller = ScrollController(
      initialScrollOffset: _centeredIndex * _itemExtent,
    )..addListener(_handleScrollPosition);
  }

  @override
  void didUpdateWidget(covariant FoldedTrackQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final progress = widget.revealProgress.clamp(0.0, 1.0);

    return SizedBox.expand(
      key: foldedTrackQueueKey,
      child: Material(
        type: MaterialType.transparency,
        child: Opacity(
          key: foldedQueueRevealKey,
          opacity: progress,
          child: IgnorePointer(
            key: foldedQueueInteractionKey,
            ignoring: progress < 0.98,
            child: widget.tracks.isEmpty
                ? const Center(child: Text('当前播放队列为空'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final centerPadding = math.max(
                        0.0,
                        (constraints.maxHeight - _itemExtent) / 2,
                      );
                      return Listener(
                        onPointerDown: (_) {
                          if (!_pointerIsDown) {
                            setState(() => _pointerIsDown = true);
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
                            padding: EdgeInsets.symmetric(
                              vertical: centerPadding,
                            ),
                            itemExtent: _itemExtent,
                            itemCount: widget.tracks.length,
                            itemBuilder: (context, index) =>
                                _buildTrack(context, theme, index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrack(BuildContext context, ThemeData theme, int index) {
    final track = widget.tracks[index];
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final centeredPosition = _controller.hasClients
            ? _controller.offset / _itemExtent
            : _centeredIndex.toDouble();
        final distance = (index - centeredPosition).abs();
        final normalizedDistance = math.min(distance / 2.4, 1.0);
        final arcOffset = 42 * (1 - math.pow(normalizedDistance, 2));
        final scale = math.max(0.76, 1 - distance * 0.12);
        final opacity = math.max(0.52, 1 - distance * 0.16);
        final isCurrent = index == _currentIndex;
        final isCentered = index == centeredPosition.round();
        final showTitle = _pointerIsDown && isCentered;

        return Transform.translate(
          offset: Offset(arcOffset.toDouble(), 0),
          child: Opacity(
            opacity: opacity,
            child: Row(
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
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: isCentered ? 3 : 1,
                              color: isCentered
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isCentered ? 0.34 : 0.2,
                                ),
                                blurRadius: isCentered ? 14 : 8,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: ClipOval(
                            child: TrackCoverImage(track: track, size: 58),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showTitle) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
