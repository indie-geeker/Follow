import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/audio_provider.dart';
import 'package:follow/data/providers/lyrics_provider.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/features/player/lyrics_overlay.dart';
import 'package:follow/features/player/player_page.dart';
import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';
import 'package:follow/shared/widgets/player/folded_track_queue.dart';
import 'package:follow/shared/widgets/player/player_cover_art.dart';
import 'package:follow/shared/widgets/player/playlist_gallery_drawer.dart';
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

const _playlist = Playlist(
  id: 'playlist-1',
  name: 'Driving Mix',
  trackCount: 2,
);

const _playlistDetail = PlaylistDetail(
  id: 'playlist-1',
  name: 'Driving Mix',
  tracks: [_firstTrack, _secondTrack],
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
  int nextCalls = 0;
  int previousCalls = 0;
  int? selectedQueueIndex;
  String? selectedPlaylistId;
  List<Track>? selectedPlaylistTracks;

  @override
  Future<void> seek(Duration position) async => seekCalls.add(position);

  @override
  Future<void> playNext() async => nextCalls++;

  @override
  Future<void> playPrevious() async => previousCalls++;

  @override
  Future<void> playQueueItemAt(int index) async {
    selectedQueueIndex = index;
  }

  @override
  Future<void> playPlaylist(
    String playlistId,
    List<Track> tracks, {
    int startIndex = 0,
  }) async {
    selectedPlaylistId = playlistId;
    selectedPlaylistTracks = tracks;
  }
}

class _FakeIsFavorite extends IsFavorite {
  @override
  Future<bool> build(String? trackId) async => false;
}

class _FakePlaylists extends Playlists {
  @override
  Future<List<Playlist>> build() async => const [_playlist];
}

Future<({ProviderContainer container, _FakeAudioPlayerService audioService})>
_pumpPlayerPage(
  WidgetTester tester, {
  required AsyncValue<List<LyricLine>> lyrics,
  Track track = _firstTrack,
  Size viewportSize = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewportSize;
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
      playQueueProvider.overrideWithValue([track, _secondTrack]),
      playlistsProvider.overrideWith(_FakePlaylists.new),
      playlistDetailProvider(
        'playlist-1',
      ).overrideWith((ref) async => _playlistDetail),
    ],
  );
  addTearDown(container.dispose);
  container.read(currentTrackProvider.notifier).setTrack(track);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayerPage()),
    ),
  );
  await tester.pump();
  return (container: container, audioService: audioService);
}

Future<void> _showLyricsPage(WidgetTester tester) async {
  await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(-120, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byKey(playerLyricsSurfaceKey), findsOneWidget);
}

