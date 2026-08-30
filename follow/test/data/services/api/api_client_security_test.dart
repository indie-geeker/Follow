import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/services/api/api_client.dart';

void main() {
  test(
    'debug HTTP log line excludes headers, body, host and query secrets',
    () {
      final options = RequestOptions(
        path: '/api/auth/login',
        baseUrl: 'http://10.0.2.2:5050',
        method: 'POST',
        queryParameters: {'token': 'query-secret'},
        headers: {'Authorization': 'Bearer header-secret'},
        data: {'password': 'body-secret'},
      );

      final line = safeApiRequestLogLine(options);

      expect(line, '--> POST /api/auth/login');
      expect(line, isNot(contains('query-secret')));
      expect(line, isNot(contains('header-secret')));
      expect(line, isNot(contains('body-secret')));
      expect(line, isNot(contains('10.0.2.2')));
    },
  );

  test(
    'debug error log identifies transport class without leaking secrets',
    () async {
      final logs = <String>[];
      final options = RequestOptions(
        path: '/api/auth/login?token=query-secret',
        baseUrl: 'https://secret-host.example',
        method: 'POST',
        headers: {'Authorization': 'Bearer header-secret'},
        data: {'password': 'body-secret'},
      );
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: StateError('transport-secret'),
      );

      final handler = _CapturingErrorInterceptorHandler();
      SafeApiLogInterceptor(logPrint: logs.add).onError(error, handler);
      await expectLater(handler.result, throwsA(anything));

      expect(
        logs.single,
        '<-- ERROR - POST /api/auth/login [connectionError/StateError]',
      );
      expect(logs.single, isNot(contains('query-secret')));
      expect(logs.single, isNot(contains('secret-host')));
      expect(logs.single, isNot(contains('header-secret')));
      expect(logs.single, isNot(contains('body-secret')));
      expect(logs.single, isNot(contains('transport-secret')));
    },
  );
}

class _CapturingErrorInterceptorHandler extends ErrorInterceptorHandler {
  Future<Object?> get result => future;
}
