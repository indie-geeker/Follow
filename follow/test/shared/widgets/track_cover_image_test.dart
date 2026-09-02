import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/network/cover_image_provider.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

void main() {
  test('shared cover helper accepts only normalized same-origin artwork', () {
    const valid = Track(
      id: 'track-1',
      title: 'Song',
      coverUrl: 'covers/album.jpg',
    );
    const invalid = Track(
      id: 'track-2',
      title: 'Unsafe',
      coverUrl: 'https://untrusted.test/cover.jpg',
    );

    final provider = coverImageProviderForTrack(valid);

    expect(provider, isA<CachedNetworkImageProvider>());
    expect(
      (provider! as CachedNetworkImageProvider).url,
      contains('/api/tracks/cover/covers/album.jpg'),
    );
    expect(coverImageProviderForTrack(invalid), isNull);
    expect(coverImageProviderForTrack(null), isNull);
  });

  testWidgets('visible cover consumes the shared image provider', (
    tester,
  ) async {
    const track = Track(
      id: 'track-1',
      title: 'Song',
      coverUrl: 'covers/album.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(home: TrackCoverImage(track: track, size: 96)),
    );

    final image = tester.widget<Image>(find.byKey(trackCoverNetworkImageKey));
    expect(image.image, coverImageProviderForTrack(track));
  });

  testWidgets('missing artwork stays inside the reserved cover geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: TrackCoverImage(track: null, size: 96)),
      ),
    );

    expect(find.byKey(trackCoverPlaceholderKey), findsOneWidget);
    expect(tester.getSize(find.byType(TrackCoverImage)), const Size(96, 96));
  });
}
