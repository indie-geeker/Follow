import 'package:flutter/foundation.dart';
import 'package:follow/core/config/app_config.dart';

Uri? resolveCoverUri(String? coverUrl, {String? apiBaseUrl}) {
  final value = coverUrl?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  if (value.startsWith('/') || value.startsWith(r'\')) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null || parsed.hasScheme || parsed.hasAuthority) return null;
  if (parsed.hasQuery || parsed.hasFragment || value.contains(r'\')) {
    return null;
  }

  final segments = value.split('/');
  if (!_areSafePathSegments(segments)) return null;
  if (!const {'covers', 'artists', 'albums'}.contains(segments.first)) {
    return null;
  }

  return _sameOriginApiUri([
    'api',
    'tracks',
    'cover',
    ...segments,
  ], apiBaseUrl: apiBaseUrl);
}

Uri resolveTrackStreamUri(String trackId, {String? apiBaseUrl}) {
  return _trackMediaUri(trackId, 'stream', apiBaseUrl: apiBaseUrl);
}

Uri resolveTrackLyricsUri(String trackId, {String? apiBaseUrl}) {
  return _trackMediaUri(trackId, 'lyrics', apiBaseUrl: apiBaseUrl);
}

Uri _trackMediaUri(String trackId, String action, {String? apiBaseUrl}) {
  final id = trackId.trim();
  if (!_areSafePathSegments([id])) {
    throw const FormatException('Invalid track identifier.');
  }
  final parsed = Uri.tryParse(id);
  if (parsed == null ||
      parsed.hasScheme ||
      parsed.hasAuthority ||
      parsed.hasQuery ||
      parsed.hasFragment) {
    throw const FormatException('Invalid track identifier.');
  }
  return _sameOriginApiUri([
    'api',
    'tracks',
    id,
    action,
  ], apiBaseUrl: apiBaseUrl);
}

bool _areSafePathSegments(List<String> segments) {
  return segments.isNotEmpty &&
      segments.every(
        (segment) =>
            segment.isNotEmpty &&
            segment != '.' &&
            segment != '..' &&
            !segment.contains('/') &&
            !segment.contains(r'\') &&
            !segment.contains(RegExp(r'[\x00-\x1f\x7f]')),
      );
}

Uri _sameOriginApiUri(List<String> pathSegments, {String? apiBaseUrl}) {
  final base = resolveApiBaseUri(
    apiBaseUrl ?? AppConfig.apiBaseUrl,
    isDebug: kDebugMode,
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  );
  return base.replace(pathSegments: pathSegments, query: null, fragment: null);
}
