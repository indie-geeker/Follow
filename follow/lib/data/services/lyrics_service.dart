import 'package:dio/dio.dart';
import 'package:follow/data/models/lyric_line.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/core/config/app_config.dart';

class LyricsService {
  final Dio _dio;

  LyricsService() : _dio = ApiClient.instance;

  Future<List<LyricLine>> fetchLyrics(String lyricsUrl) async {
    try {
      final url = lyricsUrl.startsWith('http')
          ? lyricsUrl
          : '${AppConfig.apiBaseUrl}/api/tracks/lyrics/${Uri.encodeComponent(lyricsUrl)}';

      final response = await _dio.get(url);
      final content = response.data is String ? response.data : response.data.toString();
      return parseLrc(content);
    } catch (e) {
      return [];
    }
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
          lines.add(LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
          ));
        }
      }
    }

    // Sort by timestamp
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
