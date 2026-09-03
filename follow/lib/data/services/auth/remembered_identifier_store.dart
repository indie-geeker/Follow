import 'package:shared_preferences/shared_preferences.dart';

class RememberedIdentifierStore {
  RememberedIdentifierStore(this._preferences);

  final SharedPreferences _preferences;
  static const _rememberIdentifierKey = 'rememberIdentifier';
  static const _savedIdentifierKey = 'savedIdentifier';
  static const _legacyRememberEmailKey = 'rememberEmail';
  static const _legacySavedEmailKey = 'savedEmail';

  Future<void> migrateLegacyCredentials() async {
    final identifier =
        _preferences.getString(_savedIdentifierKey)?.trim() ??
        _preferences.getString(_legacySavedEmailKey)?.trim();
    final shouldRemember =
        (_preferences.getBool(_rememberIdentifierKey) ?? false) ||
        (_preferences.getBool(_legacyRememberEmailKey) ?? false) ||
        (_preferences.getBool('rememberPassword') ?? false);

    if (shouldRemember && identifier != null && identifier.isNotEmpty) {
      await _preferences.setBool(_rememberIdentifierKey, true);
      await _preferences.setString(_savedIdentifierKey, identifier);
    } else {
      await _preferences.remove(_rememberIdentifierKey);
      await _preferences.remove(_savedIdentifierKey);
    }

    await _preferences.remove(_legacyRememberEmailKey);
    await _preferences.remove(_legacySavedEmailKey);
    await _preferences.remove('rememberPassword');
    await _preferences.remove('savedPassword');
    await _preferences.remove('accessToken');
    await _preferences.remove('refreshToken');
  }

  Future<String?> read() async {
    if (!(_preferences.getBool(_rememberIdentifierKey) ?? false)) return null;
    return _preferences.getString(_savedIdentifierKey);
  }

  Future<void> save(String identifier) async {
    await _preferences.setBool(_rememberIdentifierKey, true);
    await _preferences.setString(_savedIdentifierKey, identifier.trim());
  }

  Future<void> clear() async {
    await _preferences.remove(_rememberIdentifierKey);
    await _preferences.remove(_savedIdentifierKey);
    await _preferences.remove(_legacyRememberEmailKey);
    await _preferences.remove(_legacySavedEmailKey);
  }
}

Future<void> migrateLegacyAuthPreferences() async {
  final preferences = await SharedPreferences.getInstance();
  await RememberedIdentifierStore(preferences).migrateLegacyCredentials();
}
