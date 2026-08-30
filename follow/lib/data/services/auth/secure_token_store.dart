import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenPair {
  const AuthTokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.sessionId,
  });

  final String accessToken;
  final String refreshToken;
  final String? sessionId;

  @override
  bool operator ==(Object other) =>
      other is AuthTokenPair &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, sessionId);
}

abstract interface class TokenStore {
  Future<AuthTokenPair?> readTokens();

  Future<void> writeTokens(AuthTokenPair tokens);

  Future<void> clearTokens();

  Future<String> getOrCreateDeviceId();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokensKey = 'follow.auth.tokens.v1';
  static const _deviceIdKey = 'follow.auth.device-id.v1';

  @override
  Future<AuthTokenPair?> readTokens() async {
    final encoded = await _storage.read(key: _tokensKey);
    if (encoded == null) return null;

    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final accessToken = json['accessToken'];
      final refreshToken = json['refreshToken'];
      if (accessToken is! String ||
          accessToken.isEmpty ||
          refreshToken is! String ||
          refreshToken.isEmpty) {
        throw const FormatException('Secure auth tokens are incomplete.');
      }
      return AuthTokenPair(
        accessToken: accessToken,
        refreshToken: refreshToken,
        sessionId: json['sessionId'] as String?,
      );
    } on Object {
      await _storage.delete(key: _tokensKey);
      return null;
    }
  }

  @override
  Future<void> writeTokens(AuthTokenPair tokens) {
    return _storage.write(
      key: _tokensKey,
      value: jsonEncode({
        'accessToken': tokens.accessToken,
        'refreshToken': tokens.refreshToken,
        if (tokens.sessionId != null) 'sessionId': tokens.sessionId,
      }),
    );
  }

  @override
  Future<void> clearTokens() => _storage.delete(key: _tokensKey);

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final deviceId = base64UrlEncode(bytes).replaceAll('=', '');
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }
}
