import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/user.dart';
import 'package:follow/data/services/api/api_service.dart';
import 'package:follow/data/services/auth/auth_repository.dart';
import 'package:follow/data/services/auth/secure_token_store.dart';

void main() {
  test(
    'login requests body tokens and atomically stores the returned session',
    () async {
      final api = _FakeAuthApi();
      final tokenStore = _MemoryTokenStore();
      final repository = AuthRepository(
        api: api,
        tokenStore: tokenStore,
        deviceName: 'Follow Android',
      );

      final user = await repository.login('family', 'secret');

      expect(user.email, 'family@example.com');
      expect(api.loginRequest?.identifier, 'family');
      expect(api.loginRequest?.tokenTransport, 'body');
      expect(api.loginRequest?.deviceName, 'Follow Android');
      expect(
        tokenStore.tokens,
        const AuthTokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          sessionId: 'session-id',
        ),
      );
    },
  );

  test('registration requests body tokens and identifies the device', () async {
    final api = _FakeAuthApi();
    final tokenStore = _MemoryTokenStore();
    final repository = AuthRepository(
      api: api,
      tokenStore: tokenStore,
      deviceName: 'Follow Mac',
    );

    await repository.register('family', 'family@example.com', 'secret');

    expect(api.registerRequest?.tokenTransport, 'body');
    expect(api.registerRequest?.deviceName, 'Follow Mac');
  });

  test(
    'logout calls the server before clearing tokens and account state',
    () async {
      final events = <String>[];
      final api = _FakeAuthApi(events: events);
      final tokenStore = _MemoryTokenStore(events: events)
        ..tokens = const AuthTokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
      final repository = AuthRepository(
        api: api,
        tokenStore: tokenStore,
        deviceName: 'Follow Android',
        clearAccountState: () async => events.add('account-state-cleared'),
      );

      final serverRevoked = await repository.logout();

      expect(serverRevoked, isTrue);
      expect(events, [
        'server-logout',
        'tokens-cleared',
        'account-state-cleared',
      ]);
    },
  );

  test(
    'logout preserves the local session when server revocation fails',
    () async {
      final events = <String>[];
      final api = _FakeAuthApi(events: events, failLogout: true);
      final tokenStore = _MemoryTokenStore(events: events)
        ..tokens = const AuthTokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
      final repository = AuthRepository(
        api: api,
        tokenStore: tokenStore,
        deviceName: 'Follow Android',
        clearAccountState: () async => events.add('account-state-cleared'),
      );

      final serverRevoked = await repository.logout();

      expect(serverRevoked, isFalse);
      expect(tokenStore.tokens, isNotNull);
      expect(events, ['server-logout']);
    },
  );

  test(
    'logout completes locally when the interceptor rejects the session',
    () async {
      final events = <String>[];
      final tokenStore = _MemoryTokenStore(events: events)
        ..tokens = const AuthTokenPair(
          accessToken: 'expired-access-token',
          refreshToken: 'rejected-refresh-token',
        );
      final api = _FakeAuthApi(
        events: events,
        logoutError: _dioError(statusCode: 401),
        beforeLogoutError: tokenStore.clearTokens,
      );
      final repository = AuthRepository(
        api: api,
        tokenStore: tokenStore,
        deviceName: 'Follow Android',
        clearAccountState: () async => events.add('account-state-cleared'),
      );

      final loggedOut = await repository.logout();

      expect(loggedOut, isTrue);
      expect(tokenStore.tokens, isNull);
      expect(events, [
        'server-logout',
        'tokens-cleared',
        'account-state-cleared',
      ]);
    },
  );

  test('restores the user only when secure tokens exist', () async {
    final api = _FakeAuthApi();
    final tokenStore = _MemoryTokenStore()
      ..tokens = const AuthTokenPair(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );
    final repository = AuthRepository(
      api: api,
      tokenStore: tokenStore,
      deviceName: 'Follow Android',
    );

    final user = await repository.restoreCurrentUser();

    expect(user?.email, 'family@example.com');
    expect(api.currentUserCalls, 1);
  });

  test('an authentication rejection clears tokens and account state', () async {
    final events = <String>[];
    final api = _FakeAuthApi(
      events: events,
      currentUserError: _dioError(statusCode: 401),
    );
    final tokenStore = _MemoryTokenStore(events: events)
      ..tokens = const AuthTokenPair(
        accessToken: 'expired-access-token',
        refreshToken: 'expired-refresh-token',
      );
    final repository = AuthRepository(
      api: api,
      tokenStore: tokenStore,
      deviceName: 'Follow Android',
      clearAccountState: () async => events.add('account-state-cleared'),
    );

    expect(await repository.restoreCurrentUser(), isNull);
    expect(tokenStore.tokens, isNull);
    expect(events, ['tokens-cleared', 'account-state-cleared']);
  });

  for (final failure in [_dioError(), _dioError(statusCode: 503)]) {
    test('transient current-user failure retains secure tokens', () async {
      final api = _FakeAuthApi(currentUserError: failure);
      final tokenStore = _MemoryTokenStore()
        ..tokens = const AuthTokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
      final repository = AuthRepository(
        api: api,
        tokenStore: tokenStore,
        deviceName: 'Follow Android',
      );

      await expectLater(
        repository.restoreCurrentUser(),
        throwsA(same(failure)),
      );
      expect(tokenStore.tokens, isNotNull);
    });
  }

  test(
    'expired sessions clear local state without calling server logout',
    () async {
      final events = <String>[];
      final api = _FakeAuthApi(events: events);
      final tokenStore = _MemoryTokenStore(events: events)
        ..tokens = const AuthTokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
      final repository = AuthRepository(
        api: api,
        tokenStore: tokenStore,
        deviceName: 'Follow Android',
        clearAccountState: () async => events.add('account-state-cleared'),
      );

      await repository.clearLocalSession();

      expect(events, ['tokens-cleared', 'account-state-cleared']);
    },
  );
}

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({
    List<String>? events,
    bool failLogout = false,
    Object? logoutError,
    Future<void> Function()? beforeLogoutError,
    Object? currentUserError,
  }) : _events = events,
       _failLogout = failLogout,
       _logoutError = logoutError,
       _beforeLogoutError = beforeLogoutError,
       _currentUserError = currentUserError;

  final List<String>? _events;
  final bool _failLogout;
  final Object? _logoutError;
  final Future<void> Function()? _beforeLogoutError;
  final Object? _currentUserError;
  LoginRequest? loginRequest;
  RegisterRequest? registerRequest;
  int currentUserCalls = 0;

  static final user = User(
    id: 'user-id',
    username: 'family',
    email: 'family@example.com',
    role: 'User',
  );

  static final response = AuthResponse(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    sessionId: 'session-id',
    expiresAt: DateTime.utc(2026, 7, 27),
    user: user,
  );

  @override
  Future<User> getCurrentUser() async {
    currentUserCalls++;
    if (_currentUserError case final error?) throw error;
    return user;
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    loginRequest = request;
    return response;
  }

  @override
  Future<void> logout() async {
    _events?.add('server-logout');
    if (_failLogout) throw Exception('offline');
    if (_logoutError case final error?) {
      await _beforeLogoutError?.call();
      throw error;
    }
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    registerRequest = request;
    return response;
  }
}

DioException _dioError({int? statusCode}) {
  final options = RequestOptions(path: '/api/auth/me');
  return DioException(
    requestOptions: options,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: statusCode),
    type: statusCode == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
  );
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore({List<String>? events}) : _events = events;

  final List<String>? _events;
  AuthTokenPair? tokens;

  @override
  Future<void> clearTokens() async {
    _events?.add('tokens-cleared');
    tokens = null;
  }

  @override
  Future<String> getOrCreateDeviceId() async => 'device-id';

  @override
  Future<AuthTokenPair?> readTokens() async => tokens;

  @override
  Future<void> writeTokens(AuthTokenPair tokens) async {
    this.tokens = tokens;
  }
}
