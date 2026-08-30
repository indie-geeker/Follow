import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/services/api/api_client.dart';
import 'package:follow/data/services/auth/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses rotated tokens from the nested API response envelope', () {
    final tokens = parseAuthTokenPair({
      'code': 0,
      'message': 'ok',
      'data': {
        'accessToken': 'new-access-token',
        'refreshToken': 'new-refresh-token',
        'sessionId': 'session-id',
      },
    });

    expect(
      tokens,
      const AuthTokenPair(
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token',
        sessionId: 'session-id',
      ),
    );
  });

  test(
    'deduplicates concurrent refreshes and retries with rotated tokens',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tokenStore = _MemoryTokenStore(
        const AuthTokenPair(
          accessToken: 'expired-access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final adapter = _RefreshingAdapter();
      final refreshClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      final requestClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      requestClient.interceptors.add(
        AuthInterceptor(
          tokenStore: tokenStore,
          refreshClient: refreshClient,
          requestClient: requestClient,
        ),
      );

      final responses = await Future.wait([
        requestClient.get<Map<String, dynamic>>('/protected/one'),
        requestClient.get<Map<String, dynamic>>('/protected/two'),
      ]);

      expect(adapter.refreshCalls, 1);
      expect(
        responses.map((response) => response.data?['ok']),
        everyElement(true),
      );
      expect(
        await tokenStore.readTokens(),
        const AuthTokenPair(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
          sessionId: 'session-id',
        ),
      );
    },
  );

  test(
    'a late stale 401 replays with rotated tokens without refreshing twice',
    () async {
      final tokenStore = _MemoryTokenStore(
        const AuthTokenPair(
          accessToken: 'expired-access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final adapter = _LateUnauthorizedAdapter();
      final refreshClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      final requestClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      requestClient.interceptors.add(
        AuthInterceptor(
          tokenStore: tokenStore,
          refreshClient: refreshClient,
          requestClient: requestClient,
        ),
      );

      final responses = await Future.wait([
        requestClient.get<Map<String, dynamic>>('/protected/fast'),
        requestClient.get<Map<String, dynamic>>('/protected/late'),
      ]);

      expect(adapter.refreshCalls, 1);
      expect(
        responses.map((response) => response.data?['ok']),
        everyElement(true),
      );
    },
  );

  test('a 401 after token rotation clears the rejected session', () async {
    final tokenStore = _MemoryTokenStore(
      const AuthTokenPair(
        accessToken: 'expired-access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final adapter = _RetryUnauthorizedAdapter();
    var unauthorizedCalls = 0;
    final refreshClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
      ..httpClientAdapter = adapter;
    final requestClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
      ..httpClientAdapter = adapter;
    requestClient.interceptors.add(
      AuthInterceptor(
        tokenStore: tokenStore,
        refreshClient: refreshClient,
        requestClient: requestClient,
        onUnauthorized: () => unauthorizedCalls++,
      ),
    );

    await expectLater(
      requestClient.get<void>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(await tokenStore.readTokens(), isNull);
    expect(unauthorizedCalls, 1);
  });

  for (final refreshStatus in [400, 401, 409]) {
    test(
      'refresh $refreshStatus clears rejected tokens and expires session',
      () async {
        final tokenStore = _MemoryTokenStore(
          const AuthTokenPair(
            accessToken: 'expired-access-token',
            refreshToken: 'rejected-refresh-token',
          ),
        );
        final adapter = _FailingRefreshAdapter(refreshStatus);
        var unauthorizedCalls = 0;
        final refreshClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
          ..httpClientAdapter = adapter;
        final requestClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
          ..httpClientAdapter = adapter;
        requestClient.interceptors.add(
          AuthInterceptor(
            tokenStore: tokenStore,
            refreshClient: refreshClient,
            requestClient: requestClient,
            onUnauthorized: () => unauthorizedCalls++,
          ),
        );

        await expectLater(
          requestClient.get<void>('/protected'),
          throwsA(isA<DioException>()),
        );

        expect(await tokenStore.readTokens(), isNull);
        expect(unauthorizedCalls, 1);
      },
    );
  }

  for (final refreshStatus in [null, 503]) {
    test('transient refresh failure retains secure tokens', () async {
      final originalTokens = const AuthTokenPair(
        accessToken: 'expired-access-token',
        refreshToken: 'refresh-token',
      );
      final tokenStore = _MemoryTokenStore(originalTokens);
      final adapter = _FailingRefreshAdapter(refreshStatus);
      var unauthorizedCalls = 0;
      final refreshClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      final requestClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      requestClient.interceptors.add(
        AuthInterceptor(
          tokenStore: tokenStore,
          refreshClient: refreshClient,
          requestClient: requestClient,
          onUnauthorized: () => unauthorizedCalls++,
        ),
      );

      await expectLater(
        requestClient.get<void>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(await tokenStore.readTokens(), originalTokens);
      expect(unauthorizedCalls, 0);
    });
  }

  test(
    'a rejected login neither refreshes nor destroys an existing session',
    () async {
      final originalTokens = const AuthTokenPair(
        accessToken: 'current-access-token',
        refreshToken: 'current-refresh-token',
      );
      final tokenStore = _MemoryTokenStore(originalTokens);
      final adapter = _RejectedLoginAdapter();
      var unauthorizedCalls = 0;
      final refreshClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      final requestClient = Dio(BaseOptions(baseUrl: 'https://music.home'))
        ..httpClientAdapter = adapter;
      requestClient.interceptors.add(
        AuthInterceptor(
          tokenStore: tokenStore,
          refreshClient: refreshClient,
          requestClient: requestClient,
          onUnauthorized: () => unauthorizedCalls++,
        ),
      );

      await expectLater(
        requestClient.post<void>('/api/auth/login'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.loginAuthorization, isNull);
      expect(adapter.refreshCalls, 0);
      expect(await tokenStore.readTokens(), originalTokens);
      expect(unauthorizedCalls, 0);
    },
  );
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.tokens);

  AuthTokenPair? tokens;

  @override
  Future<void> clearTokens() async => tokens = null;

  @override
  Future<String> getOrCreateDeviceId() async => 'device-id';

  @override
  Future<AuthTokenPair?> readTokens() async => tokens;

  @override
  Future<void> writeTokens(AuthTokenPair tokens) async {
    this.tokens = tokens;
  }
}

class _RefreshingAdapter implements HttpClientAdapter {
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/auth/refresh') {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _jsonResponse({
        'code': 0,
        'data': {
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'sessionId': 'session-id',
        },
      });
    }

    if (options.headers['Authorization'] == 'Bearer new-access-token') {
      return _jsonResponse({'ok': true});
    }
    return _jsonResponse({'message': 'expired'}, statusCode: 401);
  }

  ResponseBody _jsonResponse(
    Map<String, dynamic> value, {
    int statusCode = 200,
  }) {
    return ResponseBody.fromString(
      jsonEncode(value),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingRefreshAdapter implements HttpClientAdapter {
  _FailingRefreshAdapter(this.refreshStatus);

  final int? refreshStatus;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/auth/refresh') {
      if (refreshStatus == null) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      }
      return ResponseBody.fromString(
        jsonEncode({'code': refreshStatus, 'message': 'refresh rejected'}),
        refreshStatus!,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'expired'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _LateUnauthorizedAdapter implements HttpClientAdapter {
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/auth/refresh') {
      refreshCalls++;
      return _jsonResponse({
        'code': 0,
        'data': {
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'sessionId': 'session-id',
        },
      });
    }
    if (options.headers['Authorization'] == 'Bearer new-access-token') {
      return _jsonResponse({'ok': true});
    }
    if (options.path == '/protected/late') {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    return _jsonResponse({'message': 'expired'}, statusCode: 401);
  }

  ResponseBody _jsonResponse(
    Map<String, dynamic> value, {
    int statusCode = 200,
  }) {
    return ResponseBody.fromString(
      jsonEncode(value),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RetryUnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/auth/refresh') {
      return ResponseBody.fromString(
        jsonEncode({
          'code': 0,
          'data': {
            'accessToken': 'new-access-token',
            'refreshToken': 'new-refresh-token',
            'sessionId': 'session-id',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'still unauthorized'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RejectedLoginAdapter implements HttpClientAdapter {
  int refreshCalls = 0;
  Object? loginAuthorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/auth/refresh') {
      refreshCalls++;
      return ResponseBody.fromString('{}', 401);
    }
    if (options.path == '/api/auth/login') {
      loginAuthorization = options.headers['Authorization'];
      return ResponseBody.fromString(
        jsonEncode({'message': 'invalid credentials'}),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    throw StateError('Unexpected request: ${options.path}');
  }

  @override
  void close({bool force = false}) {}
}
