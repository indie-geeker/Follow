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
  static final RegExp _lineTimestampPattern = RegExp(
    r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$',
  );
  static final RegExp _inlineTimestampPattern = RegExp(
    r'<(\d{2}):(\d{2})\.(\d{2,3})>',
  );

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

    for (final line in lrcContent.split('\n')) {
      final match = _lineTimestampPattern.firstMatch(line);
      if (match != null) {
        final timestamp = _parseTimestamp(match);
        final parsedText = _parseLyricText(match.group(4)!.trim());

        if (parsedText.text.isNotEmpty) {
          lines.add(
            LyricLine(
              timestamp: timestamp,
              text: parsedText.text,
              segments: parsedText.segments,
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

  Duration _parseTimestamp(Match match) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final milliseconds = int.parse(match.group(3)!.padRight(3, '0'));
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  _ParsedLyricText _parseLyricText(String source) {
    final matches = _inlineTimestampPattern.allMatches(source).toList();
    if (matches.isEmpty) {
      return _ParsedLyricText(source, const []);
    }

    final cleanText = source.replaceAll(_inlineTimestampPattern, '').trim();
    if (source.substring(0, matches.first.start).trim().isNotEmpty) {
      return _ParsedLyricText(cleanText, const []);
    }

    final segments = <LyricSegment>[];
    Duration? previousTimestamp;
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final timestamp = _parseTimestamp(match);
      final textEnd = index + 1 < matches.length
          ? matches[index + 1].start
          : source.length;
      final text = source.substring(match.end, textEnd);

      if (text.trim().isEmpty ||
          previousTimestamp != null && timestamp < previousTimestamp) {
        return _ParsedLyricText(cleanText, const []);
      }

      segments.add(LyricSegment(timestamp: timestamp, text: text));
      previousTimestamp = timestamp;
    }

    return _ParsedLyricText(cleanText, List.unmodifiable(segments));
  }
}

class _ParsedLyricText {
  const _ParsedLyricText(this.text, this.segments);

  final String text;
  final List<LyricSegment> segments;
}
