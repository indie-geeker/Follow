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
  static const _horizontalContentGutter = 56.0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final List<GlobalKey> _rowKeys = [];

  Timer? _inactivityTimer;
  bool _isBrowsing = false;
  int? _selectedIndex;
  bool _isProgrammaticScroll = false;
  bool _selectionUpdateScheduled = false;
  bool _gestureHadScrollActivity = false;
  bool _isSeeking = false;
  int? _seekOperationToken;
  bool _isReturningToPlayback = false;
  int? _returnOperationToken;
  double? _lastScrollPixels;
  int _scrollDirection = 1;
  int _operationToken = 0;
  List<LyricLine>? _lyricsDataIdentity;
  List<Duration> _lyricTimestamps = const [];
  List<String> _lyricTexts = const [];

  @override
  void initState() {
    super.initState();
    _captureLyricsSnapshot(widget.lyrics.value);
    _scheduleFollowCurrentLyric(animate: false);
  }

  @override
  void didUpdateWidget(covariant InteractiveLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIndexChanged = widget.currentIndex != oldWidget.currentIndex;
    final lyrics = widget.lyrics.value;
    final lyricsChanged = _lyricsHaveChanged(lyrics);
    _captureLyricsSnapshot(lyrics);

    if (lyricsChanged) {
      _resetForLyricsReplacement();
      if (lyrics?.isNotEmpty ?? false) {
        _scheduleFollowCurrentLyric(animate: false);
      }
    } else if (currentIndexChanged &&
        (lyrics?.isNotEmpty ?? false) &&
        !_isBrowsing &&
        !_isSeeking) {
      _scheduleFollowCurrentLyric(animate: true);
    }
  }

  @override
  void dispose() {
    _operationToken++;
    _isSeeking = false;
    _seekOperationToken = null;
    _isReturningToPlayback = false;
    _returnOperationToken = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _scrollController.dispose();
    super.dispose();
  }

  bool _lyricsHaveChanged(List<LyricLine>? lyrics) {
    if (!identical(lyrics, _lyricsDataIdentity)) return true;
    if (lyrics == null) return false;
    if (lyrics.length != _lyricTimestamps.length ||
        lyrics.length != _lyricTexts.length) {
      return true;
    }

    for (var index = 0; index < lyrics.length; index++) {
      if (lyrics[index].timestamp != _lyricTimestamps[index] ||
          lyrics[index].text != _lyricTexts[index]) {
        return true;
      }
    }
    return false;
  }

  void _captureLyricsSnapshot(List<LyricLine>? lyrics) {
    _lyricsDataIdentity = lyrics;
    _lyricTimestamps = lyrics == null
        ? const []
        : [for (final lyric in lyrics) lyric.timestamp];
    _lyricTexts = lyrics == null
        ? const []
        : [for (final lyric in lyrics) lyric.text];
  }

  void _resetForLyricsReplacement() {
    _operationToken++;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      _scrollController.jumpTo(_clampOffset(position, position.pixels));
    }

    _rowKeys.clear();
    _isBrowsing = false;
    _selectedIndex = null;
    _isProgrammaticScroll = false;
    _selectionUpdateScheduled = false;
    _gestureHadScrollActivity = false;
    _isSeeking = false;
    _seekOperationToken = null;
    _isReturningToPlayback = false;
    _returnOperationToken = null;
    _lastScrollPixels = null;
    _scrollDirection = 1;
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

  double _clampOffset(ScrollPosition position, double offset) {
    return offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  Duration _motionDuration(Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }

  bool get _canBrowse => (widget.lyrics.value?.length ?? 0) > 1;

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
      _scrollController.jumpTo(_clampOffset(position, estimatedOffset));
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
    final targetOffset = _clampOffset(
      position,
      viewport.getOffsetToReveal(row, 0.5).offset,
    );

    _isProgrammaticScroll = true;
    final animationDuration = _motionDuration(
      duration ?? widget.followDuration,
    );
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
    if (!_canBrowse) return;
    _inactivityTimer?.cancel();
    _isReturningToPlayback = false;
    _returnOperationToken = null;
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
      final lyrics = widget.lyrics.value;
      setState(() {
        _isBrowsing = true;
        if (lyrics != null &&
            widget.currentIndex >= 0 &&
            widget.currentIndex < lyrics.length) {
          _selectedIndex = widget.currentIndex;
        }
      });
    }
    _scheduleCenterSelection();
  }

  void _restartInactivityTimer() {
    if (!_isBrowsing || !_canBrowse) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      widget.inactivityDelay,
      () => unawaited(_returnToPlayback()),
    );
  }

  Future<void> _returnToPlayback() async {
    if (!_isBrowsing || !_canBrowse) return;

    final operationToken = ++_operationToken;
    _isReturningToPlayback = true;
    _returnOperationToken = operationToken;
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
        _clearReturnOwnership(operationToken);
        return;
      }
      if (widget.currentIndex != targetIndex) continue;

      setState(() {
        _isReturningToPlayback = false;
        _returnOperationToken = null;
        _isBrowsing = false;
        _selectedIndex = null;
      });
      return;
    }
    _clearReturnOwnership(operationToken);
  }

  void _clearReturnOwnership(int operationToken) {
    if (_returnOperationToken != operationToken) return;
    _isReturningToPlayback = false;
    _returnOperationToken = null;
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

    final rows = <VisibleLyricGeometry>[];
    for (var index = 0; index < _rowKeys.length; index++) {
      final row = _rowKeys[index].currentContext?.findRenderObject();
      if (row is! RenderBox || !row.attached) continue;

      final rowTop = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final rowBottom = rowTop + row.size.height;
      if (rowBottom < 0 || rowTop > viewport.size.height) continue;
      rows.add(
        VisibleLyricGeometry(
          index: index,
          center: rowTop + row.size.height / 2,
        ),
      );
    }

    final selectedIndex = findNearestLyricIndex(
      rows: rows,
      viewportCenter: viewport.size.height / 2,
      scrollDirection: _scrollDirection,
    );
    if (selectedIndex != null && selectedIndex != _selectedIndex) {
      setState(() => _selectedIndex = selectedIndex);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        _isSeeking) {
      return;
    }
    _beginBrowsing();
    _restartInactivityTimer();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isSeeking) return;
    _gestureHadScrollActivity = false;
    if (_isReturningToPlayback) _beginBrowsing();
  }

  void _handleLyricTap(int index) {
    if (_isSeeking) return;
    if (!_isBrowsing) _beginBrowsing();
    unawaited(_seekToIndex(index));
  }

  Future<void> _seekToIndex(int index) async {
    final lyrics = widget.lyrics.value;
    final isSingleLyric = lyrics?.length == 1;
    if (_isSeeking ||
        (!_isBrowsing && !isSingleLyric) ||
        lyrics == null ||
        index < 0 ||
        index >= lyrics.length) {
      return;
    }

    final operationToken = ++_operationToken;
    _inactivityTimer?.cancel();
    setState(() {
      _isReturningToPlayback = false;
      _returnOperationToken = null;
      _isSeeking = true;
      _seekOperationToken = operationToken;
      _selectedIndex = index;
    });

    try {
      await widget.onSeek(lyrics[index].timestamp);
    } catch (_) {
      if (!mounted ||
          !_ownsSeek(operationToken) ||
          operationToken != _operationToken) {
        return;
      }
      setState(() {
        _isSeeking = false;
        _seekOperationToken = null;
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('无法跳转播放位置，请重试')));
      _restartInactivityTimer();
      return;
    }

    if (!_isCurrentOperation(operationToken, allowBrowsing: true) ||
        (!isSingleLyric && !_isBrowsing)) {
      _releaseSeekOwnership(operationToken);
      return;
    }

    if (isSingleLyric) {
      _releaseSeekOwnership(operationToken);
      return;
    }

    _inactivityTimer?.cancel();
    final completed = await _followCurrentLyric(
      animate: true,
      operationToken: operationToken,
      allowBrowsing: true,
      duration: widget.seekDuration,
      targetIndex: index,
    );
    if (!completed ||
        !_isCurrentOperation(operationToken, allowBrowsing: true)) {
      _releaseSeekOwnership(operationToken);
      return;
    }

    if (!_ownsSeek(operationToken)) return;
    setState(() {
      _isSeeking = false;
      _seekOperationToken = null;
      _isBrowsing = false;
      _selectedIndex = null;
    });
  }

  bool _ownsSeek(int operationToken) {
    return mounted && _isSeeking && _seekOperationToken == operationToken;
  }

  void _releaseSeekOwnership(int operationToken) {
    if (!_ownsSeek(operationToken)) return;
    setState(() {
      _isSeeking = false;
      _seekOperationToken = null;
    });
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_isSeeking) return;
    final shouldStartInactivityTimer = !_gestureHadScrollActivity;
    _gestureHadScrollActivity = false;
    if (shouldStartInactivityTimer) _restartInactivityTimer();
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    if (_isSeeking) return;
    _gestureHadScrollActivity = false;
    if (_isReturningToPlayback) _beginBrowsing();
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (_isSeeking) return;
    _scheduleCenterSelection();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isSeeking || _isProgrammaticScroll) return false;

    if (notification is ScrollStartNotification) {
      _lastScrollPixels = notification.metrics.pixels;
    }

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      final previousPixels = _lastScrollPixels;
      final delta =
          notification.scrollDelta ??
          (previousPixels == null ? 0.0 : pixels - previousPixels);
      _lastScrollPixels = pixels;
      if (delta == 0) return false;

      _gestureHadScrollActivity = true;
      if (!_isBrowsing) _beginBrowsing();
      if (previousPixels != null && pixels != previousPixels) {
        _scrollDirection = pixels > previousPixels ? 1 : -1;
      } else {
        _scrollDirection = delta > 0 ? 1 : -1;
      }
      _updateCenterSelection();
    }

    if (notification case OverscrollNotification(
      :final overscroll,
    ) when overscroll != 0) {
      _gestureHadScrollActivity = true;
      if (!_isBrowsing) _beginBrowsing();
      _scrollDirection = overscroll > 0 ? 1 : -1;
      _updateCenterSelection();
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
            final selectedIndex = _selectedIndex;
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
                      physics: _isSeeking || lyrics.length <= 1
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      padding: EdgeInsets.symmetric(
                        horizontal: _horizontalContentGutter,
                        vertical: boundarySpace,
                      ),
                      itemCount: lyrics.length,
                      itemBuilder: (context, index) {
                        final lyric = lyrics[index];
                        final isCurrent = index == widget.currentIndex;
                        final isSelected =
                            _isBrowsing && _selectedIndex == index;

                        return KeyedSubtree(
                          key: ValueKey('lyric-row-$index'),
                          child: Semantics(
                            button: true,
                            label: '跳转播放：${lyric.text}',
                            onTap: _isSeeking
                                ? null
                                : () => _handleLyricTap(index),
                            child: ExcludeSemantics(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _isSeeking
                                    ? null
                                    : () => _handleLyricTap(index),
                                child: ConstrainedBox(
                                  key: _rowKeys[index],
                                  constraints: const BoxConstraints(
                                    minHeight: _minimumRowHeight,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        lyric.text,
                                        style: TextStyle(
                                          fontSize: isCurrent
                                              ? 18
                                              : isSelected
                                              ? 17
                                              : 15,
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isCurrent
                                              ? widget.foregroundColor
                                              : isSelected
                                              ? widget.foregroundColor
                                                    .withValues(alpha: 0.72)
                                              : widget.foregroundColor
                                                    .withValues(alpha: 0.4),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (lyrics.length > 1 &&
                    _isBrowsing &&
                    selectedIndex != null &&
                    selectedIndex >= 0 &&
                    selectedIndex < lyrics.length)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: boundarySpace - 22,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        IgnorePointer(
                          child: Divider(
                            indent: 52,
                            endIndent: 12,
                            height: 1,
                            thickness: 1,
                            color: widget.foregroundColor.withValues(
                              alpha: 0.14,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: '从此处播放：${lyrics[selectedIndex].text}',
                          onTap: _isSeeking
                              ? null
                              : () => unawaited(_seekToIndex(selectedIndex)),
                          child: ExcludeSemantics(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Tooltip(
                                message: '从此处播放',
                                child: IconButton(
                                  key: lyricsCenterPlayKey,
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  iconSize: 20,
                                  color: widget.foregroundColor,
                                  onPressed: _isSeeking
                                      ? null
                                      : () => unawaited(
                                          _seekToIndex(selectedIndex),
                                        ),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
