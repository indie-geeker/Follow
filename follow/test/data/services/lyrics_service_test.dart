import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/lyric_line.dart';
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
    expect(lyrics.every((line) => line.segments.isEmpty), isTrue);
  });

  test('parses enhanced LRC segments without inventing timing', () {
    final lyric = LyricsService()
        .parseLrc('[00:12.00]<00:12.00>我<00:12.30>爱<00:12.550>你')
        .single;

    expect(lyric.text, '我爱你');
    expect(lyric.segments, [
      const LyricSegment(timestamp: Duration(seconds: 12), text: '我'),
      const LyricSegment(timestamp: Duration(milliseconds: 12300), text: '爱'),
      const LyricSegment(timestamp: Duration(milliseconds: 12550), text: '你'),
    ]);
  });

  test('preserves spaces supplied by enhanced English lyrics', () {
    final lyric = LyricsService()
        .parseLrc('[00:01.00]<00:01.00>Hello <00:01.50>world<00:02.00>!')
        .single;

    expect(lyric.text, 'Hello world!');
    expect(lyric.segments.map((segment) => segment.text), [
      'Hello ',
      'world',
      '!',
    ]);
  });

  test('allows ordinary and enhanced lyric lines to coexist', () {
    final lyrics = LyricsService().parseLrc(
      '[00:01.00]ordinary\n'
      '[00:02.00]<00:02.00>逐<00:02.20>字',
    );

    expect(lyrics[0].text, 'ordinary');
    expect(lyrics[0].segments, isEmpty);
    expect(lyrics[1].text, '逐字');
    expect(lyrics[1].segments, hasLength(2));
  });

  test('falls back when text appears before the first inline timestamp', () {
    final lyric = LyricsService().parseLrc('[00:12.00]前缀<00:12.20>正文').single;

    expect(lyric.text, '前缀正文');
    expect(lyric.segments, isEmpty);
  });

  test('falls back when inline timestamps decrease', () {
    final lyric = LyricsService()
        .parseLrc('[00:12.00]<00:12.50>先<00:12.20>后')
        .single;

    expect(lyric.text, '先后');
    expect(lyric.segments, isEmpty);
  });

  test('falls back when an inline timed segment is empty', () {
    final lyric = LyricsService()
        .parseLrc('[00:12.00]<00:12.00><00:12.20>文字')
        .single;

    expect(lyric.text, '文字');
    expect(lyric.segments, isEmpty);
  });

  test(
    'sorts lyrics chronologically while preserving duplicate timestamp order',
    () {
      final service = LyricsService();
      final sourceOrderAtTenSeconds = List.generate(
        40,
        (index) => 'duplicate-$index',
      );
      final input = <String>[
        '[00:20.00]later',
        ...sourceOrderAtTenSeconds.map((text) => '[00:10.00]$text'),
        '[00:05.00]earlier',
      ].join('\n');

      final lyrics = service.parseLrc(input);

      expect(lyrics.first.text, 'earlier');
      expect(
        lyrics
            .where((line) => line.timestamp == const Duration(seconds: 10))
            .map((line) => line.text),
        sourceOrderAtTenSeconds,
      );
      expect(lyrics.last.text, 'later');
    },
  );

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
