import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/utils/duration_utils.dart';
import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';
import 'package:follow/shared/widgets/player/folded_track_queue.dart';
import 'package:follow/shared/widgets/player/player_cover_art.dart';
import 'package:follow/shared/widgets/player/player_main_controls.dart';
import 'package:follow/shared/widgets/player/player_volume_control.dart';
import 'package:follow/shared/widgets/player/playlist_gallery_drawer.dart';

const playerPlaylistPullHandleKey = ValueKey('player-playlist-pull-handle');
const playerPlaylistGalleryKey = ValueKey('player-playlist-gallery');
const playerLyricsSurfaceKey = ValueKey('player-lyrics-surface');
const playerQueueSurfaceKey = ValueKey('player-queue-surface');

enum _PlayerVisualMode { record, lyrics }

@RoutePage()
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  static const _playlistOpenThreshold = 88.0;

  _PlayerVisualMode _visualMode = _PlayerVisualMode.record;
  double _playlistPullDistance = 0;
  double _lyricsHorizontalDrag = 0;
  Offset _recordVisualOffset = Offset.zero;
  double _queueRevealProgress = 0;
  bool _playlistGalleryOpen = false;
  bool _playlistDragActive = false;
  bool _queueOpen = false;
  bool _recordGestureActive = false;
  bool _lyricsGestureActive = false;
  bool _trackGestureBusy = false;

  bool get _hasTransientLayer =>
      _playlistGalleryOpen ||
      _queueOpen ||
      _visualMode != _PlayerVisualMode.record;

  Color _foregroundColor(BuildContext context, {double alpha = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    return alpha < 1.0 ? baseColor.withValues(alpha: alpha) : baseColor;
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1a1a2e) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuItem(context, Icons.favorite_border_rounded, '收藏'),
                _buildMenuItem(context, Icons.playlist_add_rounded, '添加到播放列表'),
                _buildMenuItem(context, Icons.download_outlined, '下载'),
                _buildMenuItem(context, Icons.share_outlined, '分享'),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRecord() {
    setState(() {
      _visualMode = _PlayerVisualMode.record;
      _queueOpen = false;
      _queueRevealProgress = 0;
      _recordVisualOffset = Offset.zero;
      _lyricsHorizontalDrag = 0;
    });
  }

  void _showQueue(double revealDistance) {
    setState(() {
      _playlistGalleryOpen = false;
      _playlistPullDistance = 0;
      _visualMode = _PlayerVisualMode.record;
      _queueOpen = true;
      _queueRevealProgress = 1;
      _recordVisualOffset = Offset(revealDistance, 0);
    });
  }

  void _showLyrics(double pageWidth) {
    setState(() {
      _playlistGalleryOpen = false;
      _playlistPullDistance = 0;
      _queueOpen = false;
      _queueRevealProgress = 0;
      _visualMode = _PlayerVisualMode.lyrics;
      _recordVisualOffset = Offset(-pageWidth, 0);
      _lyricsHorizontalDrag = 0;
    });
  }

  void _closeQueue() {
    setState(() {
      _queueOpen = false;
      _queueRevealProgress = 0;
      _recordVisualOffset = Offset.zero;
    });
  }

  void _settleTrackGesture(double revealDistance) {
    setState(() {
      _recordVisualOffset = Offset(_queueOpen ? revealDistance : 0, 0);
      _queueRevealProgress = _queueOpen ? 1 : 0;
    });
  }

  void _handleRecordVisualOffset(
    Offset offset, {
    required double pageWidth,
    required double revealDistance,
  }) {
    if (_visualMode == _PlayerVisualMode.lyrics) return;
    setState(() {
      if (offset.dy != 0) {
        _recordVisualOffset = Offset(
          _queueOpen ? revealDistance : 0,
          offset.dy,
        );
        _queueRevealProgress = _queueOpen ? 1 : 0;
        return;
      }

      if (_queueOpen || offset.dx >= 0) {
        final x = offset.dx.clamp(0.0, revealDistance);
        _recordVisualOffset = Offset(x, 0);
        _queueRevealProgress = revealDistance == 0
            ? 0
            : (x / revealDistance).clamp(0.0, 1.0);
        return;
      }

      _recordVisualOffset = Offset(offset.dx.clamp(-pageWidth, 0.0), 0);
      _queueRevealProgress = 0;
    });
  }

  Future<void> _runTrackGesture(Future<void> Function() action) async {
    if (_trackGestureBusy) return;
    setState(() => _trackGestureBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _trackGestureBusy = false);
    }
  }

  void _handlePlaylistPullStart() {
    setState(() => _playlistDragActive = true);
  }

  void _handlePlaylistPullUpdate(
    DragUpdateDetails details,
    double galleryHeight,
  ) {
    setState(() {
      _playlistPullDistance = (_playlistPullDistance + details.delta.dy).clamp(
        0.0,
        galleryHeight,
      );
    });
  }

  void _handlePlaylistPullEnd(DragEndDetails details, double galleryHeight) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldOpen = velocity <= -700
        ? false
        : _playlistPullDistance >= _playlistOpenThreshold || velocity >= 700;
    setState(() {
      _playlistGalleryOpen = shouldOpen;
      _playlistDragActive = false;
      _playlistPullDistance = shouldOpen ? galleryHeight : 0;
      if (shouldOpen) _visualMode = _PlayerVisualMode.record;
    });
    if (shouldOpen) HapticFeedback.selectionClick();
  }

  void _cancelPlaylistPull(double galleryHeight) {
    setState(() {
      _playlistDragActive = false;
      _playlistPullDistance = _playlistGalleryOpen ? galleryHeight : 0;
    });
  }

  void _closeTopLayer() {
    if (_playlistGalleryOpen) {
      setState(() {
        _playlistGalleryOpen = false;
        _playlistPullDistance = 0;
      });
      return;
    }
    if (_queueOpen) {
      _closeQueue();
      return;
    }
    if (_visualMode != _PlayerVisualMode.record) _showRecord();
  }

  Future<void> _selectPlaylist(
    String playlistId,
    AudioPlayerService audioService,
  ) async {
    try {
      final playlist = await ref.read(
        playlistDetailProvider(playlistId).future,
      );
      if (playlist.tracks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('歌单暂无歌曲')));
        }
        return;
      }
      await audioService.playPlaylist(playlistId, playlist.tracks);
      if (mounted) {
        setState(() {
          _playlistGalleryOpen = false;
          _playlistPullDistance = 0;
          _visualMode = _PlayerVisualMode.record;
          _queueOpen = false;
          _queueRevealProgress = 0;
          _recordVisualOffset = Offset.zero;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('歌单加载失败，请重试')));
      }
    }
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: _foregroundColor(context, alpha: 0.8)),
      title: Text(
        label,
        style: TextStyle(fontSize: 16, color: _foregroundColor(context)),
      ),
      onTap: () {
        Navigator.pop(context);
        // TODO: Implement actions
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compactHeight = MediaQuery.sizeOf(context).height < 600;
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);

    // Lyrics providers
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final currentLyricIdx = ref.watch(currentLyricIndexProvider);
    final queue = ref.watch(playQueueProvider);
    final playlists = ref.watch(playlistsProvider);
    final currentPlaylistId = ref.watch(currentPlaylistIdProvider);

    if (currentTrack == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => context.router.maybePop(),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [LoginColors.gradientEnd, LoginColors.gradientStart]
                  : [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.surface,
                    ],
            ),
          ),
          child: Center(
            child: Text(
              '暂无播放',
              style: TextStyle(color: _foregroundColor(context, alpha: 0.7)),
            ),
          ),
        ),
      );
    }

    final isPlaying = isPlayingAsync.when(
      data: (v) => v,
      loading: () => false,
      error: (_, __) => false,
    );
    final position = positionAsync.when(
      data: (v) => v ?? Duration.zero,
      loading: () => Duration.zero,
      error: (_, __) => Duration.zero,
    );
    // Use track's durationSeconds as fallback when player duration is not ready
    final trackDuration = Duration(seconds: currentTrack.durationSeconds);
    final fallbackDuration = trackDuration.inSeconds > 0
        ? trackDuration
        : const Duration(seconds: 1);
    final duration = durationAsync.when(
      data: (v) {
        if (v == null || v.inSeconds <= 1) {
          return fallbackDuration;
        }
        return v;
      },
      loading: () => fallbackDuration,
      error: (_, __) => fallbackDuration,
    );

    final galleryHeight =
        MediaQuery.sizeOf(context).height * (compactHeight ? 0.9 : 0.42);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final playerScaffold = Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _foregroundColor(context, alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: _foregroundColor(context),
            ),
          ),
          onPressed: () => context.router.maybePop(),
        ),
        title: _visualMode == _PlayerVisualMode.lyrics
            ? Text(
                currentTrack.title,
                style: TextStyle(
                  color: _foregroundColor(context),
                  fontSize: 16,
                ),
              )
            : null,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _foregroundColor(context, alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.more_horiz, color: _foregroundColor(context)),
            ),
            onPressed: () => _showMoreMenu(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    LoginColors.gradientEnd,
                    LoginColors.gradientMid2,
                    LoginColors.gradientMid1,
                    LoginColors.gradientStart,
                  ]
                : [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.surface,
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Stable visual region shared by record, lyrics and folded queue.
              Expanded(
                child: Column(
                  children: [
                    _buildPlaylistPullHandle(
                      compact: compactHeight,
                      galleryHeight: galleryHeight,
                    ),
                    Expanded(
                      child: _buildVisualSurface(
                        currentTrack: currentTrack,
                        queue: queue,
                        lyricsAsync: lyricsAsync,
                        currentLyricIdx: currentLyricIdx,
                        audioService: audioService,
                        recordSize: compactHeight ? 150 : 280,
                        isPlaying: isPlaying,
                      ),
                    ),
                    SizedBox(
                      height: compactHeight ? 64 : 104,
                      child: _visualMode == _PlayerVisualMode.lyrics
                          ? const SizedBox.shrink()
                          : _buildTrackInfo(
                              currentTrack,
                              isDark,
                              compact: compactHeight,
                            ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: compactHeight ? 4 : 12),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Standard Slider
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: isDark
                            ? LoginColors.accentPink
                            : theme.colorScheme.primary,
                        inactiveTrackColor: _foregroundColor(
                          context,
                          alpha: 0.2,
                        ),
                        thumbColor: isDark
                            ? Colors.white
                            : theme.colorScheme.primary,
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(
                          0,
                          duration.inMilliseconds.toDouble(),
                        ),
                        min: 0,
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          audioService.seek(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(position),
                            style: TextStyle(
                              fontSize: 12,
                              color: _foregroundColor(context, alpha: 0.6),
                            ),
                          ),
                          Text(
                            formatDuration(duration),
                            style: TextStyle(
                              fontSize: 12,
                              color: _foregroundColor(context, alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (!compactHeight)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: PlayerVolumeControl(),
                ),

              SizedBox(height: compactHeight ? 4 : 12),

              // Main controls
              PlayerMainControls(
                isPlaying: isPlaying,
                onPlayPause: () {
                  if (isPlaying) {
                    audioService.pause();
                  } else {
                    audioService.play();
                  }
                },
                onPrevious: () => audioService.playPrevious(),
                onNext: () => audioService.playNext(),
                onShowQueue: () =>
                    _showQueue((compactHeight ? 150.0 : 280.0) * 0.52),
              ),

              SizedBox(height: compactHeight ? 12 : 48),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_hasTransientLayer,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasTransientLayer) _closeTopLayer();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            key: playerPlaylistGalleryKey,
            top: 0,
            left: 0,
            right: 0,
            height: galleryHeight,
            child: IgnorePointer(
              ignoring: !_playlistGalleryOpen,
              child: ExcludeSemantics(
                excluding: !_playlistGalleryOpen,
                child: PlaylistGalleryDrawer(
                  playlists: playlists,
                  currentPlaylistId: currentPlaylistId,
                  onSelect: (playlist) =>
                      _selectPlaylist(playlist.id, audioService),
                  onClose: () {
                    setState(() {
                      _playlistGalleryOpen = false;
                      _playlistPullDistance = 0;
                    });
                  },
                  onRetry: () => ref.invalidate(playlistsProvider),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: reduceMotion || _playlistDragActive
                ? Duration.zero
                : const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _playlistPullDistance, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _playlistGalleryOpen ? _closeTopLayer : null,
              child: playerScaffold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistPullHandle({
    required bool compact,
    required double galleryHeight,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final progress = (_playlistPullDistance / galleryHeight).clamp(0.0, 1.0);
    return GestureDetector(
      key: playerPlaylistPullHandleKey,
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _handlePlaylistPullStart(),
      onVerticalDragUpdate: (details) =>
          _handlePlaylistPullUpdate(details, galleryHeight),
      onVerticalDragEnd: (details) =>
          _handlePlaylistPullEnd(details, galleryHeight),
      onVerticalDragCancel: () => _cancelPlaylistPull(galleryHeight),
      child: SizedBox(
        height: compact ? 32 : 38,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              width: 42 + progress * 14,
              height: 4,
              decoration: BoxDecoration(
                color: _foregroundColor(context, alpha: 0.24 + progress * 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _playlistGalleryOpen ? '上推收起歌单' : '下拉切换歌单',
              style: TextStyle(
                fontSize: 11,
                color: _foregroundColor(context, alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualSurface({
    required Track currentTrack,
    required List<Track> queue,
    required AsyncValue<List<LyricLine>> lyricsAsync,
    required int currentLyricIdx,
    required AudioPlayerService audioService,
    required double recordSize,
    required bool isPlaying,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final revealDistance = recordSize * 0.52;
        final maxVerticalVisualOffset = math.min(
          48.0,
          math.max(0.0, (constraints.maxHeight - recordSize) / 2 - 16),
        );
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final transitionDuration =
            reduceMotion || _recordGestureActive || _lyricsGestureActive
            ? Duration.zero
            : const Duration(milliseconds: 260);
        final lyricsOffset = pageWidth + _recordVisualOffset.dx;

        return Stack(
          key: playerQueueSurfaceKey,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 18,
              top: math.max(0, (constraints.maxHeight - recordSize) / 2),
              width: math.min(196, pageWidth * 0.52),
              height: math.min(recordSize, constraints.maxHeight),
              child: FoldedTrackQueue(
                tracks: queue,
                currentTrackId: currentTrack.id,
                revealProgress: _queueRevealProgress,
                onSelect: (index) => audioService.playQueueItemAt(index),
              ),
            ),
            AnimatedContainer(
              duration: transitionDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                _recordVisualOffset.dx,
                _recordVisualOffset.dy,
                0,
              ),
              child: Center(
                child: IgnorePointer(
                  ignoring: _visualMode == _PlayerVisualMode.lyrics,
                  child: PlayerCoverArt(
                    track: currentTrack,
                    size: recordSize,
                    maxVerticalVisualOffset: maxVerticalVisualOffset,
                    isPlaying: isPlaying,
                    isBusy: _trackGestureBusy,
                    applyVisualOffset: false,
                    restingOffset: Offset(_queueOpen ? revealDistance : 0, 0),
                    onDragStateChanged: (active) {
                      if (mounted) {
                        setState(() => _recordGestureActive = active);
                      }
                    },
                    onVisualOffsetChanged: (offset) =>
                        _handleRecordVisualOffset(
                          offset,
                          pageWidth: pageWidth,
                          revealDistance: revealDistance,
                        ),
                    onSwipeUp: () {
                      _settleTrackGesture(revealDistance);
                      _runTrackGesture(audioService.playNext);
                    },
                    onSwipeDown: () {
                      _settleTrackGesture(revealDistance);
                      _runTrackGesture(audioService.playPrevious);
                    },
                    onSwipeLeft: () {
                      if (_queueOpen) {
                        _closeQueue();
                      } else {
                        _showLyrics(pageWidth);
                      }
                    },
                    onSwipeRight: () => _showQueue(revealDistance),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: transitionDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(lyricsOffset, 0, 0),
              child: IgnorePointer(
                ignoring: _visualMode != _PlayerVisualMode.lyrics,
                child: ExcludeSemantics(
                  excluding: _visualMode != _PlayerVisualMode.lyrics,
                  child: _buildLyricsSurface(
                    pageWidth: pageWidth,
                    trackId: currentTrack.id,
                    lyricsAsync: lyricsAsync,
                    currentLyricIdx: currentLyricIdx,
                    audioService: audioService,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLyricsSurface({
    required double pageWidth,
    required String trackId,
    required AsyncValue<List<LyricLine>> lyricsAsync,
    required int currentLyricIdx,
    required AudioPlayerService audioService,
  }) {
    return GestureDetector(
      key: playerLyricsSurfaceKey,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        setState(() {
          _lyricsHorizontalDrag = 0;
          _lyricsGestureActive = true;
        });
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _lyricsHorizontalDrag = (_lyricsHorizontalDrag + details.delta.dx)
              .clamp(0.0, pageWidth);
          _recordVisualOffset = Offset(-pageWidth + _lyricsHorizontalDrag, 0);
        });
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        final shouldReturn = _lyricsHorizontalDrag >= 56 || velocity >= 700;
        setState(() => _lyricsGestureActive = false);
        if (shouldReturn) {
          _showRecord();
        } else {
          setState(() {
            _recordVisualOffset = Offset(-pageWidth, 0);
            _lyricsHorizontalDrag = 0;
          });
        }
      },
      onHorizontalDragCancel: () {
        setState(() {
          _lyricsGestureActive = false;
          _recordVisualOffset = Offset(-pageWidth, 0);
          _lyricsHorizontalDrag = 0;
        });
      },
      child: _buildLyricsPage(
        trackId: trackId,
        lyricsAsync: lyricsAsync,
        currentLyricIdx: currentLyricIdx,
        audioService: audioService,
      ),
    );
  }

  Widget _buildTrackInfo(
    Track currentTrack,
    bool isDark, {
    required bool compact,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            currentTrack.title,
            style: TextStyle(
              fontSize: compact ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: _foregroundColor(context),
              shadows: isDark
                  ? const [Shadow(color: Colors.black26, blurRadius: 10)]
                  : const [],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? 2 : 8),
          Text(
            currentTrack.artist?.name ?? '未知艺术家',
            style: TextStyle(
              fontSize: compact ? 13 : 16,
              color: _foregroundColor(context, alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPage({
    required String trackId,
    required AsyncValue<List<LyricLine>> lyricsAsync,
    required int currentLyricIdx,
    required AudioPlayerService audioService,
  }) {
    return InteractiveLyricsView(
      key: ValueKey('mobile-lyrics-$trackId'),
      lyrics: lyricsAsync,
      currentIndex: currentLyricIdx,
      foregroundColor: _foregroundColor(context),
      onSeek: audioService.seek,
    );
  }
}
