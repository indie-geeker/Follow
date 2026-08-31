import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';

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

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final List<GlobalKey> _rowKeys = [];

  Timer? _inactivityTimer;
  // Browse mode is intentionally activated by a later implementation task.
  // ignore: prefer_final_fields
  bool _isBrowsing = false;
  int? _selectedIndex;
  bool _isProgrammaticScroll = false;
  int _operationToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_followCurrentLyric(animate: false));
    });
  }

  @override
  void didUpdateWidget(covariant InteractiveLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && !_isBrowsing) {
      unawaited(_followCurrentLyric(animate: true));
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

  Future<void> _followCurrentLyric({required bool animate}) async {
    final operationToken = ++_operationToken;
    final lyrics = widget.lyrics.value;
    final index = widget.currentIndex;

    if (!mounted ||
        _isBrowsing ||
        lyrics == null ||
        index < 0 ||
        index >= lyrics.length ||
        !_scrollController.hasClients) {
      return;
    }

    _ensureRowKeys(lyrics.length);
    var row = _rowKeys[index].currentContext?.findRenderObject();
    if (row == null || !row.attached) {
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

      if (!mounted || operationToken != _operationToken) return;
      row = _rowKeys[index].currentContext?.findRenderObject();
    }

    if (row == null || !row.attached || operationToken != _operationToken) {
      _isProgrammaticScroll = false;
      return;
    }

    final viewport = RenderAbstractViewport.of(row);
    final position = _scrollController.position;
    final targetOffset = viewport
        .getOffsetToReveal(row, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    _isProgrammaticScroll = true;
    if (animate && widget.followDuration > Duration.zero) {
      await _scrollController.animateTo(
        targetOffset,
        duration: widget.followDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }

    if (_isProgrammaticScroll && mounted && operationToken == _operationToken) {
      _isProgrammaticScroll = false;
    }
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
                ListView.builder(
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
                    final isSelected = _isBrowsing && _selectedIndex == index;
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