Future<({ProviderContainer container, _FakeAudioPlayerService audioService})>
_pumpLyricsOverlay(
  WidgetTester tester, {
  required AsyncValue<List<LyricLine>> lyrics,
  Size viewportSize = const Size(1280, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewportSize;
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

    expect(source, isNot(contains('_lyricsScrollController')));
    expect(source, isNot(contains('currentLyricIdx * 48.0')));
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

  testWidgets('desktop LyricsOverlay renders the narrow shared lyrics layout', (
    tester,
  ) async {
    await _pumpLyricsOverlay(
      tester,
      lyrics: AsyncData(_lyrics),
      viewportSize: const Size(599, 800),
    );

    final cover = find.byType(TrackCoverImage);
    final lyrics = find.byType(InteractiveLyricsView);
    expect(lyrics, findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-lyrics-track-1')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(lyrics).dy,
      greaterThan(tester.getBottomLeft(cover).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop mouse wheel shows accessible center control and delegates seek',
    (tester) async {
      final harness = await _pumpLyricsOverlay(
        tester,
        lyrics: AsyncData(_lyrics),
      );
      final lyricsScrollable = find.descendant(
        of: find.byType(InteractiveLyricsView),
        matching: find.byType(Scrollable),
      );
      final scrollPosition = tester
          .state<ScrollableState>(lyricsScrollable)
          .position;
      final initialOffset = scrollPosition.pixels;

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byKey(lyricsViewportKey)),
          scrollDelta: const Offset(0, 96),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(scrollPosition.pixels, greaterThan(initialOffset));
      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
      expect(find.byTooltip('从此处播放'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(lyricsCenterPlayKey)).shortestSide,
        greaterThanOrEqualTo(44),
      );

      expect(find.bySemanticsLabel('从此处播放：Player lyric 4'), findsOneWidget);
      expect(find.bySemanticsLabel('从此处播放：Player lyric 2'), findsNothing);

      await tester.tap(find.byKey(lyricsCenterPlayKey));
      await tester.pumpAndSettle();

      expect(harness.audioService.seekCalls, [const Duration(seconds: 20)]);
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
    'mobile player renders vinyl without dots and keeps controls stable',
    (tester) async {
      const longTitleTrack = Track(
        id: 'long-title',
        title:
            'A deliberately long mobile player title that wraps onto two lines',
        durationSeconds: 180,
        artist: Artist(id: 'artist-1', name: 'Artist'),
      );
      await _pumpPlayerPage(
        tester,
        lyrics: AsyncData(_lyrics),
        track: longTitleTrack,
      );

      final progressSlider = find.byType(Slider).first;
      expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
      expect(find.byKey(vinylGroovesKey), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byKey(playlistGalleryPageViewKey), findsOneWidget);
      final coverSliderY = tester.getTopLeft(progressSlider).dy;

      await _showLyricsPage(tester);

      expect(tester.getTopLeft(progressSlider).dy, closeTo(coverSliderY, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile player stays operable on small portrait and landscape', (
    tester,
  ) async {
    await _pumpPlayerPage(
      tester,
      lyrics: AsyncData(_lyrics),
      viewportSize: const Size(375, 667),
    );

    expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
    expect(find.byTooltip('下一首'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();

    expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
    expect(find.byTooltip('下一首'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile player queue action opens the active playback queue', (
    tester,
  ) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    await tester.tap(find.byTooltip('当前播放队列'));
    await tester.pumpAndSettle();

    expect(find.byType(FoldedTrackQueue), findsOneWidget);
    expect(find.text('当前播放队列'), findsNothing);
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);
    expect(
      tester.getSize(find.byKey(foldedTrackQueueKey)).height,
      closeTo(tester.getSize(find.byKey(vinylRecordSurfaceKey)).height, 0.1),
    );

    await tester.tap(find.byKey(foldedQueueTrackKey('track-2')));
    await tester.pumpAndSettle();
    expect(harness.audioService.selectedQueueIndex, 1);
  });

  testWidgets('record gestures switch tracks and reveal queue', (tester) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(harness.audioService.nextCalls, 1);

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(harness.audioService.previousCalls, 1);

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);
  });

  testWidgets('player derives a safe vertical record movement boundary', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    final cover = tester.widget<PlayerCoverArt>(find.byType(PlayerCoverArt));
    expect(cover.maxVerticalVisualOffset, greaterThan(0));
    expect(cover.maxVerticalVisualOffset, lessThanOrEqualTo(48));
  });

  testWidgets(
    'right drag progressively reveals queue below the moving record',
    (tester) async {
      await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
      final initialRecordCenter = tester.getCenter(
        find.byKey(vinylRecordSurfaceKey),
      );

      final gesture = await tester.startGesture(initialRecordCenter);
      await gesture.moveBy(const Offset(72, 18));
      await tester.pump();

      final opacity = tester
          .widget<Opacity>(find.byKey(foldedQueueRevealKey))
          .opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      expect(
        tester.getCenter(find.byKey(vinylRecordSurfaceKey)).dx,
        greaterThan(initialRecordCenter.dx),
      );
      expect(find.text('当前播放队列'), findsNothing);

      await gesture.up();
    },
  );

  testWidgets('record and lyrics follow one ViewPager-like left drag', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final initialRecordCenter = tester.getCenter(
      find.byKey(vinylRecordSurfaceKey),
    );

    final gesture = await tester.startGesture(initialRecordCenter);
    await gesture.moveBy(const Offset(-110, 12));
    await tester.pump();

    expect(find.byKey(playerLyricsSurfaceKey), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)).dx,
      lessThan(initialRecordCenter.dx),
    );
    final lyricsLeft = tester.getTopLeft(find.byKey(playerLyricsSurfaceKey)).dx;
    expect(lyricsLeft, greaterThan(0));
    expect(lyricsLeft, lessThan(tester.view.physicalSize.width));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(playerLyricsSurfaceKey)).dx,
      closeTo(0, 0.1),
    );
  });

  testWidgets('lyrics right drag brings the record back like a ViewPager', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await _showLyricsPage(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(playerLyricsSurfaceKey)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(110, 0));
    await tester.pump();

    expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
    final recordRight = tester
        .getTopRight(find.byKey(vinylRecordSurfaceKey))
        .dx;
    expect(recordRight, greaterThan(0));
    expect(recordRight, lessThan(tester.view.physicalSize.width / 2));
    expect(
      tester.getTopLeft(find.byKey(playerLyricsSurfaceKey)).dx,
      greaterThan(0),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byKey(vinylRecordSurfaceKey)).dx,
      closeTo(tester.view.physicalSize.width / 2, 1),
    );
  });

  testWidgets('top pull opens gallery and selection replaces playlist', (
    tester,
  ) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await tester.pumpAndSettle();
    final initialPlayerTop = tester
        .getTopLeft(find.byIcon(Icons.keyboard_arrow_down).first)
        .dy;

    expect(find.byKey(playerPlaylistGalleryKey), findsOneWidget);

    await tester.drag(
      find.byKey(playerPlaylistPullHandleKey),
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(playerPlaylistGalleryKey), findsOneWidget);
    expect(find.byType(PlaylistGalleryDrawer), findsOneWidget);
    expect(
      tester.getTopLeft(find.byIcon(Icons.keyboard_arrow_down).first).dy,
      greaterThan(initialPlayerTop + 250),
    );
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color == Colors.black.withValues(alpha: 0.42)),
      isEmpty,
    );

    final playlistPlayButton = find.descendant(
      of: find.byTooltip('播放歌单 Driving Mix'),
      matching: find.byType(InkWell),
    );
    expect(playlistPlayButton, findsOneWidget);
    await tester.tap(playlistPlayButton);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byIcon(Icons.keyboard_arrow_down).first).dy,
      closeTo(initialPlayerTop, 0.1),
    );
    expect(find.text('歌单加载失败，请重试'), findsNothing);
    expect(harness.audioService.selectedPlaylistId, 'playlist-1');
    expect(harness.audioService.selectedPlaylistTracks, _playlistDetail.tracks);
    expect(find.byKey(playerPlaylistGalleryKey), findsOneWidget);
  });

  testWidgets('partial top pull directly moves the complete player page', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await tester.pumpAndSettle();
    final playerBack = find.byIcon(Icons.keyboard_arrow_down).first;
    final initialTop = tester.getTopLeft(playerBack).dy;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(playerPlaylistPullHandleKey)),
    );
    await gesture.moveBy(const Offset(0, 72));
    await tester.pump();

    expect(find.byKey(playerPlaylistGalleryKey), findsOneWidget);
    expect(tester.getTopLeft(playerBack).dy, greaterThan(initialTop + 40));

    await gesture.up();
  });

  testWidgets('tapping gallery or displaced player background closes gallery', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final playerBack = find.byIcon(Icons.keyboard_arrow_down).first;
    final initialTop = tester.getTopLeft(playerBack).dy;

    Future<void> openGallery() async {
      await tester.drag(
        find.byKey(playerPlaylistPullHandleKey),
        const Offset(0, 160),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(playerBack).dy, greaterThan(initialTop + 250));
    }

    await openGallery();
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(playerBack).dy, closeTo(initialTop, 0.1));

    await openGallery();
    await tester.tapAt(const Offset(8, 720));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(playerBack).dy, closeTo(initialTop, 0.1));
  });

  testWidgets('reversing a top pull below threshold keeps gallery closed', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final playerBack = find.byIcon(Icons.keyboard_arrow_down).first;
    final initialTop = tester.getTopLeft(playerBack).dy;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(playerPlaylistPullHandleKey)),
    );
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(playerPlaylistGalleryKey), findsOneWidget);
    expect(tester.getTopLeft(playerBack).dy, closeTo(initialTop, 0.1));
  });

  testWidgets('system back closes player layers before leaving the player', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final playerBack = find.byIcon(Icons.keyboard_arrow_down).first;
    final initialTop = tester.getTopLeft(playerBack).dy;

    await tester.drag(
      find.byKey(playerPlaylistPullHandleKey),
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(playerPlaylistGalleryKey), findsOneWidget);
    expect(tester.getTopLeft(playerBack).dy, greaterThan(initialTop + 250));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(playerPlaylistGalleryKey), findsOneWidget);
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(tester.getTopLeft(playerBack).dy, closeTo(initialTop, 0.1));

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
  });

  testWidgets(
    'lyrics owns vertical browsing and right swipe returns to vinyl',
    (tester) async {
      await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
      await _showLyricsPage(tester);
      expect(find.byKey(lyricsCenterPlayKey), findsNothing);

      final verticalGesture = await tester.startGesture(
        tester.getCenter(find.byKey(lyricsViewportKey)),
      );
      await verticalGesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await verticalGesture.moveBy(const Offset(0, -90));
      await tester.pump();
      expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
      await verticalGesture.up();

      await tester.drag(
        find.byKey(playerLyricsSurfaceKey),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
    },
  );

  testWidgets('mobile PlayerPage resets lyric browsing when track changes', (
    tester,
  ) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await _showLyricsPage(tester);

    final verticalGesture = await tester.startGesture(
      tester.getCenter(find.byKey(lyricsViewportKey)),
    );
    await verticalGesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await verticalGesture.moveBy(const Offset(0, -90));
    await tester.pump();
    expect(find.byKey(lyricsCenterPlayKey), findsOneWidget);
    await verticalGesture.up();
    expect(find.byKey(const ValueKey('mobile-lyrics-track-1')), findsOneWidget);

    harness.container
        .read(currentTrackProvider.notifier)
        .setTrack(_secondTrack);
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
