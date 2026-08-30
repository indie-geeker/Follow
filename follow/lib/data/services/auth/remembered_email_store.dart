import 'package:shared_preferences/shared_preferences.dart';

class RememberedEmailStore {
  RememberedEmailStore(this._preferences);

  final SharedPreferences _preferences;
  static const _rememberEmailKey = 'rememberEmail';
  static const _savedEmailKey = 'savedEmail';

  Future<void> migrateLegacyCredentials() async {
    final rememberedPassword =
        _preferences.getBool('rememberPassword') ?? false;
    final legacyEmail = _preferences.getString(_savedEmailKey)?.trim();
    if (rememberedPassword && legacyEmail != null && legacyEmail.isNotEmpty) {
      await _preferences.setBool(_rememberEmailKey, true);
      await _preferences.setString(_savedEmailKey, legacyEmail);
    } else if (!(_preferences.getBool(_rememberEmailKey) ?? false)) {
      await _preferences.remove(_savedEmailKey);
    }

    await _preferences.remove('rememberPassword');
    await _preferences.remove('savedPassword');
    await _preferences.remove('accessToken');
    await _preferences.remove('refreshToken');
  }

  Future<String?> read() async {
    if (!(_preferences.getBool(_rememberEmailKey) ?? false)) return null;
    return _preferences.getString(_savedEmailKey);
  }

  Future<void> save(String email) async {
    await _preferences.setBool(_rememberEmailKey, true);
    await _preferences.setString(_savedEmailKey, email.trim());
  }

  Future<void> clear() async {
    await _preferences.remove(_rememberEmailKey);
    await _preferences.remove(_savedEmailKey);
  }
}

Future<void> migrateLegacyAuthPreferences() async {
  final preferences = await SharedPreferences.getInstance();
  await RememberedEmailStore(preferences).migrateLegacyCredentials();
}
