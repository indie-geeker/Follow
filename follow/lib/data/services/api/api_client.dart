import 'dart:async';

import 'package:dio/dio.dart';
import 'package:follow/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static Dio? _instance;
  static void Function()? onUnauthorized;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.apiTimeout,
      receiveTimeout: AppConfig.apiTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    return dio;
  }

  static void resetInstance() {
    _instance = null;
  }
}

class AuthInterceptor extends Interceptor {
  /// In-flight refresh future — prevents concurrent refresh calls.
  static Completer<bool>? _refreshCompleter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        err.requestOptions.extra['_retried'] != true) {
      final refreshed = await _deduplicatedRefresh();
      if (refreshed) {
        final opts = err.requestOptions;
        opts.extra['_retried'] = true;
        final prefs = await SharedPreferences.getInstance();
        opts.headers['Authorization'] = 'Bearer ${prefs.getString('accessToken')}';

        try {
          final response = await ApiClient.instance.fetch(opts);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.reject(err);
          return;
        }
      }
    }
    handler.next(err);
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
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');

    if (refreshToken == null) {
      ApiClient.onUnauthorized?.call();
      return false;
    }

    try {
      final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final response = await dio.post('/api/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      if (response.statusCode == 200) {
        await prefs.setString('accessToken', response.data['accessToken']);
        await prefs.setString('refreshToken', response.data['refreshToken']);
        return true;
      }
    } catch (e) {
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      ApiClient.onUnauthorized?.call();
    }
    return false;
  }
}
