import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';

void main() {
  test('playlist list items parse owner and edit capability', () {
    final playlist = Playlist.fromJson({
      'id': 'playlist-id',
      'name': 'Family Mix',
      'isPublic': true,
      'trackCount': 2,
      'createdAt': '2026-07-26T10:00:00.000Z',
      'ownerId': 'owner-id',
      'ownerName': 'Parent',
      'isOwnedByCurrentUser': false,
      'canEdit': false,
    });

    expect(playlist.ownerId, 'owner-id');
    expect(playlist.ownerName, 'Parent');
    expect(playlist.isOwnedByCurrentUser, isFalse);
    expect(playlist.canEdit, isFalse);
  });

  test('public playlist details remain read-only for non-owners', () {
    final playlist = PlaylistDetail.fromJson({
      'id': 'playlist-id',
      'name': 'Shared Family Mix',
      'isPublic': true,
      'tracks': <Map<String, dynamic>>[],
      'createdAt': '2026-07-26T10:00:00.000Z',
      'ownerId': 'owner-id',
      'ownerName': 'Parent',
      'isOwnedByCurrentUser': false,
      'canEdit': false,
    });

    expect(playlist.isPublic, isTrue);
    expect(playlist.canEdit, isFalse);
    expect(playlist.ownerName, 'Parent');
  });
}
