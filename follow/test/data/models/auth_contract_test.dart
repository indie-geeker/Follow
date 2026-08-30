import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/user.dart';

void main() {
  test('login requests body tokens and identifies the device', () {
    const request = LoginRequest(
      email: 'family@example.com',
      password: 'secret',
      tokenTransport: 'body',
      deviceName: 'Android',
    );

    expect(request.toJson(), {
      'email': 'family@example.com',
      'password': 'secret',
      'tokenTransport': 'body',
      'deviceName': 'Android',
    });
  });

  test('registration requests body tokens and identifies the device', () {
    const request = RegisterRequest(
      username: 'family',
      email: 'family@example.com',
      password: 'secret',
      tokenTransport: 'body',
      deviceName: 'Mac',
    );

    expect(request.toJson(), {
      'username': 'family',
      'email': 'family@example.com',
      'password': 'secret',
      'tokenTransport': 'body',
      'deviceName': 'Mac',
    });
  });

  test('auth response parses the server session contract', () {
    final response = AuthResponse.fromJson({
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'sessionId': '11111111-1111-1111-1111-111111111111',
      'expiresAt': '2026-07-27T12:00:00.000Z',
      'user': {
        'id': '22222222-2222-2222-2222-222222222222',
        'username': 'family',
        'email': 'family@example.com',
        'role': 'User',
      },
    });

    expect(response.sessionId, '11111111-1111-1111-1111-111111111111');
    expect(response.expiresAt, DateTime.utc(2026, 7, 27, 12));
  });

  test('session info parses current-device metadata', () {
    final session = SessionInfo.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'deviceName': 'Family iPhone',
      'clientType': 'Flutter',
      'createdAt': '2026-07-26T10:00:00.000Z',
      'lastUsedAt': '2026-07-26T11:00:00.000Z',
      'expiresAt': '2026-08-25T10:00:00.000Z',
      'isCurrent': true,
    });

    expect(session.deviceName, 'Family iPhone');
    expect(session.isCurrent, isTrue);
  });
}
