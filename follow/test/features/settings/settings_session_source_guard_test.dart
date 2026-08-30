import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings wires session revocation and server-confirmed logout', () {
    final source = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();

    expect(source, contains('SessionManagementSheet('));
    expect(source, contains('getSessions'));
    expect(source, contains('revokeSession'));
    expect(source, contains('logoutAll'));
    expect(source, contains('if (!revoked)'));
  });
}
