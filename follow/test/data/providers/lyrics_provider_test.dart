import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';

const _lyrics = [
  LyricLine(timestamp: Duration(seconds: 5), text: 'first'),
  LyricLine(timestamp: Duration(seconds: 10), text: 'duplicate-first'),
  LyricLine(timestamp: Duration(seconds: 10), text: 'duplicate-second'),
  LyricLine(timestamp: Duration(seconds: 10), text: 'duplicate-third'),
  LyricLine(timestamp: Duration(seconds: 20), text: 'later-first'),
  LyricLine(timestamp: Duration(seconds: 20), text: 'later-second'),
];

int _currentIndexAt(Duration position) {
  final container = ProviderContainer(
    overrides: [
      currentTrackLyricsProvider.overrideWithValue(const AsyncData(_lyrics)),
      playerPositionProvider.overrideWithValue(AsyncData(position)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(currentLyricIndexProvider);
}

void main() {
  test('uses the first lyric in the active duplicate timestamp group', () {
    expect(_currentIndexAt(const Duration(seconds: 10)), 1);
    expect(_currentIndexAt(const Duration(seconds: 15)), 1);
    expect(_currentIndexAt(const Duration(seconds: 20)), 4);
    expect(_currentIndexAt(const Duration(seconds: 25)), 4);
  });

  test('uses the first lyric before the first timestamp', () {
    expect(_currentIndexAt(const Duration(seconds: 2)), 0);
  });
}
