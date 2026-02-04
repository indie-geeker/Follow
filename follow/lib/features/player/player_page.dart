import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/utils/duration_utils.dart';
import 'package:follow/shared/widgets/player/player_cover_art.dart';
import 'package:follow/shared/widgets/player/player_main_controls.dart';
import 'package:follow/shared/widgets/player/page_indicator_dot.dart';

@RoutePage()
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  final PageController _pageController = PageController();
  final ScrollController _lyricsScrollController = ScrollController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

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

  Widget _buildMenuItem(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: _foregroundColor(context, alpha: 0.8)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: _foregroundColor(context),
        ),
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
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);
    
    // Lyrics providers
    final lyricsAsync = ref.watch(currentTrackLyricsProvider);
    final currentLyricIdx = ref.watch(currentLyricIndexProvider);

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
                  : [theme.colorScheme.primaryContainer, theme.colorScheme.surface],
            ),
          ),
          child: Center(
            child: Text('暂无播放', 
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

    // Auto-scroll lyrics logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPage == 1 && currentLyricIdx >= 0 && _lyricsScrollController.hasClients) {
        final targetOffset = (currentLyricIdx * 48.0) - MediaQuery.of(context).size.height * 0.2;
        final maxScroll = _lyricsScrollController.position.maxScrollExtent;
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

    return Scaffold(
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
        title: _currentPage == 1 
            ? Text(
                currentTrack.title,
                style: TextStyle(color: _foregroundColor(context), fontSize: 16),
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
              child: Icon(
                Icons.more_horiz,
                color: _foregroundColor(context),
              ),
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
              const Spacer(flex: 1),

              // PageView for Cover and Lyrics
              SizedBox(
                height: MediaQuery.of(context).size.width - 40, // Square-ish area
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    // Page 0: Cover Art
                    Center(child: PlayerCoverArt(track: currentTrack)),
                    // Page 1: Lyrics
                    _buildLyricsPage(lyricsAsync, currentLyricIdx, audioService),
                  ],
                ),
              ),
              
              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PageIndicatorDot(isActive: _currentPage == 0),
                  const SizedBox(width: 8),
                  PageIndicatorDot(isActive: _currentPage == 1),
                ],
              ),

              const Spacer(flex: 1),

              // Track info
              if (_currentPage == 0) ...[
                 Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        currentTrack.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _foregroundColor(context),
                          shadows: isDark ? const [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 10,
                            ),
                          ] : [],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentTrack.artist?.name ?? '未知艺术家',
                        style: TextStyle(
                          fontSize: 16,
                          color: _foregroundColor(context, alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                 const SizedBox(height: 60), 
              ],

              const SizedBox(height: 20),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Standard Slider
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        activeTrackColor: isDark ? LoginColors.accentPink : theme.colorScheme.primary, 
                        inactiveTrackColor: _foregroundColor(context, alpha: 0.2),
                        thumbColor: isDark ? Colors.white : theme.colorScheme.primary,
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
                          audioService.seek(Duration(milliseconds: value.toInt()));
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

              const SizedBox(height: 24),

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
                onShuffle: () {},
                onRepeat: () {},
              ),

              const Spacer(flex: 2),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsPage(AsyncValue<List<LyricLine>> lyricsAsync, int currentLyricIdx, dynamic audioService) {
    return lyricsAsync.when(
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: TextStyle(
                fontSize: 16,
                color: _foregroundColor(context, alpha: 0.6),
              ),
            ),
          );
        }
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.1, 0.9, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _lyricsScrollController,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final lyric = lyrics[index];
              final isCurrent = index == currentLyricIdx;
              return GestureDetector(
                onTap: () => audioService.seek(lyric.timestamp),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    lyric.text,
                    style: TextStyle(
                      fontSize: isCurrent ? 20 : 16,
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
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: _foregroundColor(context)),
      ),
      error: (_, __) => Center(
        child: Text(
          '歌词加载失败',
          style: TextStyle(
            fontSize: 16,
            color: _foregroundColor(context, alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
