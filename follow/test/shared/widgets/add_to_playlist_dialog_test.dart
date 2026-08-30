import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/playlist_provider.dart';
import 'package:follow/shared/widgets/add_to_playlist_dialog.dart';

class _FakePlaylists extends Playlists {
  @override
  Future<List<Playlist>> build() async => const [];
}

void main() {
  testWidgets('opens the shared create dialog from add to playlist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playlistsProvider.overrideWith(_FakePlaylists.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AddToPlaylistDialog(
              track: Track(id: 'track-1', title: 'Moonlight'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-playlist-from-add-dialog')),
      findsOneWidget,
    );
    expect(find.byTooltip('关闭'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('关闭')).shortestSide,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(
      find.byKey(const ValueKey('create-playlist-from-add-dialog')),
    );
    await tester.pumpAndSettle();

    expect(find.text('为喜欢的音乐留一个专属位置'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-playlist-name')), findsOneWidget);
  });
}
