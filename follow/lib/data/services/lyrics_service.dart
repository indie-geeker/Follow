import 'package:dio/dio.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/core/network/media_url.dart';

class LyricsFormatException implements Exception {
  final String message;

  const LyricsFormatException(this.message);

  @override
  String toString() => 'LyricsFormatException: $message';
}

class LyricsService {
  final Dio _dio;

  LyricsService({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<List<LyricLine>> fetchLyrics(String trackId) async {
    final url = resolveTrackLyricsUri(trackId).toString();
    final response = await _dio.get(url);
    final content = response.data is String
        ? response.data as String
        : response.data.toString();
    final lyrics = parseLrc(content);
    if (lyrics.isEmpty) {
      throw const LyricsFormatException('未找到带时间戳的歌词');
    }
    return lyrics;
  }

  List<LyricLine> parseLrc(String lrcContent) {
    final lines = <LyricLine>[];
    // Match [mm:ss.xx] or [mm:ss.xxx] format
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3)!;
        final millis = int.parse(millisStr.padRight(3, '0'));
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          lines.add(
            LyricLine(
              timestamp: Duration(
                minutes: minutes,
                seconds: seconds,
                milliseconds: millis,
              ),
              text: text,
            ),
          );
        }
      }
    }

    // Sort by timestamp while preserving source order for equal timestamps.
    final indexedLines = lines.asMap().entries.toList()
      ..sort((a, b) {
        final timestampComparison = a.value.timestamp.compareTo(
          b.value.timestamp,
        );
        return timestampComparison != 0
            ? timestampComparison
            : a.key.compareTo(b.key);
      });
    return indexedLines.map((entry) => entry.value).toList();
  }
}
