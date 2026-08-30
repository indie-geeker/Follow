import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/platform/platform_capabilities.dart';

void main() {
  group('supportsNativeFolderBrowsing', () {
    test('supports desktop platforms', () {
      expect(supportsNativeFolderBrowsing(TargetPlatform.macOS), isTrue);
      expect(supportsNativeFolderBrowsing(TargetPlatform.windows), isTrue);
      expect(supportsNativeFolderBrowsing(TargetPlatform.linux), isTrue);
    });

    test('rejects mobile platforms without an open_dir implementation', () {
      expect(supportsNativeFolderBrowsing(TargetPlatform.android), isFalse);
      expect(supportsNativeFolderBrowsing(TargetPlatform.iOS), isFalse);
      expect(supportsNativeFolderBrowsing(TargetPlatform.fuchsia), isFalse);
    });
  });

  test('authenticated audio never falls back to a cleartext local proxy', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        shouldUseAudioProxyForRequestHeaders(platform),
        isFalse,
        reason: platform.name,
      );
    }
  });
}
