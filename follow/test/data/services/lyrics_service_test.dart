import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/services/lyrics_service.dart';

Dio _dioRespondingWith(Object data, {int statusCode = 200}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final response = Response<Object>(
          requestOptions: options,
          statusCode: statusCode,
          data: data,
        );
        if (statusCode >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(response);
      },
    ),
  );
  return dio;
}

void main() {
  test('returns timed lines for a valid LRC response', () async {
    final service = LyricsService(
      dio: _dioRespondingWith('[00:01.20]第一行\n[00:02.250]第二行'),
    );

    final lyrics = await service.fetchLyrics('track-1');

    expect(lyrics.map((line) => line.text), ['第一行', '第二行']);
    expect(lyrics[0].timestamp, const Duration(milliseconds: 1200));
    expect(lyrics[1].timestamp, const Duration(milliseconds: 2250));
  });

  test('propagates a 404 for a referenced lyric object', () async {
    final service = LyricsService(
      dio: _dioRespondingWith('not found', statusCode: 404),
    );

    await expectLater(
      service.fetchLyrics('track-1'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status code',
          404,
        ),
      ),
    );
  });

  test('throws LyricsFormatException when no timed line exists', () async {
    final service = LyricsService(
      dio: _dioRespondingWith('plain text without timestamps'),
    );

    await expectLater(
      service.fetchLyrics('track-1'),
      throwsA(isA<LyricsFormatException>()),
    );
  });
}
