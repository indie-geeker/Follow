/// App configuration
class AppConfig {
  static const String appName = 'Follow Music';
  static const String appVersion = '0.1.0';
  
  /// API base URL - can be overridden by environment
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    return envUrl.isNotEmpty ? envUrl : 'http://localhost:5000';
  }
  
  /// Default timeout for API requests
  static const Duration apiTimeout = Duration(seconds: 30);
  
  /// Supported locales
  static const List<String> supportedLocales = ['en', 'zh'];
  static const String defaultLocale = 'zh';
}
