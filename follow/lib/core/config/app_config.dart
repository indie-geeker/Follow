import 'package:flutter/foundation.dart';

Uri resolveApiBaseUri(
  String configuredUrl, {
  required bool isDebug,
  bool isAndroid = false,
}) {
  final uri = Uri.tryParse(configuredUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw StateError('The Follow API gateway must be an absolute origin.');
  }

  final scheme = uri.scheme.toLowerCase();
  final isAllowedLocalDebugOrigin =
      isDebug &&
      scheme == 'http' &&
      uri.port == 5050 &&
      (isAndroid
          ? uri.host == '10.0.2.2'
          : uri.host == 'localhost' ||
                uri.host == '127.0.0.1' ||
                uri.host == '::1');
  if (scheme != 'https' && !isAllowedLocalDebugOrigin) {
    throw StateError(
      'The Follow API origin must use HTTPS outside approved local debug '
      'addresses.',
    );
  }

  final hasOnlyOriginPath = uri.path.isEmpty || uri.path == '/';
  if (uri.userInfo.isNotEmpty ||
      !hasOnlyOriginPath ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw StateError(
      'The Follow API gateway must not contain credentials, a path, query, '
      'or fragment.',
    );
  }

  return uri.replace(path: '', query: null, fragment: null);
}

/// App configuration
class AppConfig {
  static const String appName = 'Follow Music';
  static const String appVersion = '0.1.0';

  /// API base URL - can be overridden by environment
  static Uri get apiBaseUri {
    const envUrl = String.fromEnvironment('API_URL');
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final configuredUrl = envUrl.isNotEmpty
        ? envUrl
        : kDebugMode
        ? isAndroid
              ? 'http://10.0.2.2:5050'
              : 'http://localhost:5050'
        : 'https://localhost';
    return resolveApiBaseUri(
      configuredUrl,
      isDebug: kDebugMode,
      isAndroid: isAndroid,
    );
  }

  static String get apiBaseUrl => apiBaseUri.toString();

  /// Default timeout for API requests
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Supported locales
  static const List<String> supportedLocales = ['en', 'zh'];
  static const String defaultLocale = 'zh';
}
