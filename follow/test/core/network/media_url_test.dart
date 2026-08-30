import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/network/media_url.dart';

void main() {
  group('resolveCoverUri', () {
    const apiBaseUrl = 'https://music.home';

    test('rejects absolute and protocol-relative cover URLs', () {
      expect(
        resolveCoverUri(
          'https://cdn.example.com/covers/album.jpg',
          apiBaseUrl: apiBaseUrl,
        ),
        isNull,
      );
      expect(
        resolveCoverUri(
          '//cdn.example.com/covers/album.jpg',
          apiBaseUrl: apiBaseUrl,
        ),
        isNull,
      );
    });

    test('routes storage keys through the cover endpoint', () {
      expect(
        resolveCoverUri(
          'covers/artist id/专辑/cover.jpg',
          apiBaseUrl: apiBaseUrl,
        ).toString(),
        '$apiBaseUrl/api/tracks/cover/'
        'covers/artist%20id/%E4%B8%93%E8%BE%91/cover.jpg',
      );
    });

    test('rejects traversal, root paths and non-cover object prefixes', () {
      for (final value in [
        '../tracks/private.mp3',
        'covers/../tracks/private.mp3',
        '/api/tracks/cover/example.jpg',
        r'covers\..\tracks\private.mp3',
        'tracks/private.mp3',
        'lyrics/private.lrc',
      ]) {
        expect(
          resolveCoverUri(value, apiBaseUrl: apiBaseUrl),
          isNull,
          reason: value,
        );
      }
    });

    test('returns null for absent cover values', () {
      expect(resolveCoverUri(null, apiBaseUrl: apiBaseUrl), isNull);
      expect(resolveCoverUri('   ', apiBaseUrl: apiBaseUrl), isNull);
    });

    test('rejects schemes that network image consumers cannot load', () {
      expect(
        resolveCoverUri('file:///private/cover.jpg', apiBaseUrl: apiBaseUrl),
        isNull,
      );
      expect(
        resolveCoverUri('data:image/png;base64,AA==', apiBaseUrl: apiBaseUrl),
        isNull,
      );
      expect(resolveCoverUri('http:cover.jpg', apiBaseUrl: apiBaseUrl), isNull);
      expect(
        resolveCoverUri('https:///cover.jpg', apiBaseUrl: apiBaseUrl),
        isNull,
      );
    });
  });

  group('authenticated track media URIs', () {
    const apiBaseUrl = 'https://music.home';

    test('builds same-origin stream and lyrics endpoints', () {
      expect(
        resolveTrackStreamUri('track id', apiBaseUrl: apiBaseUrl).toString(),
        '$apiBaseUrl/api/tracks/track%20id/stream',
      );
      expect(
        resolveTrackLyricsUri('track id', apiBaseUrl: apiBaseUrl).toString(),
        '$apiBaseUrl/api/tracks/track%20id/lyrics',
      );
    });

    test('rejects path traversal and URL-shaped track ids', () {
      for (final id in [
        '..',
        '../track',
        'folder/track',
        r'folder\track',
        'https://evil.example/track',
      ]) {
        expect(
          () => resolveTrackStreamUri(id, apiBaseUrl: apiBaseUrl),
          throwsFormatException,
          reason: id,
        );
      }
    });
  });
}
