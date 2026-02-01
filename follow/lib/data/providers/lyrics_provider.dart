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
  if (track == null || track.lyricsUrl == null || track.lyricsUrl!.isEmpty) {
    return [];
  }

  final service = ref.watch(lyricsServiceProvider);
  return service.fetchLyrics(track.id);
}

/// Current lyric index based on playback position
@riverpod
int currentLyricIndex(ref) {
  final lyricsAsync = ref.watch(currentTrackLyricsProvider);
  final positionAsync = ref.watch(playerPositionProvider);

  final lyrics = lyricsAsync.value ?? [];
  final position = positionAsync.value ?? Duration.zero;

  if (lyrics.isEmpty) return -1;

  // Find the last lyric whose timestamp is <= current position
  for (int i = lyrics.length - 1; i >= 0; i--) {
    if (position >= lyrics[i].timestamp) {
      return i;
    }
  }
  return 0;
}
