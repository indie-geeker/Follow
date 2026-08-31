import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile PlayerPage delegates lyrics to InteractiveLyricsView', () {
    final source = File(
      'lib/features/player/player_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        "import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';",
      ),
    );
    expect(source, contains('InteractiveLyricsView('));
    expect(source, contains("ValueKey('mobile-lyrics-\$trackId')"));
    expect(source, contains('trackId: currentTrack.id'));
    expect(source, contains('lyrics: lyricsAsync'));
    expect(source, contains('currentIndex: currentLyricIdx'));
    expect(source, contains('foregroundColor: _foregroundColor(context)'));
    expect(source, contains('onSeek: audioService.seek'));

    expect(source, isNot(contains('_lyricsScrollController')));
    expect(source, isNot(contains('currentLyricIdx * 48.0')));
    expect(
      source,
      isNot(contains('WidgetsBinding.instance.addPostFrameCallback')),
    );
    expect(source, isNot(contains('ShaderMask(')));
    expect(source, isNot(contains('ListView.builder(')));
    expect(source, isNot(contains('LyricsFailureView')));
  });
}
