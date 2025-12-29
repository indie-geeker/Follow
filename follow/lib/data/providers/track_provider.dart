import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/services/api/api_service.dart';

part 'track_provider.g.dart';

/// Fetch all tracks with pagination
@riverpod
class TracksNotifier extends _$TracksNotifier {
  final ApiService _apiService = ApiService();
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  Future<List<Track>> build() async {
    _currentPage = 1;
    _hasMore = true;
    return _fetchTracks();
  }

  Future<List<Track>> _fetchTracks() async {
    final response = await _apiService.getTracks(page: _currentPage);
    _hasMore = response.page < response.totalPages;
    return response.tracks;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    
    _currentPage++;
    final newTracks = await _fetchTracks();
    final current = state.value ?? [];
    state = AsyncValue.data([...current, ...newTracks]);
  }

  Future<void> refresh() async {
    _currentPage = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetchTracks());
  }

  bool get hasMore => _hasMore;
}

/// Fetch user favorites
@riverpod
Future<List<Track>> favorites(ref) async {
  final apiService = ApiService();
  return await apiService.getFavorites();
}

/// Search tracks
@riverpod
class SearchTracks extends _$SearchTracks {
  @override
  Future<List<Track>> build(String query) async {
    if (query.isEmpty) return [];
    
    final apiService = ApiService();
    final response = await apiService.getTracks(search: query);
    return response.tracks;
  }
}
