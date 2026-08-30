import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'auth and media code never read tokens or passwords from preferences',
    () {
      final guardedFiles = [
        'lib/data/providers/auth_provider.dart',
        'lib/data/services/api/api_client.dart',
        'lib/router/app_router.dart',
        'lib/data/providers/audio_provider.dart',
        'lib/data/providers/download_provider.dart',
        'lib/features/auth/login_page.dart',
      ];
      final source = guardedFiles
          .map((path) => File(path).readAsStringSync())
          .join('\n');

      for (final forbidden in [
        "getString('accessToken')",
        "getString('refreshToken')",
        "setString('accessToken'",
        "setString('refreshToken'",
        'savedPassword',
        'rememberPassword',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }

      final authProviderSource = File(
        'lib/data/providers/auth_provider.dart',
      ).readAsStringSync();
      expect(authProviderSource, contains('clearQueue()'));
      expect(authProviderSource, contains('clearForLogout()'));

      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, contains('migrateLegacyAuthPreferences()'));
    },
  );
}
