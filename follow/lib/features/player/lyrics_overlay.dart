import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/shared/widgets/player_progress_bar.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_track_info.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_controls.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';

class LyricsOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const LyricsOverlay({super.key, required this.onClose});

  @override
  ConsumerState<LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends ConsumerState<LyricsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  final ScrollController _lyricsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _close() {
    _controller.reverse().then((_) => widget.onClose());
  }

  // Get foreground color based on theme brightness
  Color _foregroundColor(BuildContext context, {double alpha = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black87;
    return alpha < 1.0 ? baseColor.withValues(alpha: alpha) : baseColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final currentLyricIdx = ref.watch(currentLyricIndexProvider);
    final playerMode = ref.watch(playerModeProvider);
    final volumeAsync = ref.watch(playerVolumeProvider);

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
    final trackDuration = Duration(seconds: currentTrack?.durationSeconds ?? 0);
    final fallbackDuration = trackDuration.inSeconds > 0
        ? trackDuration
        : const Duration(seconds: 1);
    final duration = durationAsync.when(
      data: (v) => (v == null || v.inSeconds <= 1) ? fallbackDuration : v,
      loading: () => fallbackDuration,
      error: (_, __) => fallbackDuration,
    );

    // Auto-scroll to current lyric
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentLyricIdx >= 0 && _lyricsScrollController.hasClients) {
        final targetOffset = (currentLyricIdx * 48.0) - 100;
        final maxScroll = _lyricsScrollController.position.maxScrollExtent;
        // Only scroll if there's content to scroll and target is within bounds
        if (targetOffset > 0 && maxScroll > 0) {
          final clampedOffset = targetOffset.clamp(0.0, maxScroll);
          _lyricsScrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
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
              // Header
              _buildHeader(context),
              // Content
              // Content with floating volume control
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (layoutContext, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          if (isWide) {
                            return _buildWideLayout(
                              context,
                              currentTrack,
                              lyricsAsync,
                              currentLyricIdx,
                              audioService,
                            );
                          } else {
                            return _buildNarrowLayout(
                              context,
                              currentTrack,
                              lyricsAsync,
                              currentLyricIdx,
                              audioService,
                            );
                          }
                        },
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 16,
                      child: _HoverVolumeControl(
                        volumeAsync: volumeAsync,
                        audioService: audioService,
                        foregroundColor: _foregroundColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar
              PlayerProgressBar(
                position: position,
                duration: duration,
                onSeek: audioService.seek,
              ),
              const SizedBox(height: 16),
              // Controls
              LyricsControls(
                isPlaying: isPlaying,
                playMode: playerMode,
                onPlayPause: () {
                  if (isPlaying) {
                    audioService.pause();
                  } else {
                    audioService.play();
                  }
                },
                onPrevious: () => audioService.playPrevious(),
                onNext: () => audioService.playNext(),
                onModeToggle: () =>
                    ref.read(playerModeProvider.notifier).nextMode(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
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
            onPressed: _close,
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _foregroundColor(context, alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.more_horiz, color: _foregroundColor(context)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              // TODO: Implement actions
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('下载'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('分享'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    Track? currentTrack,
    AsyncValue<List<LyricLine>> lyricsAsync,
    int currentLyricIdx,
    AudioPlayerService audioService,
  ) {
    return Row(
      children: [
        // Left side: Cover + Info
        Expanded(
          flex: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate available height for the image
              // Reserve space for info (~80px) and spacing (24px)
              final maxImageSize = (constraints.maxHeight - 110).clamp(
                100.0,
                240.0,
              );

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TrackCoverImage(
                    track: currentTrack,
                    size: maxImageSize,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  const SizedBox(height: 24),
                  LyricsTrackInfo(track: currentTrack),
                ],
              );
            },
          ),
        ),
        // Right side: Lyrics
        Expanded(
          flex: 1,
          child: _buildLyricsList(
            context,
            lyricsAsync,
            currentLyricIdx,
            audioService,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    Track? currentTrack,
    AsyncValue<List<LyricLine>> lyricsAsync,
    int currentLyricIdx,
    AudioPlayerService audioService,
  ) {
    return Column(
      children: [
        const SizedBox(height: 16),
        TrackCoverImage(
          track: currentTrack,
          size: 200,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 16),
        LyricsTrackInfo(track: currentTrack),
        const SizedBox(height: 16),
        Expanded(
          child: _buildLyricsList(
            context,
            lyricsAsync,
            currentLyricIdx,
            audioService,
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsList(
    BuildContext context,
    AsyncValue<List<LyricLine>> lyricsAsync,
    int currentLyricIdx,
    AudioPlayerService audioService,
  ) {
    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: TextStyle(
                fontSize: 16,
                color: _foregroundColor(context, alpha: 0.5),
              ),
            ),
          );
        }
        // Add bottom padding so last lyrics can scroll to center
        final viewportHeight = MediaQuery.of(context).size.height * 0.4;
        return ListView.builder(
          controller: _lyricsScrollController,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: viewportHeight,
          ),
          itemCount: lyrics.length,
          itemBuilder: (context, index) {
            final lyric = lyrics[index];
            final isCurrent = index == currentLyricIdx;
            return GestureDetector(
              onTap: () => audioService.seek(lyric.timestamp),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: Text(
                  lyric.text,
                  style: TextStyle(
                    fontSize: isCurrent ? 18 : 15,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? _foregroundColor(context)
                        : _foregroundColor(context, alpha: 0.4),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: _foregroundColor(context)),
      ),
      error: (_, __) => LyricsFailureView(
        foregroundColor: _foregroundColor(context, alpha: 0.5),
      ),
    );
  }
}

class _HoverVolumeControl extends StatefulWidget {
  final AsyncValue<double> volumeAsync;
  final AudioPlayerService audioService;
  final Color foregroundColor;

  const _HoverVolumeControl({
    required this.volumeAsync,
    required this.audioService,
    required this.foregroundColor,
  });

  @override
  State<_HoverVolumeControl> createState() => _HoverVolumeControlState();
}

class _HoverVolumeControlState extends State<_HoverVolumeControl> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsible Slider Container
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: _isHovering ? 120 : 0,
            width: 40,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: widget.foregroundColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: 104,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: widget.foregroundColor.withValues(
                        alpha: 0.9,
                      ),
                      inactiveTrackColor: widget.foregroundColor.withValues(
                        alpha: 0.2,
                      ),
                      thumbColor: widget.foregroundColor,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: widget.volumeAsync.value ?? 1.0,
                      onChanged: (value) =>
                          widget.audioService.setVolume(value),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Volume Icon
          Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              (_isHovering || (widget.volumeAsync.value ?? 0) > 0)
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: widget.foregroundColor.withValues(
                alpha: _isHovering ? 1.0 : 0.7,
              ),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
