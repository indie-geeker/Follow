import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'playback, downloads and lyrics use the centralized same-origin routes',
    () {
      final api = File(
        'lib/data/services/api/api_service.dart',
      ).readAsStringSync();
      final downloads = File(
        'lib/data/providers/download_provider.dart',
      ).readAsStringSync();
      final lyrics = File(
        'lib/data/services/lyrics_service.dart',
      ).readAsStringSync();

      expect(api, contains('resolveTrackStreamUri('));
      expect(downloads, contains('resolveTrackStreamUri('));
      expect(lyrics, contains('resolveTrackLyricsUri('));

      expect(downloads, isNot(contains("'/api/tracks/\${track.id}/stream'")));
      expect(lyrics, isNot(contains("'/api/tracks/\$trackId/lyrics'")));
    },
  );
}
