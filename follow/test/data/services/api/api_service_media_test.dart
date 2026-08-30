import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/services/api/api_service.dart';

void main() {
  final api = ApiService(dio: Dio(BaseOptions(baseUrl: 'https://music.home')));

  test('stream URLs stay on the configured API origin', () {
    expect(
      api.getStreamUrl('track id'),
      'https://music.home/api/tracks/track%20id/stream',
    );
  });

  test('stream URLs reject traversal and URL-shaped identifiers', () {
    for (final id in ['../private', 'folder/track', 'https://evil/track']) {
      expect(() => api.getStreamUrl(id), throwsFormatException, reason: id);
    }
  });

  test('an empty page contract has zero total pages', () {
    final response = TrackListResponse.fromJson({
      'tracks': <Map<String, dynamic>>[],
      'totalCount': 0,
      'page': 1,
      'pageSize': 20,
      'totalPages': 0,
    });

    expect(response.totalPages, 0);
  });

  test('track pagination rejects values outside the server contract', () async {
    await expectLater(api.getTracks(page: 0), throwsA(isA<ArgumentError>()));
    await expectLater(
      api.getTracks(pageSize: 101),
      throwsA(isA<ArgumentError>()),
    );
  });
}
