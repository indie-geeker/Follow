import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/track.dart';
import 'package:follow/data/providers/api_provider.dart';
import 'package:follow/data/providers/track_provider.dart';
import 'package:follow/data/services/api/api_service.dart';

void main() {
  test('loads stable pages once and appends them in order', () async {
    final api = _PagedTrackApi();
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(tracksProvider, (_, __) {});
    addTearDown(subscription.close);

    expect((await container.read(tracksProvider.future)).map((t) => t.id), [
      'track-1',
    ]);

    await Future.wait([
      container.read(tracksProvider.notifier).loadMore(),
      container.read(tracksProvider.notifier).loadMore(),
    ]);

    expect(container.read(tracksProvider).value?.map((t) => t.id), [
      'track-1',
      'track-2',
    ]);
    expect(api.requestedPages, [1, 2]);
    expect(container.read(tracksProvider.notifier).hasMore, isFalse);
  });
}

class _PagedTrackApi extends ApiService {
  _PagedTrackApi() : super(dio: Dio());

  final requestedPages = <int>[];

  @override
  Future<TrackListResponse> getTracks({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? artistId,
    String? albumId,
  }) async {
    requestedPages.add(page);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return TrackListResponse(
      tracks: [Track(id: 'track-$page', title: 'Track $page')],
      totalCount: 2,
      page: page,
      pageSize: pageSize,
      totalPages: 2,
    );
  }
}
