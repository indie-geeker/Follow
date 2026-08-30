import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'main Android manifest declares internet and network security policy',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason: 'Release builds also need permission to stream audio.',
      );
      expect(
        manifest,
        contains(
          'android:networkSecurityConfig="@xml/network_security_config"',
        ),
      );
      expect(manifest, contains('android:allowBackup="false"'));
    },
  );

  test('release trusts system CAs and rejects every cleartext host', () {
    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(config, contains('<base-config cleartextTrafficPermitted="false"'));
    expect(config, contains('<certificates src="system"'));
    expect(config, isNot(contains('<certificates src="user"')));
    expect(config, isNot(contains('cleartextTrafficPermitted="true"')));
    expect(config, isNot(contains('<domain>10.0.2.2</domain>')));
  });

  test('debug allows only the Android emulator host API over cleartext', () {
    final config = File(
      'android/app/src/debug/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(config, contains('<base-config cleartextTrafficPermitted="false"'));
    expect(config, contains('<certificates src="system"'));
    expect(config, isNot(contains('<certificates src="user"')));
    expect(config, contains('<domain-config cleartextTrafficPermitted="true"'));
    expect(config, contains('>10.0.2.2</domain>'));
  });

  test('profile keeps the release cleartext policy', () {
    final config = File(
      'android/app/src/profile/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(config, contains('<base-config cleartextTrafficPermitted="false"'));
    expect(config, contains('<certificates src="system"'));
    expect(config, isNot(contains('<certificates src="user"')));
    expect(config, isNot(contains('cleartextTrafficPermitted="true"')));
    expect(config, isNot(contains('<domain>10.0.2.2</domain>')));
  });
}
