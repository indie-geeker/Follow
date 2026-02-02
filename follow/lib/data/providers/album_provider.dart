import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'album_provider.g.dart';

@riverpod
class AlbumsNotifier extends _$AlbumsNotifier {
  final ApiService _apiService = ApiService();

  @override
  Future<List<Album>> build() async {
    return _apiService.getAlbums();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _apiService.getAlbums());
  }
}

@riverpod
Future<Album> album(ref, String id) async {
  final apiService = ApiService();
  return apiService.getAlbumById(id);
}
