import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/core/theme/app_theme.dart';

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
    final fallbackDuration = trackDuration.inSeconds > 0 ? trackDuration : const Duration(seconds: 1);
    final duration = durationAsync.when(
      data: (v) => (v == null || v.inSeconds <= 1) ? fallbackDuration : v,
      loading: () => fallbackDuration,
      error: (_, __) => fallbackDuration,
    );

    // Auto-scroll to current lyric
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentLyricIdx >= 0 && _lyricsScrollController.hasClients) {
        final targetOffset = (currentLyricIdx * 48.0) - 100;
        if (targetOffset > 0) {
          _lyricsScrollController.animateTo(
            targetOffset,
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
              _buildHeader(),
              // Content
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    if (isWide) {
                      return _buildWideLayout(currentTrack, lyricsAsync, currentLyricIdx, audioService);
                    } else {
                      return _buildNarrowLayout(currentTrack, lyricsAsync, currentLyricIdx, audioService);
                    }
                  },
                ),
              ),
              // Progress bar
              _buildProgressBar(position, duration, audioService),
              const SizedBox(height: 16),
              // Controls
              _buildControls(isPlaying, audioService),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ),
            onPressed: _close,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_horiz, color: Colors.white),
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(currentTrack, lyricsAsync, int currentLyricIdx, audioService) {
    return Row(
      children: [
        // Left side: Cover + Info
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TrackCoverImage(
                track: currentTrack,
                size: 240,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(height: 24),
              _buildTrackInfo(currentTrack),
            ],
          ),
        ),
        // Right side: Lyrics
        Expanded(
          flex: 1,
          child: _buildLyricsList(lyricsAsync, currentLyricIdx, audioService),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(currentTrack, lyricsAsync, int currentLyricIdx, audioService) {
    return Column(
      children: [
        const SizedBox(height: 16),
        TrackCoverImage(
          track: currentTrack,
          size: 200,
          borderRadius: BorderRadius.circular(20),
        ),
        const SizedBox(height: 16),
        _buildTrackInfo(currentTrack),
        const SizedBox(height: 16),
        Expanded(
          child: _buildLyricsList(lyricsAsync, currentLyricIdx, audioService),
        ),
      ],
    );
  }

  Widget _buildTrackInfo(currentTrack) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            currentTrack?.title ?? '',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            currentTrack?.artist?.name ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsList(lyricsAsync, int currentLyricIdx, audioService) {
    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        return ListView.builder(
          controller: _lyricsScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (_, __) => Center(
        child: Text(
          '歌词加载失败',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Duration position, Duration duration, audioService) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          GestureDetector(
            onTapDown: (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                final width = renderBox.size.width - 64;
                final seekPosition = (details.localPosition.dx / width).clamp(0.0, 1.0);
                audioService.seek(
                  Duration(milliseconds: (duration.inMilliseconds * seekPosition).toInt()),
                );
              }
            },
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [LoginColors.accentPurple, LoginColors.accentPink],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isPlaying, audioService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(Icons.shuffle_rounded, 24, () {}),
        const SizedBox(width: 20),
        _buildControlButton(Icons.skip_previous_rounded, 32, () {}),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () {
            if (isPlaying) {
              audioService.pause();
            } else {
              audioService.play();
            }
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [LoginColors.accentPurple, LoginColors.accentPink],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: LoginColors.accentPurple.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 20),
        _buildControlButton(Icons.skip_next_rounded, 32, () {}),
        const SizedBox(width: 20),
        _buildControlButton(Icons.repeat_rounded, 24, () {}),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, double size, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.8),
          size: size,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
