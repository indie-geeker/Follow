import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/history_provider.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/features/home/views/favorites_view.dart';
import 'package:follow/features/home/views/playlist_view.dart';
import 'package:follow/features/home/views/recently_played_view.dart';
import 'package:follow/shared/widgets/loading/app_content_skeleton.dart';
import 'package:follow/shared/widgets/play_all_tile.dart';
import 'package:follow/shared/widgets/smart_track_tile.dart';
import 'package:follow/shared/widgets/states/app_state_kind.dart';
import 'package:follow/shared/widgets/states/app_state_view.dart';

void main() {
  testWidgets('home empty states use distinct illustrated variants', (
    tester,
  ) async {
    await _pump(tester, const FavoritesView(), [
      favoritesProvider.overrideWith((ref) async => const <Track>[]),
    ]);
    _expectState(AppStateKind.emptyLibrary);

    await _pump(tester, const PlaylistView(playlistId: 'playlist-1'), [
      playlistDetailProvider('playlist-1').overrideWith(
        (ref) async =>
            const PlaylistDetail(id: 'playlist-1', name: '空歌单', canEdit: true),
      ),
    ]);
    _expectState(AppStateKind.emptyPlaylist);

    var browsed = false;
    await _pump(
      tester,
      RecentlyPlayedView(onBrowseLibrary: () => browsed = true),
      [historyProvider.overrideWith((ref) async => const <Track>[])],
    );
    _expectState(AppStateKind.nothingPlaying);
    await tester.tap(find.widgetWithText(FilledButton, '进入音乐库'));
    expect(browsed, isTrue);
  });

  testWidgets('home loading uses geometry skeletons', (tester) async {
    final pending = Completer<List<Track>>();
    await _pump(tester, const FavoritesView(), [
      favoritesProvider.overrideWith((ref) => pending.future),
    ]);

    expect(find.byType(AppContentSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('home failure retries the same provider', (tester) async {
    var attempts = 0;
    await _pump(tester, const FavoritesView(), [
      favoritesProvider.overrideWith((ref) async {
        attempts++;
        throw StateError('offline');
      }),
    ]);
    await tester.pumpAndSettle();

    _expectState(AppStateKind.failure);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    final beforeRetry = attempts;
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pump();
    expect(attempts, greaterThan(beforeRetry));
  });

  testWidgets('non-empty favorites keep list and play-all behavior surfaces', (
    tester,
  ) async {
    await _pump(tester, const FavoritesView(), [
      favoritesProvider.overrideWith((ref) async => const [_track]),
    ]);

    expect(find.byType(PlayAllTile), findsOneWidget);
    expect(find.byType(SmartTrackTile), findsOneWidget);
  });
}

void _expectState(AppStateKind kind) {
  final view = find.byType(AppStateView);
  expect(view, findsOneWidget);
  expect(find.byType(SvgPicture), findsOneWidget);
  expect((view.evaluate().single.widget as AppStateView).kind, kind);
}

Future<void> _pump(WidgetTester tester, Widget child, dynamic overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

const _track = Track(id: 'track-1', title: 'Song');
