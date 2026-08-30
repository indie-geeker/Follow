import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:follow/core/config/app_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('uses the local API when desktop debug has no dart define', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    expect(AppConfig.apiBaseUrl, 'http://localhost:5050');
  });

  test('uses the host API directly by default on an Android emulator', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:5050');
  });

  test('rejects an insecure gateway outside debug builds', () {
    expect(
      () => resolveApiBaseUri('http://music.home', isDebug: false),
      throwsA(isA<StateError>()),
    );
  });

  test('allows only the exact local cleartext origins in debug builds', () {
    expect(
      resolveApiBaseUri(
        'http://10.0.2.2:5050',
        isDebug: true,
        isAndroid: true,
      ).toString(),
      'http://10.0.2.2:5050',
    );
    expect(
      resolveApiBaseUri('http://localhost:5050', isDebug: true).toString(),
      'http://localhost:5050',
    );
  });

  test('rejects non-local or incorrectly scoped cleartext origins', () {
    expect(
      () => resolveApiBaseUri(
        'http://10.0.0.2:5050',
        isDebug: true,
        isAndroid: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => resolveApiBaseUri(
        'http://10.0.2.2:5000',
        isDebug: true,
        isAndroid: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => resolveApiBaseUri('http://10.0.2.2:5050', isDebug: true),
      throwsA(isA<StateError>()),
    );
    expect(
      () => resolveApiBaseUri('http://music.home', isDebug: true),
      throwsA(isA<StateError>()),
    );
  });

  test('normalizes a trailing slash before API paths are resolved', () {
    expect(
      resolveApiBaseUri('https://music.home/', isDebug: false).toString(),
      'https://music.home',
    );
  });

  test('requires an origin without credentials, path, query or fragment', () {
    for (final value in [
      'https://user:password@music.home',
      'https://music.home/base',
      'https://music.home?token=secret',
      'https://music.home#fragment',
    ]) {
      expect(
        () => resolveApiBaseUri(value, isDebug: false),
        throwsA(isA<StateError>()),
        reason: value,
      );
    }
  });
}
