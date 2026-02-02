import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';

part 'playlist_provider.g.dart';

@riverpod
class Playlists extends _$Playlists {
  final _apiService = ApiService();

  @override
  Future<List<Playlist>> build() async {
    return _apiService.getPlaylists();
  }

  Future<void> create(String name) async {
    await _apiService.createPlaylist(name);
    ref.invalidateSelf();
  }

  Future<void> addTrack(String playlistId, String trackId) async {
    await _apiService.addTrackToPlaylist(playlistId, trackId);
    // Optionally invalidate specific playlist detail if needed, but not strictly necessary for the list
  }
}

@Riverpod(keepAlive: true)
Future<PlaylistDetail> playlistDetail(ref, String id) async {
  final apiService = ApiService();
  return apiService.getPlaylistById(id);
}
