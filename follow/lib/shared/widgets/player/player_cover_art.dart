import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

const vinylRecordSurfaceKey = ValueKey('vinyl-record-surface');
const vinylRecordVisualKey = ValueKey('vinyl-record-visual');
const vinylRotationKey = ValueKey('vinyl-record-rotation');
const vinylGroovesKey = ValueKey('vinyl-record-grooves');
const vinylSpindleKey = ValueKey('vinyl-record-spindle');

/// Large circular record surface for the mobile player.
class PlayerCoverArt extends StatefulWidget {
  final Track track;
  final double size;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final Offset restingOffset;
  final ValueChanged<Offset>? onVisualOffsetChanged;
  final ValueChanged<bool>? onDragStateChanged;
  final bool applyVisualOffset;
  final double maxVerticalVisualOffset;
  final bool isPlaying;
  final bool isBusy;

  const PlayerCoverArt({
    super.key,
    required this.track,
    this.size = 280,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.restingOffset = Offset.zero,
    this.onVisualOffsetChanged,
    this.onDragStateChanged,
    this.applyVisualOffset = true,
    this.maxVerticalVisualOffset = double.infinity,
    this.isPlaying = false,
    this.isBusy = false,
  }) : assert(maxVerticalVisualOffset >= 0);

  @override
  State<PlayerCoverArt> createState() => _PlayerCoverArtState();
}

class _PlayerCoverArtState extends State<PlayerCoverArt>
    with SingleTickerProviderStateMixin {
  static const _axisLockThreshold = 10.0;
  static const _distanceThreshold = 56.0;
  static const _velocityThreshold = 700.0;
  static const _minimumFlingDistance = 16.0;

  Offset _rawDragOffset = Offset.zero;
  Offset _dragOffset = Offset.zero;
  Axis? _lockedAxis;
  bool _isDragging = false;
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant PlayerCoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.isBusy != widget.isBusy) {
      _syncRotation();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _syncRotation() {
    final shouldRotate =
        widget.isPlaying &&
        !widget.isBusy &&
        !_isDragging &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldRotate) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  void _handlePanStart(DragStartDetails _) {
    if (widget.isBusy) return;
    setState(() {
      _isDragging = true;
      _rawDragOffset = Offset.zero;
      _dragOffset = Offset.zero;
      _lockedAxis = null;
    });
    _syncRotation();
    widget.onDragStateChanged?.call(true);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.isBusy || !_isDragging) return;
    setState(() {
      _rawDragOffset += details.delta;
      if (_lockedAxis == null &&
          _rawDragOffset.distance >= _axisLockThreshold) {
        _lockedAxis = _rawDragOffset.dx.abs() > _rawDragOffset.dy.abs()
            ? Axis.horizontal
            : Axis.vertical;
      }
      final projectedOffset = switch (_lockedAxis) {
        Axis.horizontal => Offset(_rawDragOffset.dx, 0),
        Axis.vertical => Offset(0, _rawDragOffset.dy),
        null => Offset.zero,
      };
      _dragOffset = _lockedAxis == Axis.vertical
          ? Offset(
              0,
              projectedOffset.dy.clamp(
                -widget.maxVerticalVisualOffset,
                widget.maxVerticalVisualOffset,
              ),
            )
          : projectedOffset;
    });
    widget.onVisualOffsetChanged?.call(widget.restingOffset + _dragOffset);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.isBusy || !_isDragging) {
      _resetDrag();
      return;
    }

    final horizontal = _lockedAxis == Axis.horizontal;
    final distance = horizontal ? _rawDragOffset.dx : _rawDragOffset.dy;
    final velocity = horizontal
        ? details.velocity.pixelsPerSecond.dx
        : details.velocity.pixelsPerSecond.dy;
    final completed =
        distance.abs() >= _distanceThreshold ||
        (distance.abs() >= _minimumFlingDistance &&
            velocity.abs() >= _velocityThreshold);

    VoidCallback? callback;
    if (completed) {
      callback = horizontal
          ? (distance < 0 ? widget.onSwipeLeft : widget.onSwipeRight)
          : (distance < 0 ? widget.onSwipeUp : widget.onSwipeDown);
    }

    _resetDrag(notify: callback == null);
    if (callback != null) {
      HapticFeedback.selectionClick();
      callback();
    }
  }

  void _resetDrag({bool notify = true}) {
    if (!mounted) return;
    setState(() {
      _isDragging = false;
      _rawDragOffset = Offset.zero;
      _dragOffset = Offset.zero;
      _lockedAxis = null;
    });
    widget.onDragStateChanged?.call(false);
    _syncRotation();
    if (notify) {
      widget.onVisualOffsetChanged?.call(widget.restingOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final visualOffset = reduceMotion
        ? widget.restingOffset
        : widget.restingOffset + _dragOffset;
    final appliedOffset = widget.applyVisualOffset ? visualOffset : Offset.zero;

    return Semantics(
      image: true,
      label: '唱片封面：${widget.track.title}。上滑下一首，下滑上一首，左滑歌词，右滑播放队列',
      child: GestureDetector(
        key: vinylRecordSurfaceKey,
        behavior: HitTestBehavior.opaque,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onPanCancel: _resetDrag,
        child: AnimatedContainer(
          key: vinylRecordVisualKey,
          duration: reduceMotion || _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            appliedOffset.dx,
            appliedOffset.dy,
            0,
          ),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isDark ? LoginColors.accentPurple : Colors.black)
                    .withValues(alpha: isDark ? 0.32 : 0.14),
                blurRadius: 40,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: RotationTransition(
            key: vinylRotationKey,
            turns: _rotationController,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TrackCoverImage(track: widget.track, size: widget.size),
                  ColoredBox(color: Colors.black.withValues(alpha: 0.16)),
                  CustomPaint(
                    key: vinylGroovesKey,
                    painter: _VinylGroovePainter(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: widget.size * 0.25,
                      height: widget.size * 0.25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.68),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        key: vinylSpindleKey,
                        width: math.max(8, widget.size * 0.035),
                        height: math.max(8, widget.size * 0.035),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
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

class _VinylGroovePainter extends CustomPainter {
  const _VinylGroovePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final fraction in [0.92, 0.8, 0.68, 0.56, 0.42]) {
      canvas.drawCircle(center, maxRadius * fraction, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylGroovePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
