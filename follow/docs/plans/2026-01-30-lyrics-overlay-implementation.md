# Lyrics Overlay Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add cover image to desktop player bar and lyrics overlay that slides up when tapped.

**Architecture:** Shared TrackCoverImage widget, LyricsService for LRC parsing, LyricsOverlay as animated Stack child in DesktopShell.

**Tech Stack:** Flutter, Riverpod, CachedNetworkImage, Dio

---

### Task 1: Create TrackCoverImage Widget

**Files:**
- Create: `lib/shared/widgets/track_cover_image.dart`

**Step 1: Create the widget file**

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/config/app_config.dart';

class TrackCoverImage extends StatelessWidget {
  final Track? track;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final VoidCallback? onTap;

  const TrackCoverImage({
    super.key,
    required this.track,
    required this.size,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = _buildImage();

    Widget result = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      child: image,
    );

    if (onTap != null) {
      result = GestureDetector(onTap: onTap, child: result);
    }

    return result;
  }

  Widget _buildImage() {
    if (track?.coverUrl != null && track!.coverUrl!.isNotEmpty) {
      final url = track!.coverUrl!.startsWith('http')
          ? track!.coverUrl!
          : '${AppConfig.apiBaseUrl}/api/tracks/cover/${Uri.encodeComponent(track!.coverUrl!)}';
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: fit,
        placeholder: (_, __) => _buildPlaceholder(),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[300],
      child: Icon(Icons.music_note, size: size * 0.5, color: Colors.grey[500]),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/shared/widgets/track_cover_image.dart
git commit -m "feat: add TrackCoverImage shared widget"
```

---

### Task 2: Create LyricLine Model

**Files:**
- Create: `lib/data/models/lyric_line.dart`

**Step 1: Create the model file**

```dart
class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => 'LyricLine(${timestamp.inSeconds}s: $text)';
}
```

**Step 2: Commit**

```bash
git add lib/data/models/lyric_line.dart
git commit -m "feat: add LyricLine model"
```

---

### Task 3: Create LyricsService

**Files:**
- Create: `lib/data/services/lyrics_service.dart`

**Step 1: Create the service file**

```dart
import 'package:dio/dio.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/core/config/app_config.dart';

class LyricsService {
  final Dio _dio;

  LyricsService() : _dio = ApiClient.instance;

  Future<List<LyricLine>> fetchLyrics(String lyricsUrl) async {
    try {
      final url = lyricsUrl.startsWith('http')
          ? lyricsUrl
          : '${AppConfig.apiBaseUrl}/api/tracks/lyrics/${Uri.encodeComponent(lyricsUrl)}';

      final response = await _dio.get(url);
      final content = response.data is String ? response.data : response.data.toString();
      return parseLrc(content);
    } catch (e) {
      return [];
    }
  }

  List<LyricLine> parseLrc(String lrcContent) {
    final lines = <LyricLine>[];
    // Match [mm:ss.xx] or [mm:ss.xxx] format
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3)!;
        final millis = int.parse(millisStr.padRight(3, '0'));
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
          ));
        }
      }
    }

    // Sort by timestamp
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
```

**Step 2: Commit**

```bash
git add lib/data/services/lyrics_service.dart
git commit -m "feat: add LyricsService with LRC parsing"
```

---

### Task 4: Create Lyrics Providers

**Files:**
- Create: `lib/data/providers/lyrics_provider.dart`

**Step 1: Create the provider file**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/services/lyrics_service.dart';
import 'package:follow/data/providers/audio_provider.dart';

part 'lyrics_provider.g.dart';

/// Lyrics overlay visibility state
@riverpod
class LyricsOverlayVisible extends _$LyricsOverlayVisible {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
  void toggle() => state = !state;
}

/// Lyrics service provider
@riverpod
LyricsService lyricsService(ref) {
  return LyricsService();
}

/// Current track lyrics provider
@riverpod
Future<List<LyricLine>> currentTrackLyrics(ref) async {
  final track = ref.watch(currentTrackProvider);
  if (track?.lyricsUrl == null || track!.lyricsUrl!.isEmpty) {
    return [];
  }

  final service = ref.watch(lyricsServiceProvider);
  return service.fetchLyrics(track.lyricsUrl!);
}

/// Current lyric index based on playback position
@riverpod
int currentLyricIndex(ref) {
  final lyricsAsync = ref.watch(currentTrackLyricsProvider);
  final positionAsync = ref.watch(playerPositionProvider);

  final lyrics = lyricsAsync.valueOrNull ?? [];
  final position = positionAsync.valueOrNull ?? Duration.zero;

  if (lyrics.isEmpty) return -1;

  // Find the last lyric whose timestamp is <= current position
  for (int i = lyrics.length - 1; i >= 0; i--) {
    if (position >= lyrics[i].timestamp) {
      return i;
    }
  }
  return 0;
}
```

**Step 2: Run build_runner to generate code**

Run: `flutter pub run build_runner build --delete-conflicting-outputs`

**Step 3: Commit**

```bash
git add lib/data/providers/lyrics_provider.dart lib/data/providers/lyrics_provider.g.dart
git commit -m "feat: add lyrics providers"
```

---

### Task 5: Create LyricsOverlay Widget

