import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_scroll_geometry.dart';

const lyricsViewportKey = Key('interactive-lyrics-viewport');
const lyricsCenterPlayKey = Key('interactive-lyrics-center-play');

class InteractiveLyricsView extends StatefulWidget {
  const InteractiveLyricsView({
    super.key,
    required this.lyrics,
    required this.currentIndex,
    required this.foregroundColor,
    required this.onSeek,
    this.inactivityDelay = const Duration(seconds: 3),
    this.followDuration = const Duration(milliseconds: 280),
    this.returnDuration = const Duration(milliseconds: 400),
    this.seekDuration = const Duration(milliseconds: 220),
  });

  final AsyncValue<List<LyricLine>> lyrics;
  final int currentIndex;
  final Color foregroundColor;
  final Future<void> Function(Duration) onSeek;
  final Duration inactivityDelay;
  final Duration followDuration;
  final Duration returnDuration;
  final Duration seekDuration;

  @override
  State<InteractiveLyricsView> createState() => _InteractiveLyricsViewState();
}

class _InteractiveLyricsViewState extends State<InteractiveLyricsView> {
  static const _minimumRowHeight = 48.0;
  static const _maxRevealAttempts = 4;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final List<GlobalKey> _rowKeys = [];

  Timer? _inactivityTimer;
  bool _isBrowsing = false;
  int? _selectedIndex;
  bool _isProgrammaticScroll = false;
  bool _selectionUpdateScheduled = false;
  bool _gestureHadScrollActivity = false;
  double? _lastScrollPixels;
  int _scrollDirection = 1;
  int _operationToken = 0;

  @override
  void initState() {
    super.initState();
    _scheduleFollowCurrentLyric(animate: false);
  }

  @override
  void didUpdateWidget(covariant InteractiveLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIndexChanged = widget.currentIndex != oldWidget.currentIndex;
    final lyricsChanged = widget.lyrics != oldWidget.lyrics;
    final hasLyrics = widget.lyrics.value?.isNotEmpty ?? false;
    if ((currentIndexChanged || lyricsChanged) && hasLyrics && !_isBrowsing) {
      _scheduleFollowCurrentLyric(animate: currentIndexChanged);
    }
  }

