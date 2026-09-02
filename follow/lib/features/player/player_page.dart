import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/core/theme/player_palette_provider.dart';
import 'package:follow/core/utils/duration_utils.dart';
import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';
import 'package:follow/shared/widgets/play_queue_sheet.dart';
import 'package:follow/shared/widgets/player/folded_track_queue.dart';
import 'package:follow/shared/widgets/player/player_cover_art.dart';
import 'package:follow/shared/widgets/player/player_aurora_background.dart';
import 'package:follow/shared/widgets/player/player_main_controls.dart';
import 'package:follow/shared/widgets/player/player_volume_control.dart';
import 'package:follow/shared/widgets/player/playlist_gallery_drawer.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';
import 'package:follow/shared/widgets/surfaces/aurora_background.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';
import 'package:follow/router/app_router.dart';

const playerPlaylistPullHandleKey = ValueKey('player-playlist-pull-handle');
const playerPlaylistGalleryKey = ValueKey('player-playlist-gallery');
const playerPlaylistGalleryOpacityKey = ValueKey(
  'player-playlist-gallery-opacity',
);
const playerPlaylistGalleryPointerKey = ValueKey(
  'player-playlist-gallery-pointer',
);
const playerPlaylistGallerySemanticsKey = ValueKey(
  'player-playlist-gallery-semantics',
);
const playerPlaylistGuidanceOpacityKey = ValueKey(
  'player-playlist-guidance-opacity',
);
const playerTopChromeSurfaceKey = ValueKey('player-top-chrome-surface');
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
  static const _foldedQueueIdleDuration = Duration(seconds: 2);

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
  bool _foldedQueueInteractionActive = false;
  Timer? _foldedQueueAutoCloseTimer;

  bool get _hasTransientLayer =>
      _playlistGalleryOpen ||
      _queueOpen ||
      _visualMode != _PlayerVisualMode.record;

  Color _foregroundColor(BuildContext context, {double alpha = 1.0}) {
    final baseColor = context.followTokens.textPrimary;
    return alpha < 1.0 ? baseColor.withValues(alpha: alpha) : baseColor;
  }

  @override
  void dispose() {
    _foldedQueueAutoCloseTimer?.cancel();
    super.dispose();
  }

  void _cancelFoldedQueueAutoClose() {
    _foldedQueueAutoCloseTimer?.cancel();
    _foldedQueueAutoCloseTimer = null;
  }

  void _scheduleFoldedQueueAutoClose() {
    _cancelFoldedQueueAutoClose();
    if (!_queueOpen || _foldedQueueInteractionActive) return;
    _foldedQueueAutoCloseTimer = Timer(_foldedQueueIdleDuration, () {
      if (!mounted || !_queueOpen || _foldedQueueInteractionActive) return;
      _closeQueue();
    });
  }

  void _handleFoldedQueueInteractionStart() {
    _foldedQueueInteractionActive = true;
    _cancelFoldedQueueAutoClose();
  }

  void _handleFoldedQueueInteractionSettled() {
    _foldedQueueInteractionActive = false;
  }

  void _handleFoldedQueueScrollSettled() {
    _foldedQueueInteractionActive = false;
    _scheduleFoldedQueueAutoClose();
  }

  void _dismissFoldedQueueForExternalInteraction() {
    if (_queueOpen || _queueRevealProgress > 0) _closeQueue();
  }

  bool _consumeRecordInteractionIfQueueOpen() {
    if (!_queueOpen && _queueRevealProgress <= 0) return false;
    _closeQueue();
    return true;
  }

  void _showMoreMenu(BuildContext context) {
    _dismissFoldedQueueForExternalInteraction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.followTokens.surface,
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
    _cancelFoldedQueueAutoClose();
    _foldedQueueInteractionActive = false;
    setState(() {
      _queueOpen = false;
      _queueRevealProgress = 0;
      _recordVisualOffset = Offset.zero;
    });
  }

  void _showPlayQueue(BuildContext context, PlayerPalette palette) {
    _dismissFoldedQueueForExternalInteraction();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayQueueSheet(palette: palette),
    );
  }

  void _handleRecordVisualOffset(
    Offset offset, {
    required double pageWidth,
    required double revealDistance,
  }) {
    if (_visualMode == _PlayerVisualMode.lyrics) return;
    setState(() {
      if (offset.dy != 0) {
        _recordVisualOffset = Offset(_queueOpen ? revealDistance : 0, 0);
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
    _dismissFoldedQueueForExternalInteraction();
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
      if (shouldOpen) {
        _visualMode = _PlayerVisualMode.record;
        _queueOpen = false;
        _queueRevealProgress = 0;
        _recordVisualOffset = Offset.zero;
        _lyricsHorizontalDrag = 0;
      }
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
    final currentIndex = ref.watch(currentIndexProvider);
    final playerMode = ref.watch(playerModeProvider);
    final shuffledIndices = ref.watch(shuffledIndicesProvider);
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
        body: AuroraBackground(
          child: AppStateView(
            kind: AppStateKind.nothingPlaying,
            title: '暂无播放',
            description: '从音乐库选择一首歌，开启沉浸式播放。',
            actionLabel: '打开音乐库',
            onAction: () => context.router.root.navigate(
              const MainShellRoute(children: [LibraryRoute()]),
            ),
          ),
        ),
      );
    }

    final tokens = context.followTokens;
    final paletteRequest = PlayerPaletteRequest.fromTrack(
      currentTrack,
      theme.brightness,
    );
    final palette =
        ref.watch(playerPaletteProvider(paletteRequest)).value ??
        PlayerPalette.fallback(brightness: theme.brightness, tokens: tokens);

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
    final displayedQueueIndex = queue.indexWhere(
      (track) => track.id == currentTrack.id,
    );
    final previewQueueIndex = displayedQueueIndex >= 0
        ? displayedQueueIndex
        : currentIndex;
    final previousIndex = resolveAdjacentQueueIndex(
      queueLength: queue.length,
      currentIndex: previewQueueIndex,
      mode: playerMode,
      shuffledIndices: shuffledIndices,
      delta: -1,
    );
    final nextIndex = resolveAdjacentQueueIndex(
      queueLength: queue.length,
      currentIndex: previewQueueIndex,
      mode: playerMode,
      shuffledIndices: shuffledIndices,
      delta: 1,
    );
    Track? queueTrackAt(int? index) {
      if (index == null || index < 0 || index >= queue.length) return null;
      return queue[index];
    }

    final previousTrack = queueTrackAt(previousIndex);
    final nextTrack = queueTrackAt(nextIndex);

    final galleryHeight =
        MediaQuery.sizeOf(context).height * (compactHeight ? 0.9 : 0.42);
    final playlistRevealProgress = (_playlistPullDistance / galleryHeight)
        .clamp(0.0, 1.0);
    final topChromeAlpha = 0.22 * (1 - playlistRevealProgress);
    final topChromeBlur = 18.0 * (1 - playlistRevealProgress);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final playerScaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter.grouped(
            key: ValueKey('player-top-chrome'),
            filter: ImageFilter.blur(
              sigmaX: topChromeBlur,
              sigmaY: topChromeBlur,
            ),
            child: ColoredBox(
              key: playerTopChromeSurfaceKey,
              color: palette.scrim.withValues(alpha: topChromeAlpha),
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: _foregroundColor(context),
          ),
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(
          _visualMode == _PlayerVisualMode.lyrics ? currentTrack.title : '',
          style: TextStyle(color: _foregroundColor(context), fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: _foregroundColor(context)),
            onPressed: () => _showMoreMenu(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PlayerAuroraBackground(
        track: currentTrack,
        palette: palette,
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
                        previousTrack: previousTrack,
                        nextTrack: nextTrack,
                        queue: queue,
                        lyricsAsync: lyricsAsync,
                        currentLyricIdx: currentLyricIdx,
                        position: position,
                        audioService: audioService,
                        recordSize: compactHeight ? 150 : 280,
                        isPlaying: isPlaying,
                        palette: palette,
                      ),
                    ),
                    SizedBox(
                      key: const ValueKey('player-track-info-slot'),
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
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compactHeight ? 12 : 20,
                  compactHeight ? 4 : 8,
                  compactHeight ? 12 : 20,
                  compactHeight ? 8 : 20,
                ),
                child: GlassPanel(
                  key: const ValueKey('player-control-deck'),
                  tier: GlassTier.standard,
                  padding: EdgeInsets.symmetric(
                    horizontal: compactHeight ? 8 : 12,
                    vertical: compactHeight ? 4 : 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                          activeTrackColor: palette.progress,
                          inactiveTrackColor: _foregroundColor(
                            context,
                            alpha: 0.2,
                          ),
                          thumbColor: palette.progress,
                          overlayColor: palette.progress.withValues(
                            alpha: 0.14,
                          ),
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
                      if (!compactHeight)
                        PlayerVolumeControl(
                          palette: palette,
                          onInteractionStart:
                              _dismissFoldedQueueForExternalInteraction,
                        ),
                      SizedBox(height: compactHeight ? 2 : 6),
                      Listener(
                        onPointerDown: (_) =>
                            _dismissFoldedQueueForExternalInteraction(),
                        child: PlayerMainControls(
                          palette: palette,
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
                          onShowQueue: () => _showPlayQueue(context, palette),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      child: BackdropGroup(
        key: const ValueKey('player-backdrop-group'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              key: playerPlaylistGalleryKey,
              top: 0,
              left: 0,
              right: 0,
              height: galleryHeight,
              child: Opacity(
                key: playerPlaylistGalleryOpacityKey,
                opacity: playlistRevealProgress,
                child: IgnorePointer(
                  key: playerPlaylistGalleryPointerKey,
                  ignoring: !_playlistGalleryOpen,
                  child: ExcludeSemantics(
                    key: playerPlaylistGallerySemanticsKey,
                    excluding: !_playlistGalleryOpen,
                    child: PlaylistGalleryDrawer(
                      palette: palette,
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
                child: Listener(
                  onPointerDown: (_) {
                    if (!_foldedQueueInteractionActive) {
                      _dismissFoldedQueueForExternalInteraction();
                    }
                  },
                  child: playerScaffold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistPullHandle({
    required bool compact,
    required double galleryHeight,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final progress = (_playlistPullDistance / galleryHeight).clamp(0.0, 1.0);
    final guidanceProgress = (_playlistPullDistance / _playlistOpenThreshold)
        .clamp(0.0, 1.0);
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
        child: Opacity(
          key: playerPlaylistGuidanceOpacityKey,
          opacity: guidanceProgress,
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
                  color: _foregroundColor(
                    context,
                    alpha: 0.24 + progress * 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _playlistGalleryOpen
                    ? '上推收起歌单'
                    : _playlistPullDistance >= _playlistOpenThreshold
                    ? '释放打开歌单'
                    : '下拉切换歌单',
                style: TextStyle(
                  fontSize: 11,
                  color: _foregroundColor(context, alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualSurface({
    required Track currentTrack,
    required Track? previousTrack,
    required Track? nextTrack,
    required List<Track> queue,
    required AsyncValue<List<LyricLine>> lyricsAsync,
    required int currentLyricIdx,
    required Duration position,
    required AudioPlayerService audioService,
    required double recordSize,
    required bool isPlaying,
    required PlayerPalette palette,
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
              child: Opacity(
                opacity: _queueRevealProgress.clamp(0.0, 1.0),
                child: FoldedTrackQueue(
                  palette: palette,
                  tracks: queue,
                  currentTrackId: currentTrack.id,
                  revealProgress: _queueRevealProgress,
                  onSelect: (index) => audioService.playQueueItemAt(index),
                  onInteractionStart: _handleFoldedQueueInteractionStart,
                  onInteractionSettled: _handleFoldedQueueInteractionSettled,
                  onScrollSettled: _handleFoldedQueueScrollSettled,
                ),
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
                    palette: palette,
                    track: currentTrack,
                    previousTrack: previousTrack,
                    nextTrack: nextTrack,
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
                    onInteractionAttempt: _consumeRecordInteractionIfQueueOpen,
                    onTap: () {
                      if (isPlaying) {
                        audioService.pause();
                      } else {
                        audioService.play();
                      }
                    },
                    onVisualOffsetChanged: (offset) =>
                        _handleRecordVisualOffset(
                          offset,
                          pageWidth: pageWidth,
                          revealDistance: revealDistance,
                        ),
                    onSwipeUp: () {
                      _closeQueue();
                      _runTrackGesture(audioService.playNext);
                    },
                    onSwipeDown: () {
                      _closeQueue();
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
                    palette: palette,
                    pageWidth: pageWidth,
                    trackId: currentTrack.id,
                    lyricsAsync: lyricsAsync,
                    currentLyricIdx: currentLyricIdx,
                    position: position,
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
    required PlayerPalette palette,
    required double pageWidth,
    required String trackId,
    required AsyncValue<List<LyricLine>> lyricsAsync,
    required int currentLyricIdx,
    required Duration position,
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
        position: position,
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
    required Duration position,
    required AudioPlayerService audioService,
  }) {
    return InteractiveLyricsView(
      key: ValueKey('mobile-lyrics-$trackId'),
      lyrics: lyricsAsync,
      currentIndex: currentLyricIdx,
      playbackPosition: position,
      foregroundColor: _foregroundColor(context),
      onSeek: audioService.seek,
    );
  }
}
