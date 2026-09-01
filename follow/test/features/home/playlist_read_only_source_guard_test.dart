import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-owner public playlists do not expose write callbacks', () {
    final view = File(
      'lib/features/home/views/playlist_view.dart',
    ).readAsStringSync();
    final addDialog = File(
      'lib/shared/widgets/add_to_playlist_dialog.dart',
    ).readAsStringSync();
    final smartTrackTile = File(
      'lib/shared/widgets/smart_track_tile.dart',
    ).readAsStringSync();

    expect(view, contains('playlist.canEdit'));
    expect(view, contains('onRemoveFromList: playlist.canEdit'));
    expect(view, contains('sourcePlaylistId: playlistId'));
    expect(addDialog, contains('where((playlist) => playlist.canEdit)'));
    expect(smartTrackTile, contains('sourcePlaylistId'));
    expect(smartTrackTile, contains('.playPlaylist('));
  });
}
