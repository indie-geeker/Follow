# Lyrics Overlay Feature Design

## Overview

Two enhancements to the desktop music player:

1. **Show cover image in desktop player bar** - Replace placeholder icon with actual track cover
2. **Lyrics overlay on cover tap** - Slide-up panel covering right content area (sidebar remains visible)

## Requirements

- Cover image displays in desktop player bar (mark 2 in screenshot)
- Tapping cover opens lyrics overlay
- Overlay covers right content area (mark 3), sidebar stays visible
- Layout: cover art left, scrolling lyrics right (wide screens); stacked on narrow screens
- Full playback controls in overlay
- Dismiss via close button or swipe down

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `lib/shared/widgets/track_cover_image.dart` | Shared cover image widget |
| `lib/features/player/lyrics_overlay.dart` | Lyrics overlay panel |
| `lib/data/models/lyric_line.dart` | LyricLine model |
| `lib/data/services/lyrics_service.dart` | Fetch and parse LRC |
| `lib/data/providers/lyrics_provider.dart` | Riverpod provider for lyrics |

### Modified Files

| File | Changes |
|------|---------|
| `lib/router/app_router.dart` | Add overlay state, wrap content in Stack, use TrackCoverImage in _DesktopPlayerBar |
| `lib/shared/widgets/mini_player.dart` | Use shared TrackCoverImage |
| `lib/features/player/player_page.dart` | Use shared TrackCoverImage |

## Technical Design

### 1. TrackCoverImage Widget

```dart
// lib/shared/widgets/track_cover_image.dart
class TrackCoverImage extends StatelessWidget {
  final Track? track;
  final double size;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const TrackCoverImage({
    super.key,
    required this.track,
    required this.size,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (track?.coverUrl != null && track!.coverUrl!.isNotEmpty) {
      final url = track!.coverUrl!.startsWith('http')
          ? track!.coverUrl!
          : '${AppConfig.apiBaseUrl}/api/tracks/cover/${Uri.encodeComponent(track!.coverUrl!)}';
      image = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildPlaceholder(),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      image = _buildPlaceholder();
    }

    Widget result = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      child: image,
    );

    if (onTap != null) {
      result = GestureDetector(onTap: onTap, child: result);
    }

    return result;
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

### 2. Lyrics Overlay State

```dart
// Add to lib/data/providers/audio_provider.dart or new file
final lyricsOverlayVisibleProvider = StateProvider<bool>((ref) => false);
```

### 3. Desktop Shell Modification

```dart
// In _DesktopShell, wrap content area in Stack
Expanded(
  child: Stack(
    children: [
      Column(
        children: [
          Expanded(child: child),
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
            onClose: () => ref.read(lyricsOverlayVisibleProvider.notifier).state = false,
          );
        },
      ),
    ],
  ),
)
```

### 4. LyricsOverlay Layout

```
Wide screens (≥600px):
┌─────────────────────────────────────────────────────┐
│ [×]                                                 │
├───────────────────────┬─────────────────────────────┤
│   ┌───────────────┐   │   ♪ Line 1                  │
│   │  Cover 280px  │   │   ♪ Line 2 (current)        │
│   └───────────────┘   │   ♪ Line 3                  │
│   Title               │   ...                       │
│   Artist              │                             │
├───────────────────────┴─────────────────────────────┤
│  Progress bar + Controls                            │
└─────────────────────────────────────────────────────┘

Narrow screens (<600px):
┌─────────────────────┐
│ [×]                 │
├─────────────────────┤
│   ┌───────────┐     │
│   │  Cover    │     │
│   └───────────┘     │
│   Title / Artist    │
├─────────────────────┤
│   ♪ Line 1          │
│   ♪ Line 2 (curr)   │
│   ...               │
├─────────────────────┤
│  Progress + Ctrls   │
└─────────────────────┘
```

### 5. LyricLine Model

```dart
// lib/data/models/lyric_line.dart
class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({required this.timestamp, required this.text});
}
```

### 6. Lyrics Service

```dart
// lib/data/services/lyrics_service.dart
class LyricsService {
  final Dio _dio;

  LyricsService(this._dio);

  Future<List<LyricLine>> fetchLyrics(String lyricsUrl) async {
    final url = lyricsUrl.startsWith('http')
        ? lyricsUrl
        : '${AppConfig.apiBaseUrl}/api/tracks/lyrics/${Uri.encodeComponent(lyricsUrl)}';

    final response = await _dio.get(url);
    return parseLrc(response.data as String);
  }

  List<LyricLine> parseLrc(String lrcContent) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millis = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
            text: text,
          ));
        }
      }
    }

    return lines;
  }
}
```

### 7. Lyrics Provider

```dart
// lib/data/providers/lyrics_provider.dart
final lyricsServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return LyricsService(dio);
});

final currentTrackLyricsProvider = FutureProvider<List<LyricLine>>((ref) async {
  final track = ref.watch(currentTrackProvider);
  if (track?.lyricsUrl == null) return [];

  final service = ref.watch(lyricsServiceProvider);
  return service.fetchLyrics(track!.lyricsUrl!);
});

final currentLyricIndexProvider = Provider<int>((ref) {
  final lyrics = ref.watch(currentTrackLyricsProvider).valueOrNull ?? [];
  final position = ref.watch(playerPositionProvider).valueOrNull ?? Duration.zero;

  if (lyrics.isEmpty) return -1;

  for (int i = lyrics.length - 1; i >= 0; i--) {
    if (position >= lyrics[i].timestamp) return i;
  }
  return 0;
});
```

## Animation

LyricsOverlay uses `SlideTransition` to animate from bottom:

```dart
class LyricsOverlay extends StatefulWidget {
  // ...
}

class _LyricsOverlayState extends State<LyricsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

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

  void _close() {
    _controller.reverse().then((_) => widget.onClose());
  }
  // ...
}
```

## Implementation Order

1. Create `TrackCoverImage` widget
2. Update `_DesktopPlayerBar` to use `TrackCoverImage` with onTap
3. Add `lyricsOverlayVisibleProvider`
4. Create `LyricLine` model
5. Create `LyricsService` with LRC parsing
6. Create `currentTrackLyricsProvider` and `currentLyricIndexProvider`
7. Create `LyricsOverlay` widget
8. Integrate overlay into `_DesktopShell`
9. Refactor `MiniPlayer` and `PlayerPage` to use `TrackCoverImage`
