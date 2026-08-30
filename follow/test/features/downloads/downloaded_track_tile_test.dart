import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/features/downloads/downloads_page.dart';

void main() {
  testWidgets('downloaded track tile plays from its row', (tester) async {
    var playCalls = 0;
    const track = Track(
      id: 'track-1',
      title: 'Offline song',
      artist: Artist(id: 'artist-1', name: 'Artist'),
      isDownloaded: true,
      localPath: '/app/music/track-1.mp3',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadedTrackTile(
            track: track,
            isDark: false,
            showRevealAction: false,
            onPlay: () async {
              playCalls++;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.folder_open_rounded), findsNothing);
    await tester.tap(find.text('Offline song'));
    await tester.pump();

    expect(playCalls, 1);
  });
}
