import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'l10n.g.dart';

/// Supported locales
class AppLocalizations {
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  final Locale locale;
  AppLocalizations(this.locale);

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'home': 'Home',
      'library': 'Library',
      'search': 'Search',
      'downloads': 'Downloads',
      'settings': 'Settings',
      'recentlyPlayed': 'Recently Played',
      'favorites': 'Favorites',
      'tracks': 'Tracks',
      'artists': 'Artists',
      'albums': 'Albums',
      'playlists': 'Playlists',
      'nowPlaying': 'Now Playing',
      'lyrics': 'Lyrics',
      'noLyrics': 'No lyrics available',
      'downloading': 'Downloading',
      'downloaded': 'Downloaded',
      'download': 'Download',
      'delete': 'Delete',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'language': 'Language',
      'account': 'Account',
      'logout': 'Logout',
      'storage': 'Storage',
      'clearCache': 'Clear Cache',
      'login': 'Login',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'username': 'Username',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'error': 'Error',
      'loading': 'Loading...',
      'noData': 'No data',
      'retry': 'Retry',
      'rememberPassword': 'Remember Password',
    },
    'zh': {
      'home': '首页',
      'library': '音乐库',
      'search': '搜索',
      'downloads': '下载',
      'settings': '设置',
      'recentlyPlayed': '最近播放',
      'favorites': '我的收藏',
      'tracks': '曲目',
      'artists': '艺术家',
      'albums': '专辑',
      'playlists': '播放列表',
      'nowPlaying': '正在播放',
      'lyrics': '歌词',
      'noLyrics': '暂无歌词',
      'downloading': '下载中',
      'downloaded': '已下载',
      'download': '下载',
      'delete': '删除',
      'appearance': '外观',
      'theme': '主题',
      'light': '浅色',
      'dark': '深色',
      'system': '跟随系统',
      'language': '语言',
      'account': '账户',
      'logout': '退出登录',
      'storage': '存储',
      'clearCache': '清除缓存',
      'login': '登录',
      'register': '注册',
      'email': '邮箱',
      'password': '密码',
      'username': '用户名',
      'cancel': '取消',
      'confirm': '确认',
      'save': '保存',
      'error': '错误',
      'loading': '加载中...',
      'noData': '暂无数据',
      'retry': '重试',
      'rememberPassword': '记住密码',
    },
  };

  String get(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  String get home => get('home');
  String get library => get('library');
  String get search => get('search');
  String get downloads => get('downloads');
  String get settings => get('settings');
  String get tracks => get('tracks');
  String get artists => get('artists');
  String get albums => get('albums');
  String get playlists => get('playlists');
  String get login => get('login');
  String get logout => get('logout');
  String get theme => get('theme');
  String get language => get('language');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Locale provider with persistence
@riverpod
class AppLocale extends _$AppLocale {
  static const _key = 'locale';

  @override
  Locale build() {
    _loadLocale();
    return const Locale('zh', 'CN');
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key) ?? 'zh';
    state = stored == 'en' ? const Locale('en', 'US') : const Locale('zh', 'CN');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  void toggleLocale() {
    if (state.languageCode == 'zh') {
      setLocale(const Locale('en', 'US'));
    } else {
      setLocale(const Locale('zh', 'CN'));
    }
  }
}