  @override
  void dispose() {
    _operationToken++;
    _inactivityTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureRowKeys(int count) {
    while (_rowKeys.length < count) {
      _rowKeys.add(GlobalKey());
    }
    if (_rowKeys.length > count) {
      _rowKeys.removeRange(count, _rowKeys.length);
    }
  }

  Future<void> _waitForLayout() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  void _scheduleFollowCurrentLyric({required bool animate}) {
    final operationToken = ++_operationToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrentOperation(operationToken)) return;
      unawaited(
        _followCurrentLyric(animate: animate, operationToken: operationToken),
      );
    });
  }

  bool _isCurrentOperation(int operationToken, {bool allowBrowsing = false}) {
    return mounted &&
        operationToken == _operationToken &&
        (allowBrowsing || !_isBrowsing);
  }

  Future<bool> _followCurrentLyric({
    required bool animate,
    required int operationToken,
    bool allowBrowsing = false,
    Duration? duration,
    int? targetIndex,
  }) async {
    final lyrics = widget.lyrics.value;
    final index = targetIndex ?? widget.currentIndex;

    if (!_isCurrentOperation(operationToken, allowBrowsing: allowBrowsing) ||
        lyrics == null ||
        index < 0 ||
        index >= lyrics.length ||
        !_scrollController.hasClients) {
      return false;
    }

    _ensureRowKeys(lyrics.length);
    var row = _rowKeys[index].currentContext?.findRenderObject();
    for (
      var attempt = 0;
      (row == null || !row.attached) && attempt < _maxRevealAttempts;
      attempt++
    ) {
      final position = _scrollController.position;
      final estimatedOffset = lyrics.length <= 1
          ? 0.0
          : position.maxScrollExtent * index / (lyrics.length - 1);
      _isProgrammaticScroll = true;
      _scrollController.jumpTo(
        estimatedOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await _waitForLayout();

      if (!_isCurrentOperation(operationToken, allowBrowsing: allowBrowsing)) {
        return false;
      }
      row = _rowKeys[index].currentContext?.findRenderObject();
    }

    if (row == null ||
        !row.attached ||
        !_isCurrentOperation(operationToken, allowBrowsing: allowBrowsing)) {
      _isProgrammaticScroll = false;
      return false;
    }

    final viewport = RenderAbstractViewport.of(row);
    final position = _scrollController.position;
    final targetOffset = viewport
        .getOffsetToReveal(row, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    _isProgrammaticScroll = true;
    final animationDuration = duration ?? widget.followDuration;
    if (animate && animationDuration > Duration.zero) {
      await _scrollController.animateTo(
        targetOffset,
        duration: animationDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }

    final completed = _isCurrentOperation(
      operationToken,
      allowBrowsing: allowBrowsing,
    );
    if (_isProgrammaticScroll && completed) {
      _isProgrammaticScroll = false;
    }
    return completed;
  }

  void _beginBrowsing() {
    _inactivityTimer?.cancel();
    _operationToken++;
    _lastScrollPixels = _scrollController.hasClients
        ? _scrollController.offset
        : null;

    if (_isProgrammaticScroll && _scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      _scrollController.jumpTo(currentOffset);
    }
    _isProgrammaticScroll = false;

    if (!_isBrowsing) {
      setState(() => _isBrowsing = true);
    }
    _scheduleCenterSelection();
  }

  void _restartInactivityTimer() {
    if (!_isBrowsing) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      widget.inactivityDelay,
      () => unawaited(_returnToPlayback()),
    );
  }

  Future<void> _returnToPlayback() async {
    if (!_isBrowsing) return;

    final operationToken = ++_operationToken;
    while (_isCurrentOperation(operationToken, allowBrowsing: true)) {
      final targetIndex = widget.currentIndex;
      final completed = await _followCurrentLyric(
        animate: true,
        operationToken: operationToken,
        allowBrowsing: true,
        duration: widget.returnDuration,
        targetIndex: targetIndex,
      );
      if (!completed ||
          !_isCurrentOperation(operationToken, allowBrowsing: true)) {
        return;
      }
      if (widget.currentIndex != targetIndex) continue;

      setState(() {
        _isBrowsing = false;
        _selectedIndex = null;
      });
      return;
    }
  }

  void _scheduleCenterSelection() {
    if (_selectionUpdateScheduled) return;
    _selectionUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionUpdateScheduled = false;
      if (mounted && _isBrowsing) _updateCenterSelection();
    });
  }

  void _updateCenterSelection() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;

    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    final rows = <VisibleLyricGeometry>[];
    for (var index = 0; index < _rowKeys.length; index++) {
      final row = _rowKeys[index].currentContext?.findRenderObject();
      if (row is! RenderBox || !row.attached) continue;

      final rowTop = row.localToGlobal(Offset.zero).dy;
      final rowBottom = rowTop + row.size.height;
      if (rowBottom < viewportTop || rowTop > viewportBottom) continue;
      rows.add(
        VisibleLyricGeometry(
          index: index,
          center: rowTop + row.size.height / 2,
        ),
      );
    }

    final selectedIndex = findNearestLyricIndex(
      rows: rows,
      viewportCenter: viewportTop + viewport.size.height / 2,
      scrollDirection: _scrollDirection,
    );
    if (selectedIndex != null && selectedIndex != _selectedIndex) {
      setState(() => _selectedIndex = selectedIndex);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _beginBrowsing();
    _restartInactivityTimer();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _gestureHadScrollActivity = false;
    _beginBrowsing();
  }

  void _handlePointerEnd(PointerEvent event) {
    final shouldStartInactivityTimer = !_gestureHadScrollActivity;
    _gestureHadScrollActivity = false;
    if (shouldStartInactivityTimer) _restartInactivityTimer();
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    _gestureHadScrollActivity = false;
    _beginBrowsing();
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _gestureHadScrollActivity = true;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isProgrammaticScroll) return false;

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _gestureHadScrollActivity = true;
      if (!_isBrowsing) _beginBrowsing();
    }

    if (notification is ScrollUpdateNotification && _isBrowsing) {
      if (notification.dragDetails != null) {
        _gestureHadScrollActivity = true;
      }
      final previousPixels = _lastScrollPixels;
      final pixels = notification.metrics.pixels;
      if (previousPixels != null && pixels != previousPixels) {
        _scrollDirection = pixels > previousPixels ? 1 : -1;
      } else if (notification.scrollDelta case final delta? when delta != 0) {
        _scrollDirection = delta > 0 ? 1 : -1;
      }
      _lastScrollPixels = pixels;
      _scheduleCenterSelection();
    }

    if (_isBrowsing &&
        (notification is ScrollEndNotification ||
            notification is UserScrollNotification &&
                notification.direction == ScrollDirection.idle)) {
      _gestureHadScrollActivity = false;
      _restartInactivityTimer();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.lyrics.when(
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: TextStyle(
                fontSize: 16,
                color: widget.foregroundColor.withValues(alpha: 0.5),
              ),
            ),
          );
        }

        _ensureRowKeys(lyrics.length);
        return LayoutBuilder(
          builder: (context, constraints) {
            final boundarySpace = constraints.maxHeight / 2;
            return Stack(
              key: _viewportKey,
              fit: StackFit.expand,
              children: [
                Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerUp: _handlePointerEnd,
                  onPointerCancel: _handlePointerEnd,
                  onPointerSignal: _handlePointerSignal,
                  onPointerPanZoomStart: _handlePanZoomStart,
                  onPointerPanZoomUpdate: _handlePanZoomUpdate,
                  onPointerPanZoomEnd: _handlePointerEnd,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: ListView.builder(
                      key: lyricsViewportKey,
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: boundarySpace,
                      ),
                      itemCount: lyrics.length,
                      itemBuilder: (context, index) {
                        final lyric = lyrics[index];
                        final isCurrent = index == widget.currentIndex;
                        final isSelected =
                            _isBrowsing && _selectedIndex == index;
                        final isEmphasized = isCurrent || isSelected;

                        return KeyedSubtree(
                          key: ValueKey('lyric-row-$index'),
                          child: ConstrainedBox(
                            key: _rowKeys[index],
                            constraints: const BoxConstraints(
                              minHeight: _minimumRowHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                  lyric.text,
                                  style: TextStyle(
                                    fontSize: isEmphasized ? 18 : 15,
                                    fontWeight: isEmphasized
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isEmphasized
                                        ? widget.foregroundColor
                                        : widget.foregroundColor.withValues(
                                            alpha: 0.4,
                                          ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_isBrowsing)
                  Positioned(
                    left: 12,
                    top: boundarySpace - 12,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        key: lyricsCenterPlayKey,
                        size: 24,
                        color: widget.foregroundColor,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: widget.foregroundColor),
      ),
      error: (_, _) => LyricsFailureView(
        foregroundColor: widget.foregroundColor.withValues(alpha: 0.5),
      ),
    );
  }
}
