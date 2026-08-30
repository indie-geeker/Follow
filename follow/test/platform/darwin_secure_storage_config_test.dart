import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final path in [
    'ios/Runner/DebugProfile.entitlements',
    'ios/Runner/Release.entitlements',
    'macos/Runner/DebugProfile.entitlements',
    'macos/Runner/Release.entitlements',
  ]) {
    test('$path enables the Keychain group used by secure token storage', () {
      final contents = File(path).readAsStringSync();
      expect(contents, contains('<key>keychain-access-groups</key>'));
      expect(contents, contains('<array/>'));
      expect(contents, isNot(contains(r'$(AppIdentifierPrefix)')));
    });
  }

  test('iOS build configurations select the matching entitlements', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;'),
    );
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;'),
    );
  });

  test('macOS release only requests outbound network access', () {
    final release = File(
      'macos/Runner/Release.entitlements',
    ).readAsStringSync();
    expect(release, contains('com.apple.security.network.client'));
    expect(release, isNot(contains('com.apple.security.network.server')));
  });
}
