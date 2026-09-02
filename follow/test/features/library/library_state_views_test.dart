import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:follow/core/l10n/l10n.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/album_provider.dart';
import 'package:follow/data/providers/artist_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/features/library/album_detail_page.dart';
import 'package:follow/features/library/artist_detail_page.dart';
import 'package:follow/features/library/library_page.dart';
import 'package:follow/features/library/widgets/albums_tab.dart';
import 'package:follow/features/library/widgets/artists_tab.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

void main() {
  testWidgets(
    'track library uses illustrated empty, loading and failure states',
    (tester) async {
      await _pumpLibrary(tester, _FakeTracks(() async => const []));
      _expectState(AppStateKind.emptyLibrary);

      final pending = Completer<List<Track>>();
      await _pumpLibrary(tester, _FakeTracks(() => pending.future));
      expect(find.byType(AppContentSkeleton), findsOneWidget);

      final failed = _FakeTracks(() async => throw StateError('offline'));
      await _pumpLibrary(tester, failed);
      await tester.pumpAndSettle();
      _expectState(AppStateKind.failure);
      await tester.tap(find.widgetWithText(FilledButton, '重试'));
      await tester.pump();
      expect(failed.refreshCount, 1);
    },
  );

  testWidgets('album and artist tabs use the shared library state contract', (
    tester,
  ) async {
    await _pump(tester, const AlbumsTab(), [
      albumsProvider.overrideWith(() => _FakeAlbums(() async => const [])),
    ]);
    _expectState(AppStateKind.emptyLibrary);

    await _pump(tester, const ArtistsTab(), [
      artistsProvider.overrideWith(() => _FakeArtists(() async => const [])),
    ]);
    _expectState(AppStateKind.emptyLibrary);
  });

  testWidgets('album detail uses shared states for its track collection', (
    tester,
  ) async {
    await _pump(tester, const AlbumDetailPage(id: 'album-1'), [
      albumProvider(
        'album-1',
      ).overrideWith((ref) async => const Album(id: 'album-1', title: 'Album')),
      albumTracksProvider(
        'album-1',
      ).overrideWith((ref) async => const <Track>[]),
    ]);
    await tester.pump();
    _expectState(AppStateKind.emptyLibrary);
  });

  testWidgets('artist detail uses shared failure state with retry', (
    tester,
  ) async {
    var attempts = 0;
    await _pump(tester, const ArtistDetailPage(id: 'artist-1'), [
      artistProvider('artist-1').overrideWith(
        (ref) async => const Artist(id: 'artist-1', name: 'Artist'),
      ),
      artistTracksProvider('artist-1').overrideWith((ref) async {
        attempts++;
        throw StateError('offline');
      }),
    ]);
    await tester.pumpAndSettle();
    _expectState(AppStateKind.failure);
    final beforeRetry = attempts;
    final retry = find.widgetWithText(FilledButton, '重试');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pump();
    expect(attempts, greaterThan(beforeRetry));
  });
}

class _FakeTracks extends TracksNotifier {
  _FakeTracks(this.loader);

  final Future<List<Track>> Function() loader;
  int refreshCount = 0;

  @override
  Future<List<Track>> build() => loader();

  @override
  bool get hasMore => false;

  @override
  Future<void> refresh() async {
    refreshCount++;
    state = const AsyncData([]);
  }
}

class _FakeAlbums extends AlbumsNotifier {
  _FakeAlbums(this.loader);

  final Future<List<Album>> Function() loader;

  @override
  Future<List<Album>> build() => loader();
}

class _FakeArtists extends ArtistsNotifier {
  _FakeArtists(this.loader);

  final Future<List<Artist>> Function() loader;

  @override
  Future<List<Artist>> build() => loader();
}

void _expectState(AppStateKind kind) {
  final view = find.byType(AppStateView);
  expect(view, findsOneWidget);
  expect(find.byType(SvgPicture), findsOneWidget);
  expect((view.evaluate().single.widget as AppStateView).kind, kind);
  expect(find.byIcon(Icons.error_outline), findsNothing);
}

Future<void> _pumpLibrary(WidgetTester tester, _FakeTracks tracks) =>
    _pump(tester, const LibraryPage(), [
      tracksProvider.overrideWith(() => tracks),
      albumsProvider.overrideWith(() => _FakeAlbums(() async => const [])),
      artistsProvider.overrideWith(() => _FakeArtists(() async => const [])),
    ]);

Future<void> _pump(WidgetTester tester, Widget child, dynamic overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
