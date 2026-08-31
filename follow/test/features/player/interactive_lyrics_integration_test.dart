import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/features/player/player_page.dart';
import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';

const _firstTrack = Track(
  id: 'track-1',
  title: 'First track',
  durationSeconds: 180,
  artist: Artist(id: 'artist-1', name: 'Artist'),
);

const _secondTrack = Track(
  id: 'track-2',
  title: 'Second track',
  durationSeconds: 180,
  artist: Artist(id: 'artist-1', name: 'Artist'),
);

final _lyrics = List.generate(
  12,
  (index) => LyricLine(
    timestamp: Duration(seconds: index * 5),
    text: 'Player lyric $index',
  ),
);

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {}

Future<ProviderContainer> _pumpPlayerPage(
  WidgetTester tester, {
  required AsyncValue<List<LyricLine>> lyrics,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      audioPlayerServiceProvider.overrideWithValue(_FakeAudioPlayerService()),
      isPlayingProvider.overrideWithValue(const AsyncData(false)),
      playerPositionProvider.overrideWithValue(
        const AsyncData(Duration(seconds: 10)),
      ),
      playerDurationProvider.overrideWithValue(
        const AsyncData(Duration(seconds: 180)),
      ),
      playerVolumeProvider.overrideWithValue(const AsyncData(0.65)),
      currentTrackLyricsProvider.overrideWithValue(lyrics),
      currentLyricIndexProvider.overrideWithValue(2),
    ],
  );
  addTearDown(container.dispose);
  container.read(currentTrackProvider.notifier).setTrack(_firstTrack);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayerPage()),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _showLyricsPage(WidgetTester tester) async {
  final pageView = find.byType(PageView);
  await tester.fling(pageView, const Offset(-360, 0), 1200);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(tester.widget<PageView>(pageView).controller!.page, closeTo(1, 0.01));
}

void main() {
  test('mobile player uses the shared interactive lyrics view', () {
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

    expect(source, isNot(contains('_lyricsScrollController')));
    expect(source, isNot(contains('currentLyricIdx * 48.0')));
    expect(
      source,
      isNot(contains('WidgetsBinding.instance.addPostFrameCallback')),
    );
  });

  testWidgets(
    'mobile PlayerPage arbitrates horizontal paging and vertical lyric browsing',
    (tester) async {
      await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

      await _showLyricsPage(tester);
      expect(find.byKey(lyricsCenterPlayKey), findsNothing);

      final horizontalGesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await horizontalGesture.moveBy(const Offset(300, 0));
      await tester.pump();
      expect(
        find.byKey(lyricsCenterPlayKey, skipOffstage: false),
        findsNothing,
      );
      await horizontalGesture.up();
      await tester.pump(const Duration(seconds: 1));

      final pageController = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      pageController.jumpToPage(1);
      await tester.pump();
      final verticalGesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await verticalGesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await verticalGesture.moveBy(const Offset(0, -90));
      await tester.pump();
      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
      await verticalGesture.up();
    },
  );

  testWidgets('mobile PlayerPage resets lyric browsing when track changes', (
    tester,
  ) async {
    final container = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await _showLyricsPage(tester);

    final verticalGesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await verticalGesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await verticalGesture.moveBy(const Offset(0, -90));
    await tester.pump();
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    await verticalGesture.up();
    expect(find.byKey(const ValueKey('mobile-lyrics-track-1')), findsOneWidget);

    container.read(currentTrackProvider.notifier).setTrack(_secondTrack);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    expect(find.byKey(const ValueKey('mobile-lyrics-track-2')), findsOneWidget);
  });

  testWidgets('mobile PlayerPage renders the shared lyrics loading state', (
    tester,
  ) async {
    await _pumpPlayerPage(
      tester,
      lyrics: const AsyncLoading<List<LyricLine>>(),
    );
    await _showLyricsPage(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('mobile PlayerPage renders the shared empty lyrics state', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: const AsyncData(<LyricLine>[]));
    await _showLyricsPage(tester);

    expect(find.text('暂无歌词'), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('mobile PlayerPage renders the shared lyrics error state', (
    tester,
  ) async {
    await _pumpPlayerPage(
      tester,
      lyrics: AsyncError<List<LyricLine>>(
        StateError('failed'),
        StackTrace.empty,
      ),
    );
    await _showLyricsPage(tester);

    expect(find.byType(LyricsFailureView), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });
}
