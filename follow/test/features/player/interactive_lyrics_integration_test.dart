import 'dart:async';
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
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/features/player/lyrics_overlay.dart';
import 'package:follow/features/player/player_page.dart';
import 'package:follow/shared/widgets/lyrics/interactive_lyrics_view.dart';
import 'package:follow/shared/widgets/lyrics/lyrics_failure_view.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/play_queue_sheet.dart';
import 'package:follow/shared/widgets/player_progress_bar.dart';
import 'package:follow/shared/widgets/player/folded_track_queue.dart';
import 'package:follow/shared/widgets/player/player_cover_art.dart';
import 'package:follow/shared/widgets/player/player_aurora_background.dart';
import 'package:follow/shared/widgets/player/playlist_gallery_drawer.dart';
import 'package:follow/shared/widgets/track_cover_image.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

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

const _playerLauncherKey = ValueKey('player-test-launcher');

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
  int playCalls = 0;
  int pauseCalls = 0;
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
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> applyPlayMode(PlayMode mode) async {}

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
  Track? track = _firstTrack,
  bool isPlaying = false,
  Size viewportSize = const Size(390, 844),
  EdgeInsets safeAreaInsets = EdgeInsets.zero,
  bool pushAsRoute = false,
  Stream<Duration?>? positionStream,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.reset);

  final audioService = _FakeAudioPlayerService();
  final container = ProviderContainer(
    overrides: [
      audioPlayerServiceProvider.overrideWithValue(audioService),
      isPlayingProvider.overrideWithValue(AsyncData(isPlaying)),
      if (positionStream == null)
        playerPositionProvider.overrideWithValue(
          const AsyncData(Duration(seconds: 10)),
        )
      else
        playerPositionProvider.overrideWith((ref) => positionStream),
      playerDurationProvider.overrideWithValue(
        const AsyncData(Duration(seconds: 180)),
      ),
      playerVolumeProvider.overrideWithValue(const AsyncData(0.65)),
      isFavoriteProvider.overrideWith(_FakeIsFavorite.new),
      currentTrackLyricsProvider.overrideWithValue(lyrics),
      currentLyricIndexProvider.overrideWithValue(2),
      playQueueProvider.overrideWithValue([
        if (track != null) track,
        _secondTrack,
      ]),
      playlistsProvider.overrideWith(_FakePlaylists.new),
      playlistDetailProvider(
        'playlist-1',
      ).overrideWith((ref) async => _playlistDetail),
    ],
  );
  addTearDown(container.dispose);
  if (track != null) {
    container.read(currentTrackProvider.notifier).setTrack(track);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            Widget buildPlayer(BuildContext routeContext) => MediaQuery(
              data: MediaQuery.of(
                routeContext,
              ).copyWith(padding: safeAreaInsets, viewPadding: safeAreaInsets),
              child: const PlayerPage(),
            );

            if (!pushAsRoute) return buildPlayer(context);
            return Scaffold(
              body: Center(
                child: FilledButton(
                  key: _playerLauncherKey,
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: buildPlayer)),
                  child: const Text('Open player'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  if (pushAsRoute) {
    await tester.tap(find.byKey(_playerLauncherKey));
    await tester.pumpAndSettle();
  }
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
  Stream<Duration?>? positionStream,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.reset);

  final audioService = _FakeAudioPlayerService();
  final container = ProviderContainer(
    overrides: [
      audioPlayerServiceProvider.overrideWithValue(audioService),
      isPlayingProvider.overrideWithValue(const AsyncData(false)),
      if (positionStream == null)
        playerPositionProvider.overrideWithValue(
          const AsyncData(Duration(seconds: 10)),
        )
      else
        playerPositionProvider.overrideWith((ref) => positionStream),
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
  Offset pageTranslation(WidgetTester tester) {
    final transform = tester
        .widget<AnimatedContainer>(find.byKey(playerPageTransformKey))
        .transform!;
    return Offset(transform.storage[12], transform.storage[13]);
  }

  Offset blankPlayerPoint(WidgetTester tester) {
    final rect = tester.getRect(find.byKey(playerPageDismissGestureKey));
    return Offset(rect.right - 8, rect.top + 250);
  }

  testWidgets('position ticks do not rebuild the complete mobile player', (
    tester,
  ) async {
    final positions = StreamController<Duration?>.broadcast();
    addTearDown(positions.close);
    await _pumpPlayerPage(
      tester,
      lyrics: AsyncData(_lyrics),
      positionStream: positions.stream,
    );
    positions.add(const Duration(seconds: 10));
    await tester.pump();

    final rebuiltTypes = <Type>[];
    final previousRebuildCallback = debugOnRebuildDirtyWidget;
    addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildCallback);
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      rebuiltTypes.add(element.widget.runtimeType);
    };

    positions.add(const Duration(seconds: 11));
    await tester.pump();

    expect(rebuiltTypes, isNot(contains(PlayerPage)));
    final progress = find
        .descendant(
          of: find.byKey(const ValueKey('player-control-deck')),
          matching: find.byType(Slider),
        )
        .first;
    expect(tester.widget<Slider>(progress).value, 11000);
  });

  testWidgets('position ticks do not rebuild the complete lyrics overlay', (
    tester,
  ) async {
    final positions = StreamController<Duration?>.broadcast();
    addTearDown(positions.close);
    await _pumpLyricsOverlay(
      tester,
      lyrics: AsyncData(_lyrics),
      positionStream: positions.stream,
    );
    positions.add(const Duration(seconds: 10));
    await tester.pump();

    final rebuiltTypes = <Type>[];
    final previousRebuildCallback = debugOnRebuildDirtyWidget;
    addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildCallback);
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      rebuiltTypes.add(element.widget.runtimeType);
    };

    positions.add(const Duration(seconds: 11));
    await tester.pump();

    expect(rebuiltTypes, isNot(contains(LyricsOverlay)));
    expect(
      tester.widget<PlayerProgressBar>(find.byType(PlayerProgressBar)).position,
      const Duration(seconds: 11),
    );
  });

  testWidgets('player keeps an opaque underlay behind the translated page', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    final underlay = find.byKey(playerPageOpaqueUnderlayKey);
    expect(underlay, findsOneWidget);
    expect(tester.widget<ColoredBox>(underlay).color.a, 1);
    expect(
      tester.getSize(underlay),
      MediaQuery.sizeOf(tester.element(underlay)),
    );
    expect(
      find.descendant(
        of: find.byKey(playerPageDismissGestureKey),
        matching: underlay,
      ),
      findsNothing,
    );
  });

  testWidgets('blank player atmosphere follows a downward drag and rebounds', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final initialTranslation = pageTranslation(tester);

    final gesture = await tester.startGesture(blankPlayerPoint(tester));
    await gesture.moveBy(const Offset(0, 56));
    await tester.pump();

    expect(pageTranslation(tester).dy, closeTo(initialTranslation.dy + 56, 1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pageTranslation(tester), initialTranslation);
  });

  testWidgets('blank downward drag past the threshold dismisses the player', (
    tester,
  ) async {
    await _pumpPlayerPage(
      tester,
      lyrics: AsyncData(_lyrics),
      pushAsRoute: true,
    );

    await tester.timedDragFrom(
      blankPlayerPoint(tester),
      const Offset(0, 110),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_playerLauncherKey), findsOneWidget);
    expect(find.byType(PlayerPage), findsNothing);
  });

  testWidgets('short fast blank downward flick dismisses the player', (
    tester,
  ) async {
    await _pumpPlayerPage(
      tester,
      lyrics: AsyncData(_lyrics),
      pushAsRoute: true,
    );

    await tester.flingFrom(blankPlayerPoint(tester), const Offset(0, 56), 900);
    await tester.pumpAndSettle();

    expect(find.byKey(_playerLauncherKey), findsOneWidget);
    expect(find.byType(PlayerPage), findsNothing);
  });

  testWidgets('record pull target and control deck exclude page dismissal', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final initialTranslation = pageTranslation(tester);

    for (final target in [
      find.byKey(vinylRecordSurfaceKey),
      find.byKey(playerPlaylistPullHandleKey),
      find.byKey(const ValueKey('player-control-deck')),
    ]) {
      final gesture = await tester.startGesture(tester.getCenter(target));
      await gesture.moveBy(const Offset(0, 56));
      await tester.pump();
      expect(pageTranslation(tester), initialTranslation);
      await gesture.cancel();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'playlist pull target is visible below the toolbar and 48dp tall',
    (tester) async {
      const topInset = 24.0;
      await _pumpPlayerPage(
        tester,
        lyrics: AsyncData(_lyrics),
        safeAreaInsets: const EdgeInsets.only(top: topInset, bottom: 16),
      );

      final targetRect = tester.getRect(
        find.byKey(playerPlaylistPullHandleKey),
      );
      expect(targetRect.height, greaterThanOrEqualTo(48));
      expect(targetRect.top, greaterThanOrEqualTo(topInset + kToolbarHeight));
      expect(
        tester
            .widget<Opacity>(find.byKey(playerPlaylistGuidanceOpacityKey))
            .opacity,
        greaterThanOrEqualTo(0.65),
      );
    },
  );

  testWidgets('lyrics app bar title stays below the top safe area', (
    tester,
  ) async {
    const topInset = 24.0;
    await _pumpPlayerPage(
      tester,
      lyrics: AsyncData(_lyrics),
      safeAreaInsets: const EdgeInsets.only(top: topInset, bottom: 16),
    );

    await _showLyricsPage(tester);

    final titleRect = tester.getRect(find.text(_firstTrack.title));
    expect(titleRect.top, greaterThanOrEqualTo(topInset));
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('player app bar keeps a stable title slot across visual modes', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    Text appBarTitle() {
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      return appBar.title! as Text;
    }

    expect(appBarTitle().data, isEmpty);
    await _showLyricsPage(tester);
    expect(appBarTitle().data, _firstTrack.title);
  });

  testWidgets('closed playlist drawer is invisible and excluded', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    expect(
      tester
          .widget<Opacity>(find.byKey(playerPlaylistGalleryOpacityKey))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(playerPlaylistGalleryPointerKey))
          .ignoring,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find.byKey(playerPlaylistGallerySemanticsKey),
          )
          .excluding,
      isTrue,
    );
    expect(find.bySemanticsLabel('播放歌单 Driving Mix'), findsNothing);
    semantics.dispose();
  });

  testWidgets('pull progress fades gallery in and reduces top chrome opacity', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    final restingChrome = tester.widget<ColoredBox>(
      find.byKey(playerTopChromeSurfaceKey),
    );
    expect(restingChrome.color.a, closeTo(0.22, 0.01));
    expect(
      find.descendant(
        of: find.byKey(playerTopChromeSurfaceKey),
        matching: find.byType(GlassPanel),
      ),
      findsNothing,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(playerPlaylistPullHandleKey)),
    );
    await gesture.moveBy(const Offset(0, 44));
    await tester.pump();

    final galleryOpacity = tester
        .widget<Opacity>(find.byKey(playerPlaylistGalleryOpacityKey))
        .opacity;
    final pulledChrome = tester.widget<ColoredBox>(
      find.byKey(playerTopChromeSurfaceKey),
    );
    expect(galleryOpacity, greaterThan(0));
    expect(galleryOpacity, lessThan(1));
    expect(pulledChrome.color.a, lessThan(restingChrome.color.a));
    expect(
      tester
          .widget<Opacity>(find.byKey(playerPlaylistGuidanceOpacityKey))
          .opacity,
      greaterThan(0),
    );

    await gesture.cancel();
  });

  testWidgets('sub-threshold pull restores the resting playlist layers', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    await tester.drag(
      find.byKey(playerPlaylistPullHandleKey),
      const Offset(0, 36),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Opacity>(find.byKey(playerPlaylistGalleryOpacityKey))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(playerPlaylistGuidanceOpacityKey))
          .opacity,
      closeTo(0.7, 0.01),
    );
    expect(
      tester.widget<ColoredBox>(find.byKey(playerTopChromeSurfaceKey)).color.a,
      closeTo(0.22, 0.01),
    );
  });

  testWidgets('open playlist removes the title-bar color stripe', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    await tester.drag(
      find.byKey(playerPlaylistPullHandleKey),
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ColoredBox>(find.byKey(playerTopChromeSurfaceKey)).color.a,
      0,
    );
  });

  testWidgets('mobile player composes one grouped cover-adaptive glass scene', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    final expectedPalette = PlayerPalette.fallback(
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );
    final backdrop = tester.widget<PlayerAuroraBackground>(
      find.byType(PlayerAuroraBackground),
    );
    expect(backdrop.track, _firstTrack);
    expect(backdrop.palette, expectedPalette);
    expect(find.byType(BackdropGroup), findsOneWidget);

    final topChrome = tester.widget<ColoredBox>(
      find.byKey(playerTopChromeSurfaceKey),
    );
    final controlDeck = tester.widget<GlassPanel>(
      find.byKey(const ValueKey('player-control-deck')),
    );
    expect(topChrome.color, expectedPalette.scrim.withValues(alpha: 0.22));
    expect(controlDeck.tier, GlassTier.standard);

    expect(
      tester.getSize(find.byKey(vinylRecordSurfaceKey)),
      const Size.square(280),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('player-track-info-slot')))
          .height,
      104,
    );
    expect(find.byKey(playerPlaylistPullHandleKey), findsOneWidget);
    expect(find.byKey(vinylRecordSurfaceKey), findsOneWidget);
    expect(find.byKey(playerLyricsSurfaceKey), findsOneWidget);
    expect(find.byKey(playerQueueSurfaceKey), findsOneWidget);

    final progressTheme = tester.widget<SliderTheme>(
      find
          .descendant(
            of: find.byKey(const ValueKey('player-control-deck')),
            matching: find.byType(SliderTheme),
          )
          .first,
    );
    expect(progressTheme.data.activeTrackColor, expectedPalette.progress);
    expect(
      tester.widget<Text>(find.text(_firstTrack.title).first).style?.color,
      FollowThemeTokens.light.textPrimary,
    );
  });

  testWidgets('mobile lyrics render directly on the player atmosphere', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await _showLyricsPage(tester);

    expect(
      find.descendant(
        of: find.byKey(playerLyricsSurfaceKey),
        matching: find.byType(InteractiveLyricsView),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(playerLyricsSurfaceKey),
        matching: find.byType(GlassPanel),
      ),
      findsNothing,
    );
  });

  testWidgets('folded queue palette surface is invisible until revealed', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    Opacity queueOpacity() => tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(foldedTrackQueueKey),
        matching: find.byType(Opacity),
      ),
    );

    expect(
      find.ancestor(
        of: find.byKey(foldedTrackQueueKey),
        matching: find.byType(GlassPanel),
      ),
      findsNothing,
    );

    expect(queueOpacity().opacity, 0);
    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(120, 0));
    await tester.pump();
    expect(queueOpacity().opacity, greaterThan(0));
  });

  testWidgets('mobile PlayerPage uses the nothing-playing illustrated state', (
    tester,
  ) async {
    await _pumpPlayerPage(
      tester,
      lyrics: const AsyncData(<LyricLine>[]),
      track: null,
    );

    expect(
      tester.widget<AppStateView>(find.byType(AppStateView)).kind,
      AppStateKind.nothingPlaying,
    );
    expect(find.widgetWithText(FilledButton, '打开音乐库'), findsOneWidget);
  });

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
    expect(source, contains('playbackPosition: position'));
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
    expect(source, contains('playbackPosition: position'));

    expect(source, isNot(contains('_lyricsScrollController')));
    expect(source, isNot(contains('currentLyricIdx * 48.0')));
  });

  testWidgets('desktop lyrics overlay owns one cover-adaptive glass scene', (
    tester,
  ) async {
    await _pumpLyricsOverlay(tester, lyrics: AsyncData(_lyrics));

    final expectedPalette = PlayerPalette.fallback(
      brightness: Brightness.light,
      tokens: FollowThemeTokens.light,
    );
    final backdrop = tester.widget<PlayerAuroraBackground>(
      find.byType(PlayerAuroraBackground),
    );
    expect(backdrop.track, _firstTrack);
    expect(backdrop.palette, expectedPalette);
    expect(find.byType(BackdropGroup), findsOneWidget);

    final contentGlass = tester.widget<GlassPanel>(
      find.byKey(const ValueKey('desktop-lyrics-content-glass')),
    );
    expect(contentGlass.tier, GlassTier.strong);
  });

  testWidgets('desktop LyricsOverlay renders the wide shared lyrics layout', (
    tester,
  ) async {
    await _pumpLyricsOverlay(tester, lyrics: AsyncData(_lyrics));

    expect(find.byType(InteractiveLyricsView), findsOneWidget);
    expect(
      tester
          .widget<InteractiveLyricsView>(find.byType(InteractiveLyricsView))
          .playbackPosition,
      const Duration(seconds: 10),
    );
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
    expect(
      tester.widget<InteractiveLyricsView>(lyrics).playbackPosition,
      const Duration(seconds: 10),
    );
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

    expect(find.byType(AppContentSkeleton), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('desktop LyricsOverlay renders the shared empty lyrics state', (
    tester,
  ) async {
    await _pumpLyricsOverlay(tester, lyrics: const AsyncData(<LyricLine>[]));

    expect(
      tester.widget<AppStateView>(find.byType(AppStateView)).kind,
      AppStateKind.noLyrics,
    );
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
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    await tester.tap(find.byTooltip('当前播放队列'));
    await tester.pumpAndSettle();

    expect(find.byType(FoldedTrackQueue), findsOneWidget);
    expect(find.byType(PlayQueueSheet), findsOneWidget);
    expect(find.text('播放队列 (2)'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
  });

  testWidgets('folded queue stays open when it has not been scrolled', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);
  });

  testWidgets('tapping a folded queue item does not arm auto-close', (
    tester,
  ) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(120, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(foldedQueueTrackKey('track-2')));
    await tester.pumpAndSettle();
    expect(harness.audioService.selectedQueueIndex, 1);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);
  });

  testWidgets('folded queue interaction restarts the two-second idle timer', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1500));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(foldedQueueListKey)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);

    await gesture.moveBy(const Offset(0, -96));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);

    await tester.pump(const Duration(milliseconds: 221));
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
  });

  testWidgets('open queue consumes the first record tap', (tester) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);
    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();

    await tester.tap(record);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(harness.audioService.playCalls, 0);
    expect(harness.audioService.pauseCalls, 0);
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);

    await tester.tap(record);
    await tester.pump();
    expect(harness.audioService.playCalls, 1);
  });

  testWidgets('open queue consumes an upward record swipe', (tester) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(harness.audioService.nextCalls, 0);
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);

    await tester.drag(record, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(harness.audioService.nextCalls, 1);
  });

  testWidgets('open queue consumes a downward record swipe', (tester) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(harness.audioService.previousCalls, 0);
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);

    await tester.drag(record, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(harness.audioService.previousCalls, 1);
  });

  testWidgets('open queue consumes a left record swipe', (tester) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    expect(tester.getCenter(record).dx, closeTo(195, 1));
    expect(tester.getTopLeft(find.byKey(playerLyricsSurfaceKey)).dx, 390);

    await tester.drag(record, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(playerLyricsSurfaceKey)).dx, 0);
  });

  testWidgets('open queue consumes a right record swipe', (tester) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();
    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    expect(tester.getCenter(record).dx, closeTo(195, 1));

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);
  });

  testWidgets('record tap pauses active playback once', (tester) async {
    final harness = await _pumpPlayerPage(
      tester,
      lyrics: AsyncData(_lyrics),
      isPlaying: true,
    );

    await tester.tap(find.byKey(vinylRecordSurfaceKey));
    await tester.pump();

    expect(harness.audioService.pauseCalls, 1);
    expect(harness.audioService.playCalls, 0);
  });

  testWidgets('player controls and sliders dismiss an open folded queue', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);

    Future<void> openQueue() async {
      await tester.drag(record, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity,
        1,
      );
    }

    await openQueue();
    await tester.tap(find.byTooltip('播放模式：顺序播放'));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await openQueue();
    final progressSlider = find.byType(Slider).first;
    final progressGesture = await tester.startGesture(
      tester.getCenter(progressSlider),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    await progressGesture.up();

    await openQueue();
    await tester.tap(find.byTooltip('静音'));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
  });

  testWidgets('record gestures switch tracks and reveal queue', (tester) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(harness.audioService.nextCalls, 1);
    harness.container
        .read(currentTrackProvider.notifier)
        .setTrack(_secondTrack);
    harness.container.read(currentIndexProvider.notifier).setIndex(1);
    await tester.pump();

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(harness.audioService.previousCalls, 1);
    harness.container.read(currentTrackProvider.notifier).setTrack(_firstTrack);
    harness.container.read(currentIndexProvider.notifier).setIndex(0);
    await tester.pump();

    await tester.drag(find.byKey(vinylRecordSurfaceKey), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);
  });

  testWidgets('record pointer-down starts closing an open queue', (
    tester,
  ) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);

    final gesture = await tester.startGesture(tester.getCenter(record));
    await gesture.moveBy(const Offset(0, -14));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -16));
    await tester.pump(const Duration(milliseconds: 110));

    expect(
      tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity,
      lessThan(1),
    );
    expect(harness.audioService.nextCalls, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    expect(harness.audioService.nextCalls, 0);
  });

  testWidgets('adjacent preview stays anchored to the displayed track', (
    tester,
  ) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    harness.container.read(currentIndexProvider.notifier).setIndex(1);
    await tester.pump();

    final cover = tester.widget<PlayerCoverArt>(find.byType(PlayerCoverArt));
    expect(cover.track.id, _firstTrack.id);
    expect(cover.nextTrack?.id, _secondTrack.id);
  });

  testWidgets('player supplies adjacent queue records to the vertical pager', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));

    final cover = tester.widget<PlayerCoverArt>(find.byType(PlayerCoverArt));
    expect(cover.previousTrack?.id, _secondTrack.id);
    expect(cover.nextTrack?.id, _secondTrack.id);
  });

  testWidgets('vertical paging keeps the bounded record viewport stationary', (
    tester,
  ) async {
    final harness = await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final surface = find.byKey(vinylRecordSurfaceKey);
    final initialCenter = tester.getCenter(surface);

    final gesture = await tester.startGesture(initialCenter);
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -70));
    await tester.pump();

    expect(tester.getCenter(surface), initialCenter);
    expect(
      tester
          .widget<AnimatedContainer>(find.byKey(vinylCurrentRecordPageKey))
          .transform!
          .storage[13],
      lessThan(0),
    );
    expect(harness.audioService.nextCalls, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(harness.audioService.nextCalls, 1);
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

  testWidgets('confirmed top pull closes an open playback queue', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);
    final initialRecordX = tester.getCenter(record).dx;

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 1);
    expect(tester.getCenter(record).dx, greaterThan(initialRecordX));

    await tester.drag(
      find.byKey(playerPlaylistPullHandleKey),
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    expect(tester.getCenter(record).dx, closeTo(initialRecordX, 1));
  });

  testWidgets('below-threshold top pull still closes an open playback queue', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: AsyncData(_lyrics));
    final record = find.byKey(vinylRecordSurfaceKey);
    final initialRecordX = tester.getCenter(record).dx;

    await tester.drag(record, const Offset(120, 0));
    await tester.pumpAndSettle();

    await tester.timedDrag(
      find.byKey(playerPlaylistPullHandleKey),
      const Offset(0, 40),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(find.byKey(foldedQueueRevealKey)).opacity, 0);
    expect(tester.getCenter(record).dx, closeTo(initialRecordX, 1));
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
      expect(pageTranslation(tester), Offset.zero);
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

    expect(find.byType(AppContentSkeleton), findsOneWidget);
    expect(find.byKey(lyricsCenterPlayKey), findsNothing);
  });

  testWidgets('mobile PlayerPage renders the shared empty lyrics state', (
    tester,
  ) async {
    await _pumpPlayerPage(tester, lyrics: const AsyncData(<LyricLine>[]));
    await _showLyricsPage(tester);

    expect(
      tester.widget<AppStateView>(find.byType(AppStateView)).kind,
      AppStateKind.noLyrics,
    );
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
