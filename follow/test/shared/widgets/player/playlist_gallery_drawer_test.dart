import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/core/theme/player_palette.dart';
import 'package:follow/shared/widgets/player/playlist_gallery_drawer.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

const _playlists = [
  Playlist(id: 'playlist-1', name: 'Morning Drive', trackCount: 12),
  Playlist(id: 'playlist-2', name: 'Night Highway', trackCount: 24),
  Playlist(id: 'playlist-3', name: 'Weekend', trackCount: 8),
];
const _palette = PlayerPalette(
  primaryControl: Color(0xFF173E89),
  onPrimaryControl: Colors.white,
  secondary: Color(0xFF8A2362),
  ambient: Color(0xFF16869B),
  progress: Color(0xFF8A2362),
  glow: Color(0xFF16869B),
  scrim: Color(0xFFF7F6FC),
);

void main() {
  Future<void> pumpGallery(
    WidgetTester tester, {
    required AsyncValue<List<Playlist>> playlists,
    String? currentPlaylistId,
    Future<void> Function(Playlist)? onSelect,
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaylistGalleryDrawer(
            palette: _palette,
            playlists: playlists,
            currentPlaylistId: currentPlaylistId,
            onSelect: onSelect ?? (_) async {},
            onClose: () {},
            onRetry: onRetry,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders loading empty and retryable error states', (
    tester,
  ) async {
    await pumpGallery(tester, playlists: const AsyncLoading<List<Playlist>>());
    expect(find.byType(AppContentSkeleton), findsOneWidget);

    await pumpGallery(tester, playlists: const AsyncData(<Playlist>[]));
    expect(
      tester.widget<AppStateView>(find.byType(AppStateView)).kind,
      AppStateKind.emptyPlaylist,
    );

    var retries = 0;
    await pumpGallery(
      tester,
      playlists: AsyncError(StateError('failed'), StackTrace.empty),
      onRetry: () => retries++,
    );
    expect(
      tester.widget<AppStateView>(find.byType(AppStateView)).kind,
      AppStateKind.failure,
    );
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });

  testWidgets('renders as a flat page rather than a rounded popup', (
    tester,
  ) async {
    await pumpGallery(tester, playlists: const AsyncData(_playlists));

    final pageMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PlaylistGalleryDrawer),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(pageMaterial.borderRadius, isNull);
    expect(pageMaterial.clipBehavior, Clip.none);
    expect(
      tester
          .widget<GlassPanel>(
            find.byKey(const ValueKey('playlist-gallery-glass')),
          )
          .tier,
      GlassTier.strong,
    );
  });

  testWidgets('centers the active playlist and scales neighbors smaller', (
    tester,
  ) async {
    await pumpGallery(
      tester,
      playlists: const AsyncData(_playlists),
      currentPlaylistId: 'playlist-2',
    );

    final pageView = tester.widget<PageView>(
      find.byKey(playlistGalleryPageViewKey),
    );
    expect(pageView.controller!.initialPage, 1);
    expect(
      find.bySemanticsLabel(RegExp('歌单：Night Highway，24 首，当前播放歌单')),
      findsOneWidget,
    );

    final centerTransform = tester.widget<Transform>(
      find.byKey(playlistCardScaleKey('playlist-2')),
    );
    final neighborTransform = tester.widget<Transform>(
      find.byKey(playlistCardScaleKey('playlist-1')),
    );
    expect(
      centerTransform.transform.storage[0],
      greaterThan(neighborTransform.transform.storage[0]),
    );

    final leftStackTransform = tester.widget<Transform>(
      find.byKey(playlistCardStackKey('playlist-1')),
    );
    expect(leftStackTransform.transform.storage[12], greaterThan(0));
  });

  testWidgets('horizontal paging changes the centered playlist', (
    tester,
  ) async {
    await pumpGallery(
      tester,
      playlists: const AsyncData(_playlists),
      currentPlaylistId: 'playlist-1',
    );

    await tester.drag(
      find.byKey(playlistGalleryPageViewKey),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Night Highway'), findsOneWidget);
    expect(find.byKey(playlistCenteredCardKey('playlist-2')), findsOneWidget);
  });

  testWidgets('arrow buttons page through playlists like a swipe', (
    tester,
  ) async {
    await pumpGallery(
      tester,
      playlists: const AsyncData(_playlists),
      currentPlaylistId: 'playlist-2',
    );

    await tester.tap(find.byTooltip('下一个歌单'));
    await tester.pumpAndSettle();
    expect(find.byKey(playlistCenteredCardKey('playlist-3')), findsOneWidget);

    await tester.tap(find.byTooltip('上一个歌单'));
    await tester.pumpAndSettle();
    expect(find.byKey(playlistCenteredCardKey('playlist-2')), findsOneWidget);
    expect(find.text('左右滑动切换'), findsNothing);
  });

  testWidgets('only the centered card exposes its playlist play action', (
    tester,
  ) async {
    await pumpGallery(
      tester,
      playlists: const AsyncData(_playlists),
      currentPlaylistId: 'playlist-2',
    );

    expect(find.byTooltip('播放歌单 Night Highway'), findsOneWidget);
    expect(find.byTooltip('播放歌单 Morning Drive'), findsNothing);
    expect(find.byTooltip('播放歌单 Weekend'), findsNothing);
  });

  testWidgets('selects the centered playlist once while busy', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await pumpGallery(
      tester,
      playlists: const AsyncData(_playlists),
      currentPlaylistId: 'playlist-1',
      onSelect: (_) {
        calls++;
        return completer.future;
      },
    );

    final play = find.byTooltip('播放歌单 Morning Drive');
    await tester.tap(play);
    await tester.pump();
    await tester.tap(play, warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(playlistGalleryBusyKey), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });
}
