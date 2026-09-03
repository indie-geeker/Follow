import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/models/user.dart';
import 'package:follow/data/services/api/api_service.dart';

void main() {
  test('login sends body token transport and the device name', () async {
    final adapter = _AuthApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://music.home'))
      ..httpClientAdapter = adapter;
    final api = ApiService(dio: dio);

    await api.login(
      const LoginRequest(
        identifier: 'family',
        password: 'secret',
        tokenTransport: 'body',
        deviceName: 'Android',
      ),
    );

    expect(adapter.lastRequestData, {
      'identifier': 'family',
      'password': 'secret',
      'tokenTransport': 'body',
      'deviceName': 'Android',
    });
  });

  test('loads device sessions from the API response envelope', () async {
    final adapter = _AuthApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://music.home'))
      ..httpClientAdapter = adapter;
    final api = ApiService(dio: dio);

    final sessions = await api.getSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single.deviceName, 'Family iPhone');
    expect(sessions.single.isCurrent, isTrue);
  });

  test('logout calls the server before local auth state is cleared', () async {
    final adapter = _AuthApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://music.home'))
      ..httpClientAdapter = adapter;
    final api = ApiService(dio: dio);

    await api.logout();

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/api/auth/logout');
  });

  test('revokes a selected device session with DELETE', () async {
    final adapter = _AuthApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://music.home'))
      ..httpClientAdapter = adapter;
    final api = ApiService(dio: dio);

    await api.revokeSession('11111111-1111-1111-1111-111111111111');

    expect(adapter.lastMethod, 'DELETE');
    expect(
      adapter.lastPath,
      '/api/auth/sessions/11111111-1111-1111-1111-111111111111',
    );
  });

  test('logout all calls the server logout-all endpoint', () async {
    final adapter = _AuthApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://music.home'))
      ..httpClientAdapter = adapter;
    final api = ApiService(dio: dio);

    await api.logoutAll();

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/api/auth/logout-all');
  });
}

class _AuthApiAdapter implements HttpClientAdapter {
  Object? lastRequestData;
  String? lastMethod;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestData = options.data;
    lastMethod = options.method;
    lastPath = options.path;
    if (options.path == '/api/auth/sessions') {
      return _jsonResponse({
        'code': 0,
        'data': [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'deviceName': 'Family iPhone',
            'clientType': 'Flutter',
            'createdAt': '2026-07-26T10:00:00.000Z',
            'lastUsedAt': '2026-07-26T11:00:00.000Z',
            'expiresAt': '2026-08-25T10:00:00.000Z',
            'isCurrent': true,
          },
        ],
      });
    }
    return _jsonResponse({
      'code': 0,
      'data': {
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
      },
    });
  }

  ResponseBody _jsonResponse(Map<String, dynamic> value) {
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
