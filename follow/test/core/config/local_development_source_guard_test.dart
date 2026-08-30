import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter startup has no local certificate injection', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, isNot(contains('configureLocalTlsTrust')));
    expect(source, isNot(contains('local_tls_trust')));
    expect(File('lib/core/network/local_tls_trust.dart').existsSync(), isFalse);
  });

  test('local stack publishes API and Admin without a Caddy gateway', () {
    final compose = File('../docker-compose.yml').readAsStringSync();
    final nginx = File('../follow-admin/nginx.conf').readAsStringSync();

    expect(compose, isNot(contains('  gateway:')));
    expect(compose, isNot(contains('caddy')));
    expect(compose, contains('127.0.0.1:5050:5000'));
    expect(compose, contains('127.0.0.1:3000:80'));
    expect(nginx, contains('proxy_pass http://api:5000'));
  });

  test('local startup requires neither Caddy files nor ADB preparation', () {
    expect(File('../Caddyfile').existsSync(), isFalse);
    expect(
      File('../scripts/prepare-android-emulator.sh').existsSync(),
      isFalse,
    );
  });
}
