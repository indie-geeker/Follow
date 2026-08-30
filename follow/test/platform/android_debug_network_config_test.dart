import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android debug allows cleartext only to the emulator host API', () {
    final source = File(
      'android/app/src/debug/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(source, contains('<base-config cleartextTrafficPermitted="false">'));
    expect(
      source,
      contains('<domain-config cleartextTrafficPermitted="true">'),
    );
    expect(source, contains('>10.0.2.2</domain>'));
  });

  test('Android main and profile configurations remain HTTPS only', () {
    for (final path in [
      'android/app/src/main/res/xml/network_security_config.xml',
      'android/app/src/profile/res/xml/network_security_config.xml',
    ]) {
      final source = File(path).readAsStringSync();

      expect(
        source,
        contains('<base-config cleartextTrafficPermitted="false">'),
      );
      expect(source, isNot(contains('cleartextTrafficPermitted="true"')));
      expect(source, isNot(contains('<certificates src="user"')));
    }
  });
}
