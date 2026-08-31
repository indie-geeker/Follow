import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/features/player/lyrics_overlay.dart';
import 'package:follow/features/player/player_page.dart';
import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';

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

class _FakeAudioPlayerService extends Fake implements AudioPlayerService {
  final seekCalls = <Duration>[];

  @override
  Future<void> seek(Duration position) async => seekCalls.add(position);
}

class _FakeIsFavorite extends IsFavorite {
  @override
  Future<bool> build(String? trackId) async => false;
}

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
      isFavoriteProvider.overrideWith(_FakeIsFavorite.new),
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

Future<({ProviderContainer container, _FakeAudioPlayerService audioService})>
_pumpLyricsOverlay(
  WidgetTester tester, {
  required AsyncValue<List<LyricLine>> lyrics,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 800);
  addTearDown(tester.view.reset);

  final audioService = _FakeAudioPlayerService();
  final container = ProviderContainer(
    overrides: [
      audioPlayerServiceProvider.overrideWithValue(audioService),
      isPlayingProvider.overrideWithValue(const AsyncData(false)),
      playerPositionProvider.overrideWithValue(
        const AsyncData(Duration(seconds: 10)),
      ),
      playerDurationProvider.overrideWithValue(
        const AsyncData(Duration(seconds: 180)),
      ),
      playerVolumeProvider.overrideWithValue(const AsyncData(0.65)),
      isFavoriteProvider.overrideWith(_FakeIsFavorite.new),
      currentTrackLyricsProvider.overrideWithValue(lyrics),
      currentLyricIndexProvider.overrideWithValue(2),
    ],
  );
  addTearDown(container.dispose);
  container.read(currentTrackProvider.notifier).setTrack(_firstTrack);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: LyricsOverlay(onClose: () {})),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  return (container: container, audioService: audioService);
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

  test('desktop overlay uses the shared interactive lyrics view', () {
    final source = File(
      'lib/features/player/lyrics_overlay.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        "import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';",
      ),
    );
    expect(source, contains('InteractiveLyricsView('));
    expect(source, contains("ValueKey('desktop-lyrics-\$trackId')"));

    expect(source, isNot(contains('_lyricsScrollController')));
    expect(source, isNot(contains('currentLyricIdx * 48.0')));
    expect(
      source,
      isNot(contains('WidgetsBinding.instance.addPostFrameCallback')),
    );
  });

  testWidgets('desktop LyricsOverlay renders the wide shared lyrics layout', (
    tester,
  ) async {
    await _pumpLyricsOverlay(tester, lyrics: AsyncData(_lyrics));

    expect(find.byType(InteractiveLyricsView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-lyrics-track-1')),
      findsOneWidget,
    );
    expect(find.byType(TrackCoverImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop mouse wheel shows accessible center control and delegates seek',
    (tester) async {
      final harness = await _pumpLyricsOverlay(
        tester,
        lyrics: AsyncData(_lyrics),
      );

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byKey(lyricsViewportKey)),
          scrollDelta: const Offset(0, 120),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
      expect(find.byTooltip('从此处播放'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(lyricsCenterPlayKey)).shortestSide,
        greaterThanOrEqualTo(44),
      );

      final playSemantics = find.bySemanticsLabel(
        RegExp(r'^从此处播放：Player lyric \d+$'),
      );
      expect(playSemantics, findsOneWidget);
      final selectedText = tester
          .getSemantics(playSemantics)
          .label
          .replaceFirst('从此处播放：', '');
      final selectedLyric = _lyrics.singleWhere(
        (lyric) => lyric.text == selectedText,
      );

      await tester.tap(find.byKey(lyricsCenterPlayKey));
      await tester.pumpAndSettle();

      expect(harness.audioService.seekCalls, [selectedLyric.timestamp]);
      expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    },
  );

  testWidgets('desktop LyricsOverlay resets lyric browsing on track change', (
    tester,
  ) async {
    final harness = await _pumpLyricsOverlay(
      tester,
      lyrics: AsyncData(_lyrics),
    );

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byKey(lyricsViewportKey)),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-lyrics-track-1')),
      findsOneWidget,
    );

    harness.container
        .read(currentTrackProvider.notifier)
        .setTrack(_secondTrack);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    expect(
      find.byKey(const ValueKey('desktop-lyrics-track-2')),
      findsOneWidget,
    );
  });

  testWidgets('desktop LyricsOverlay renders the shared lyrics loading state', (
    tester,
  ) async {
    await _pumpLyricsOverlay(
      tester,
      lyrics: const AsyncLoading<List<LyricLine>>(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('desktop LyricsOverlay renders the shared empty lyrics state', (
    tester,
  ) async {
    await _pumpLyricsOverlay(tester, lyrics: const AsyncData(<LyricLine>[]));

    expect(find.text('暂无歌词'), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('desktop LyricsOverlay renders the shared lyrics error state', (
    tester,
  ) async {
    await _pumpLyricsOverlay(
      tester,
      lyrics: AsyncError<List<LyricLine>>(
        StateError('failed'),
        StackTrace.empty,
      ),
    );

    expect(find.byType(LyricsFailureView), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
    expect(tester.takeException(), isNull);
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
