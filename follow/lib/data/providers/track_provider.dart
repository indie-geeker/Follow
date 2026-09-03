import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/data/providers/search_debounce.dart';
import 'package:follow/data/services/api/api_service.dart';

part 'track_provider.g.dart';

/// Fetch all tracks with pagination
@riverpod
class TracksNotifier extends _$TracksNotifier {
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<Track>> build() async {
    _currentPage = 1;
    _hasMore = true;
    return _fetchTracks(page: 1);
  }

  Future<List<Track>> _fetchTracks({required int page}) async {
    final response = await ref.read(apiServiceProvider).getTracks(page: page);
    _currentPage = response.page;
    _hasMore = response.page < response.totalPages;
    return response.tracks;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    try {
      final nextPage = _currentPage + 1;
      final newTracks = await _fetchTracks(page: nextPage);
      final current = state.value ?? const <Track>[];
      state = AsyncValue.data([...current, ...newTracks]);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    _currentPage = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _fetchTracks(page: 1));
  }

  bool get hasMore => _hasMore;
}

/// Fetch user favorites
@Riverpod(keepAlive: true)
Future<List<Track>> favorites(ref) async {
  final apiService = ApiService();
  return await apiService.getFavorites();
}

/// Search tracks
@riverpod
class SearchTracks extends _$SearchTracks {
  @override
  Future<List<Track>> build(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];
    if (!await waitForSearchDebounce(ref)) return [];

    final response = await ref
        .read(apiServiceProvider)
        .getTracks(search: normalizedQuery);
    return response.tracks;
  }
}

@riverpod
Future<List<Track>> albumTracks(ref, String albumId) async {
  final apiService = ApiService();
  final response = await apiService.getTracks(albumId: albumId, pageSize: 100);
  return response.tracks;
}

@riverpod
Future<List<Track>> artistTracks(ref, String artistId) async {
  final apiService = ApiService();
  final response = await apiService.getTracks(
    artistId: artistId,
    pageSize: 100,
  );
  return response.tracks;
}
