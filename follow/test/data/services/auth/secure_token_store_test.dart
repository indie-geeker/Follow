import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/services/auth/secure_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('writes and reads an auth token pair as one secure value', () async {
    final store = SecureTokenStore();
    const tokens = AuthTokenPair(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      sessionId: 'session-id',
    );

    await store.writeTokens(tokens);

    expect(await store.readTokens(), tokens);
  });

  test('clears tokens without deleting the installation device id', () async {
    final store = SecureTokenStore();
    const tokens = AuthTokenPair(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
    await store.writeTokens(tokens);
    final deviceId = await store.getOrCreateDeviceId();

    await store.clearTokens();

    expect(await store.readTokens(), isNull);
    expect(await store.getOrCreateDeviceId(), deviceId);
  });

  test('fails closed and removes a malformed secure token value', () async {
    FlutterSecureStorage.setMockInitialValues({
      'follow.auth.tokens.v1': '{not-json',
    });
    final store = SecureTokenStore();

    expect(await store.readTokens(), isNull);
    expect(await store.readTokens(), isNull);
  });

  test('rejects empty credentials inside an otherwise valid value', () async {
    FlutterSecureStorage.setMockInitialValues({
      'follow.auth.tokens.v1':
          '{"accessToken":"","refreshToken":"refresh-token"}',
    });
    final store = SecureTokenStore();

    expect(await store.readTokens(), isNull);
  });
}
