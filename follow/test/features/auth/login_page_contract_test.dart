import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'login page separates the username-or-email identifier from registration email',
    () {
      final source = File(
        'lib/features/auth/login_page.dart',
      ).readAsStringSync();
      final localizations = File('lib/core/l10n/l10n.dart').readAsStringSync();

      expect(source, contains('_identifierController'));
      expect(source, contains("l10n.get('loginIdentifier')"));
      expect(source, contains("l10n.get('rememberIdentifier')"));
      expect(source, contains('.login(_identifierController.text.trim(),'));
      expect(localizations, contains("'loginIdentifier': '用户名或邮箱'"));
      expect(localizations, contains("'rememberIdentifier': '记住账号'"));
    },
  );
}
