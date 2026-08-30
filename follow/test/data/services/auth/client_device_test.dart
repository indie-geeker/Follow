import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/services/auth/client_device.dart';

void main() {
  test('uses a human-readable Flutter device name for auth sessions', () {
    expect(
      clientDeviceName(platform: TargetPlatform.android, isWeb: false),
      'Follow Android',
    );
  });
}
