import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:follow/core/config/app_config.dart';
import 'package:follow/data/services/auth/secure_token_store.dart';

AuthTokenPair parseAuthTokenPair(Object? responseData) {
  if (responseData is! Map<String, dynamic>) {
    throw const FormatException('Auth response must be a JSON object.');
  }
  final data = responseData['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Auth response is missing the data envelope.');
  }
  final accessToken = data['accessToken'];
  final refreshToken = data['refreshToken'];
  if (accessToken is! String ||
      accessToken.isEmpty ||
      refreshToken is! String ||
      refreshToken.isEmpty) {
    throw const FormatException('Auth response is missing body tokens.');
  }
  return AuthTokenPair(
    accessToken: accessToken,
    refreshToken: refreshToken,
    sessionId: data['sessionId'] as String?,
  );
}

String safeApiRequestLogLine(RequestOptions options) {
  return '--> ${options.method} ${Uri.parse(options.path).path}';
}

class SafeApiLogInterceptor extends Interceptor {
  SafeApiLogInterceptor({void Function(String)? logPrint})
    : _logPrint = logPrint ?? debugPrint;

  final void Function(String) _logPrint;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logPrint(safeApiRequestLogLine(options));
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final request = response.requestOptions;
    _logPrint(
      '<-- ${response.statusCode ?? '-'} ${request.method} '
      '${Uri.parse(request.path).path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    final causeType = err.error?.runtimeType.toString() ?? 'none';
    _logPrint(
      '<-- ERROR ${err.response?.statusCode ?? '-'} ${request.method} '
      '${Uri.parse(request.path).path} [${err.type.name}/$causeType]',
    );
    handler.next(err);
  }
}

class ApiClient {
  static Dio? _instance;
  static final TokenStore _tokenStore = SecureTokenStore();
  static void Function()? onUnauthorized;

  static TokenStore get tokenStore => _tokenStore;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final refreshClient = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: _tokenStore,
        refreshClient: refreshClient,
        requestClient: dio,
        onUnauthorized: () => onUnauthorized?.call(),
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(SafeApiLogInterceptor());
    }

    return dio;
  }

  static void resetInstance() {
    _instance = null;
  }
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required Dio refreshClient,
    required Dio requestClient,
    void Function()? onUnauthorized,
  }) : _tokenStore = tokenStore,
       _refreshClient = refreshClient,
       _requestClient = requestClient,
       _onUnauthorized = onUnauthorized;

  final TokenStore _tokenStore;
  final Dio _refreshClient;
  final Dio _requestClient;
  final void Function()? _onUnauthorized;

  /// In-flight refresh future — prevents concurrent refresh calls.
  Completer<bool>? _refreshCompleter;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isCredentialEndpoint(options)) {
      handler.next(options);
      return;
    }

    final tokens = await _tokenStore.readTokens();

    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        !_isCredentialEndpoint(err.requestOptions) &&
        err.requestOptions.extra['_retried'] != true) {
      final currentTokens = await _tokenStore.readTokens();
      final failedAuthorization =
          err.requestOptions.headers['Authorization'] as String?;

      // Another request may already have rotated the token while this stale
      // response was in flight. Replay with the current token before issuing
      // another refresh request.
      if (currentTokens != null &&
          failedAuthorization != 'Bearer ${currentTokens.accessToken}') {
        await _retryRequest(err.requestOptions, currentTokens, handler);
        return;
      }

      final refreshed = await _deduplicatedRefresh();
      if (refreshed) {
        final opts = err.requestOptions;
        final tokens = await _tokenStore.readTokens();
        if (tokens == null) {
          handler.next(err);
          return;
        }
        await _retryRequest(opts, tokens, handler);
        return;
      }
    }
    handler.next(err);
  }

  bool _isCredentialEndpoint(RequestOptions options) {
    final parsedPath = Uri.tryParse(options.path)?.path ?? options.path;
    final path = parsedPath.length > 1 && parsedPath.endsWith('/')
        ? parsedPath.substring(0, parsedPath.length - 1)
        : parsedPath;
    return path == '/api/auth/login' ||
        path == '/api/auth/register' ||
        path == '/api/auth/refresh';
  }

  Future<void> _retryRequest(
    RequestOptions options,
    AuthTokenPair tokens,
    ErrorInterceptorHandler handler,
  ) async {
    options.extra['_retried'] = true;
    options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    try {
      final response = await _requestClient.fetch(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401) {
        await _tokenStore.clearTokens();
        _onUnauthorized?.call();
      }
      handler.reject(retryError);
    }
  }

  /// Ensures only one refresh runs at a time.
  /// Concurrent callers await the same Completer.
  Future<bool> _deduplicatedRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final result = await _refreshToken();
      _refreshCompleter!.complete(result);
      return result;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> _refreshToken() async {
    final currentTokens = await _tokenStore.readTokens();

    if (currentTokens == null) {
      _onUnauthorized?.call();
      return false;
    }

    try {
      final response = await _refreshClient.post(
        '/api/auth/refresh',
        data: {
          'refreshToken': currentTokens.refreshToken,
          'tokenTransport': 'body',
        },
      );

      if (response.statusCode == 200) {
        final rotatedTokens = parseAuthTokenPair(response.data);
        await _tokenStore.writeTokens(rotatedTokens);
        return true;
      }
    } on DioException catch (error) {
      if (_isAuthenticationRejection(error.response?.statusCode)) {
        await _tokenStore.clearTokens();
        _onUnauthorized?.call();
      }
    } on FormatException {
      // A malformed or transient server response must not destroy a valid
      // refresh credential. The original request remains failed and can be
      // retried after the server recovers.
    }
    return false;
  }
}

bool _isAuthenticationRejection(int? statusCode) {
  return statusCode == 400 || statusCode == 401 || statusCode == 409;
}
