import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/services/api/api_service.dart';

void main() {
  test('waits for typing to settle before searching', () async {
    final api = _RecordingTrackApi();
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final provider = searchTracksProvider('aurora');
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(api.requestedSearches, isEmpty);

    await container.read(provider.future);
    expect(api.requestedSearches, ['aurora']);
  });

  test('disposes an obsolete query before it reaches the API', () async {
    final api = _RecordingTrackApi();
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final obsolete = container.listen(searchTracksProvider('a'), (_, __) {});
    await Future<void>.delayed(Duration.zero);
    obsolete.close();
    await Future<void>.delayed(Duration.zero);

    final currentProvider = searchTracksProvider('aurora');
    final current = container.listen(currentProvider, (_, __) {});
    addTearDown(current.close);
    await container.read(currentProvider.future);

    expect(api.requestedSearches, ['aurora']);
  });
}

class _RecordingTrackApi extends ApiService {
  _RecordingTrackApi() : super(dio: Dio());

  final requestedSearches = <String>[];

  @override
  Future<TrackListResponse> getTracks({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? artistId,
    String? albumId,
  }) async {
    if (search != null) requestedSearches.add(search);
    return TrackListResponse(
      tracks: const [],
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      totalPages: 0,
    );
  }
}
