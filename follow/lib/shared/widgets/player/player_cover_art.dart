import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

const vinylRecordSurfaceKey = ValueKey('vinyl-record-surface');
const vinylRecordVisualKey = ValueKey('vinyl-record-visual');
const vinylRotationKey = ValueKey('vinyl-record-rotation');
const vinylGroovesKey = ValueKey('vinyl-record-grooves');
const vinylSpindleKey = ValueKey('vinyl-record-spindle');
const vinylCoverLayerKey = ValueKey('vinyl-cover-layer');
const vinylEdgeAssetKey = ValueKey('vinyl-edge-asset');
const vinylTonearmKey = ValueKey('vinyl-tonearm');
const vinylTonearmRotationKey = ValueKey('vinyl-tonearm-rotation');
const vinylTonearmAssetKey = ValueKey('vinyl-tonearm-asset');
const vinylCurrentRecordPageKey = ValueKey('vinyl-record-page-current');
const vinylPreviousRecordPageKey = ValueKey('vinyl-record-page-previous');
const vinylNextRecordPageKey = ValueKey('vinyl-record-page-next');

const _vinylEdgeAssetPath = 'assets/images/music-circle.png';
const _tonearmAssetPath = 'assets/images/play-bar.png';

/// Large circular record surface for the mobile player.
class PlayerCoverArt extends StatefulWidget {
  final Track track;
  final Track? previousTrack;
  final Track? nextTrack;
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
  final bool Function()? onInteractionAttempt;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onTap;
  final PlayerPalette? palette;

