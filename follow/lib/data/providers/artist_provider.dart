import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'artist_provider.g.dart';

@riverpod
class ArtistsNotifier extends _$ArtistsNotifier {
  final ApiService _apiService = ApiService();

  @override
  Future<List<Artist>> build() async {
    return _apiService.getArtists();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _apiService.getArtists());
  }
}

@riverpod
Future<Artist> artist(ref, String id) async {
  final apiService = ApiService();
  return apiService.getArtistById(id);
}