**Files:**
- Create: `lib/features/player/lyrics_overlay.dart`

**Step 1: Create the overlay widget file**

```dart
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

    final isPlaying = isPlayingAsync.valueOrNull ?? false;
    final position = positionAsync.valueOrNull ?? Duration.zero;
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
```

**Step 2: Commit**

```bash
git add lib/features/player/lyrics_overlay.dart
git commit -m "feat: add LyricsOverlay widget"
```

---

### Task 6: Update _DesktopPlayerBar to Show Cover and Open Overlay

**Files:**
- Modify: `lib/router/app_router.dart`

**Step 1: Add imports at top of file (after line 7)**

Add after existing imports:
```dart
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/features/player/lyrics_overlay.dart';
```

**Step 2: Replace cover placeholder in _DesktopPlayerBar (lines 302-313)**

Find this code in `_DesktopPlayerBar`:
```dart
                  // Cover
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
```

Replace with:
```dart
                  // Cover - tap to open lyrics overlay
                  Consumer(
                    builder: (context, ref, _) {
                      return TrackCoverImage(
                        track: currentTrack,
                        size: 56,
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          ref.read(lyricsOverlayVisibleProvider.notifier).show();
                        },
                      );
                    },
                  ),
```

**Step 3: Wrap content area with Stack in _DesktopShell (around lines 236-245)**

Find this code in `_DesktopShell`:
```dart
              // Main content
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: child),
                    // Bottom player bar for desktop
                    if (currentTrack != null)
                      _DesktopPlayerBar(currentTrack: currentTrack),
                  ],
                ),
              ),
```

Replace with:
```dart
              // Main content
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(child: child),
                        // Bottom player bar for desktop
                        if (currentTrack != null)
                          _DesktopPlayerBar(currentTrack: currentTrack),
                      ],
                    ),
                    // Lyrics overlay
                    Consumer(
                      builder: (context, ref, _) {
                        final showOverlay = ref.watch(lyricsOverlayVisibleProvider);
                        if (!showOverlay) return const SizedBox.shrink();
                        return LyricsOverlay(
                          onClose: () {
                            ref.read(lyricsOverlayVisibleProvider.notifier).hide();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
```

**Step 4: Commit**

```bash
git add lib/router/app_router.dart
git commit -m "feat: integrate TrackCoverImage and LyricsOverlay in desktop shell"
```

---

### Task 7: Refactor MiniPlayer to Use TrackCoverImage

**Files:**
- Modify: `lib/shared/widgets/mini_player.dart`

**Step 1: Add import (after line 6)**

Add:
```dart
import 'package:follow/shared/widgets/track_cover_image.dart';
```

**Step 2: Replace _buildCover call (line 88)**

Find:
```dart
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildCover(currentTrack, 48),
                    ),
```

Replace with:
```dart
                    TrackCoverImage(
                      track: currentTrack,
                      size: 48,
                      borderRadius: BorderRadius.circular(6),
                    ),
```

**Step 3: Remove unused methods (lines 130-154)**

Delete these methods:
- `_buildCover`
- `_buildPlaceholder`

**Step 4: Commit**

```bash
git add lib/shared/widgets/mini_player.dart
git commit -m "refactor: use TrackCoverImage in MiniPlayer"
```

---

### Task 8: Refactor PlayerPage to Use TrackCoverImage

**Files:**
- Modify: `lib/features/player/player_page.dart`

**Step 1: Add import (after line 6)**

Add:
```dart
import 'package:follow/shared/widgets/track_cover_image.dart';
```

**Step 2: Replace _buildCoverImage in _buildCoverArt (line 249)**

Find in `_buildCoverArt`:
```dart
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildCoverImage(track),
      ),
```

Replace with:
```dart
      child: TrackCoverImage(
        track: track,
        size: 280,
        borderRadius: BorderRadius.circular(24),
      ),
```

**Step 3: Remove unused methods (lines 254-287)**

Delete these methods:
- `_buildCoverImage`
- `_buildPlaceholder`

**Step 4: Commit**

```bash
git add lib/features/player/player_page.dart
git commit -m "refactor: use TrackCoverImage in PlayerPage"
```

---

### Task 9: Run Build Runner and Verify

**Step 1: Run build_runner**

Run: `cd /Users/wen/Desktop/Personal/Projects/Follow/follow && flutter pub run build_runner build --delete-conflicting-outputs`

**Step 2: Check for compile errors**

Run: `flutter analyze`

**Step 3: Run the app**

Run: `flutter run -d macos`

**Step 4: Final commit if any generated files changed**

```bash
git add -A
git status
# If there are changes:
git commit -m "chore: regenerate riverpod providers"
```

---

## Verification Checklist

- [ ] Desktop player bar shows track cover image instead of placeholder
- [ ] Tapping cover image opens lyrics overlay with slide-up animation
- [ ] Overlay covers right content area, sidebar remains visible
- [ ] Wide screens: cover left, lyrics right (side by side)
- [ ] Narrow screens: cover top, lyrics below (stacked)
- [ ] Lyrics scroll and highlight current line
- [ ] Tapping a lyric line seeks to that timestamp
- [ ] Close button dismisses overlay with slide-down animation
- [ ] Playback controls work in overlay