  const PlayerCoverArt({
    super.key,
    required this.track,
    this.previousTrack,
    this.nextTrack,
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
    this.onInteractionAttempt,
    this.onInteractionStart,
    this.onTap,
    this.palette,
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
  static const _pageGap = 12.0;
  static const _pageSettleDuration = Duration(milliseconds: 240);
  static const _tonearmSettleDuration = Duration(milliseconds: 350);
  static const _tonearmRestingTurns = -25 / 360;
  static const _tonearmPlayingTurns = -3 / 360;
  static const _tonearmPivotFractionX = 0.11;
  static const _tonearmPivot = Alignment(_tonearmPivotFractionX * 2 - 1, -0.86);
  static const _tonearmWidthFactor = 0.50;
  static const _tonearmHeightFactor = 0.75;

  Offset _rawDragOffset = Offset.zero;
  Offset _dragOffset = Offset.zero;
  Axis? _lockedAxis;
  bool _isDragging = false;
  bool _isSettling = false;
  bool _interactionConsumed = false;
  bool _pendingTrackHandoff = false;
  bool _skipNextPageAnimation = false;
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
    final trackChanged = oldWidget.track.id != widget.track.id;
    final completesPendingHandoff = _pendingTrackHandoff && trackChanged;
    if (completesPendingHandoff) {
      _applySettledPageRebase();
      _schedulePageAnimationRestore();
    }
    if (trackChanged) {
      _rotationController.value = 0;
    }
    if (oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.isBusy != widget.isBusy ||
        trackChanged) {
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
        !_isSettling &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldRotate) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  void _handlePanDown(DragDownDetails _) {
    _interactionConsumed = widget.onInteractionAttempt?.call() ?? false;
    if (_interactionConsumed) return;
    widget.onInteractionStart?.call();
  }

  void _handlePanCancel() {
    if (_interactionConsumed) {
      _interactionConsumed = false;
      return;
    }
    final shouldTap = !_isDragging && !_isSettling && !widget.isBusy;
    _resetDrag(notify: !shouldTap);
    if (shouldTap) widget.onTap?.call();
  }

  void _handlePanStart(DragStartDetails _) {
    if (_interactionConsumed) return;
    if (widget.isBusy || _isSettling) return;
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
    if (_interactionConsumed) return;
    if (widget.isBusy || _isSettling || !_isDragging) return;
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
    if (_interactionConsumed) {
      _interactionConsumed = false;
      return;
    }
    if (_isSettling) return;
    if (widget.isBusy || !_isDragging) {
      _resetDrag();
      return;
    }
    if (_lockedAxis == null && _rawDragOffset.distance < _axisLockThreshold) {
      _resetDrag(notify: false);
      widget.onTap?.call();
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

    if (callback != null && !horizontal) {
      _completeVerticalPageTurn(callback, distance < 0 ? -1 : 1);
      return;
    }

    _resetDrag(notify: callback == null);
    if (callback != null) {
      HapticFeedback.selectionClick();
      callback();
    }
  }

  void _handleSemanticTap() {
    if (widget.onInteractionAttempt?.call() ?? false) return;
    widget.onTap?.call();
  }

  Future<void> _completeVerticalPageTurn(
    VoidCallback callback,
    int direction,
  ) async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final targetOffset = direction * (widget.size + _pageGap);
    final adjacentTrack = direction < 0
        ? widget.nextTrack
        : widget.previousTrack;
    setState(() {
      _isDragging = false;
      _isSettling = true;
      _pendingTrackHandoff =
          adjacentTrack != null && adjacentTrack.id != widget.track.id;
      _rawDragOffset = Offset(0, targetOffset);
      _dragOffset = Offset(
        0,
        targetOffset.clamp(
          -widget.maxVerticalVisualOffset,
          widget.maxVerticalVisualOffset,
        ),
      );
    });
    widget.onDragStateChanged?.call(false);
    _syncRotation();

    if (!reduceMotion) await Future<void>.delayed(_pageSettleDuration);
    if (!mounted) return;
    HapticFeedback.selectionClick();
    callback();
    if (adjacentTrack == null || adjacentTrack.id == widget.track.id) {
      _rebaseSettledPage();
    }
  }

  void _rebaseSettledPage() {
    setState(_applySettledPageRebase);
    _schedulePageAnimationRestore();
    _syncRotation();
  }

  void _applySettledPageRebase() {
    _isDragging = false;
    _isSettling = false;
    _pendingTrackHandoff = false;
    _rawDragOffset = Offset.zero;
    _dragOffset = Offset.zero;
    _lockedAxis = null;
    _skipNextPageAnimation = true;
  }

  void _schedulePageAnimationRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_skipNextPageAnimation) return;
      setState(() => _skipNextPageAnimation = false);
    });
  }

  void _resetDrag({bool notify = true}) {
    if (!mounted) return;
    setState(() {
      _isDragging = false;
      _rawDragOffset = Offset.zero;
      _dragOffset = Offset.zero;
      _lockedAxis = null;
      _isSettling = false;
      _pendingTrackHandoff = false;
    });
    widget.onDragStateChanged?.call(false);
    _syncRotation();
    if (notify) {
      widget.onVisualOffsetChanged?.call(widget.restingOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final palette =
        widget.palette ??
        PlayerPalette.fallback(
          brightness: brightness,
          tokens: context.followTokens,
        );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final visualOffset = reduceMotion
        ? widget.restingOffset
        : widget.restingOffset + _dragOffset;
    final appliedOffset = widget.applyVisualOffset ? visualOffset : Offset.zero;
    final verticalPageOffset = reduceMotion || _lockedAxis != Axis.vertical
        ? 0.0
        : _rawDragOffset.dy.clamp(
            -(widget.size + _pageGap),
            widget.size + _pageGap,
          );
    final pageAnimationDuration =
        reduceMotion || _isDragging || _skipNextPageAnimation
        ? Duration.zero
        : _pageSettleDuration;
    final tonearmWidth = widget.size * _tonearmWidthFactor;
    final tonearmHeight = widget.size * _tonearmHeightFactor;
    final tonearmLeft = widget.size / 2 - tonearmWidth * _tonearmPivotFractionX;

    return Semantics(
      image: true,
      button: true,
      onTap: _handleSemanticTap,
      label:
          '唱片封面：${widget.track.title}。点击${widget.isPlaying ? '暂停' : '播放'}，上滑下一首，下滑上一首，左滑歌词，右滑播放队列',
      child: GestureDetector(
        key: vinylRecordSurfaceKey,
        behavior: HitTestBehavior.opaque,
        onPanDown: _handlePanDown,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onPanCancel: _handlePanCancel,
        child: AnimatedContainer(
          key: vinylRecordVisualKey,
          duration: reduceMotion || _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(appliedOffset.dx, 0, 0),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.glow.withValues(alpha: 0.32),
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
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.previousTrack case final previousTrack?)
                      _buildRecordPage(
                        key: vinylPreviousRecordPageKey,
                        track: previousTrack,
                        verticalOffset:
                            verticalPageOffset - (widget.size + _pageGap),
                        duration: pageAnimationDuration,
                      ),
                    _buildRecordPage(
                      key: vinylCurrentRecordPageKey,
                      track: widget.track,
                      verticalOffset: verticalPageOffset,
                      duration: pageAnimationDuration,
                      isCurrent: true,
                    ),
                    if (widget.nextTrack case final nextTrack?)
                      _buildRecordPage(
                        key: vinylNextRecordPageKey,
                        track: nextTrack,
                        verticalOffset:
                            verticalPageOffset + widget.size + _pageGap,
                        duration: pageAnimationDuration,
                      ),
                  ],
                ),
              ),
              Positioned(
                key: vinylTonearmKey,
                left: tonearmLeft,
                top: -widget.size * 0.28,
                width: tonearmWidth,
                height: tonearmHeight,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: AnimatedRotation(
                      key: vinylTonearmRotationKey,
                      turns: widget.isPlaying
                          ? _tonearmPlayingTurns
                          : _tonearmRestingTurns,
                      alignment: _tonearmPivot,
                      duration: reduceMotion
                          ? Duration.zero
                          : _tonearmSettleDuration,
                      curve: Curves.easeInOutCubic,
                      child: Image.asset(
                        _tonearmAssetPath,
                        key: vinylTonearmAssetKey,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordPage({
    required Key key,
    required Track track,
    required double verticalOffset,
    required Duration duration,
    bool isCurrent = false,
  }) {
    final coverSize = widget.size * 0.69;
    final record = Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: SizedBox.square(
            key: isCurrent ? vinylCoverLayerKey : null,
            dimension: coverSize,
            child: ClipOval(
              child: TrackCoverImage(track: track, size: coverSize),
            ),
          ),
        ),
        KeyedSubtree(
          key: isCurrent ? vinylGroovesKey : null,
          child: Image.asset(
            _vinylEdgeAssetPath,
            key: isCurrent ? vinylEdgeAssetKey : null,
            fit: BoxFit.contain,
          ),
        ),
        Center(
          child: Container(
            key: isCurrent ? vinylSpindleKey : null,
            width: math.max(8, widget.size * 0.035),
            height: math.max(8, widget.size * 0.035),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.black.withValues(alpha: 0.32)),
            ),
          ),
        ),
      ],
    );

    return AnimatedContainer(
      key: key,
      duration: duration,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, verticalOffset, 0),
      child: isCurrent
          ? RotationTransition(
              key: vinylRotationKey,
              turns: _rotationController,
              child: record,
            )
          : ExcludeSemantics(child: record),
    );
  }
}
