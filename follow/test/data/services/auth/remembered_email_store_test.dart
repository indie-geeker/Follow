import 'package:flutter_test/flutter_test.dart';
import 'package:follow/data/services/auth/remembered_identifier_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'migrates a remembered login without retaining plaintext secrets',
    () async {
      SharedPreferences.setMockInitialValues({
        'rememberPassword': true,
        'savedEmail': 'family@example.com',
        'savedPassword': 'plaintext-secret',
        'accessToken': 'old-access-token',
        'refreshToken': 'old-refresh-token',
      });
      final preferences = await SharedPreferences.getInstance();
      final store = RememberedIdentifierStore(preferences);

      await store.migrateLegacyCredentials();

      expect(await store.read(), 'family@example.com');
      expect(preferences.getBool('rememberIdentifier'), isTrue);
      expect(preferences.getString('savedIdentifier'), 'family@example.com');
      expect(preferences.containsKey('rememberEmail'), isFalse);
      expect(preferences.containsKey('savedEmail'), isFalse);
      expect(preferences.containsKey('rememberPassword'), isFalse);
      expect(preferences.containsKey('savedPassword'), isFalse);
      expect(preferences.containsKey('accessToken'), isFalse);
      expect(preferences.containsKey('refreshToken'), isFalse);
    },
  );

  test('remembers only the normalized username or email identifier', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = RememberedIdentifierStore(preferences);

    await store.save('  family  ');

    expect(await store.read(), 'family');
    expect(preferences.containsKey('savedPassword'), isFalse);
  });

  test(
    'forgets the saved identifier when remember account is disabled',
    () async {
      SharedPreferences.setMockInitialValues({
        'rememberIdentifier': true,
        'savedIdentifier': 'family',
      });
      final preferences = await SharedPreferences.getInstance();
      final store = RememberedIdentifierStore(preferences);

      await store.clear();

      expect(await store.read(), isNull);
      expect(preferences.containsKey('savedIdentifier'), isFalse);
    },
  );

  test(
    'legacy opt-out removes an email left beside the old password',
    () async {
      SharedPreferences.setMockInitialValues({
        'rememberPassword': false,
        'savedEmail': 'family@example.com',
        'savedPassword': 'plaintext-secret',
      });
      final preferences = await SharedPreferences.getInstance();
      final store = RememberedIdentifierStore(preferences);

      await store.migrateLegacyCredentials();

      expect(preferences.containsKey('savedEmail'), isFalse);
      expect(preferences.containsKey('savedPassword'), isFalse);
      expect(await store.read(), isNull);
    },
  );

  test(
    'migrates the current remembered email setting to an identifier',
    () async {
      SharedPreferences.setMockInitialValues({
        'rememberEmail': true,
        'savedEmail': ' family@example.com ',
      });
      final preferences = await SharedPreferences.getInstance();
      final store = RememberedIdentifierStore(preferences);

      await store.migrateLegacyCredentials();

      expect(await store.read(), 'family@example.com');
      expect(preferences.getBool('rememberIdentifier'), isTrue);
      expect(preferences.containsKey('rememberEmail'), isFalse);
      expect(preferences.containsKey('savedEmail'), isFalse);
    },
  );

  test(
    'startup migration removes legacy auth secrets before UI builds',
    () async {
      SharedPreferences.setMockInitialValues({
        'savedPassword': 'plaintext-secret',
        'accessToken': 'legacy-access',
        'refreshToken': 'legacy-refresh',
      });

      await migrateLegacyAuthPreferences();

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('savedPassword'), isFalse);
      expect(preferences.containsKey('accessToken'), isFalse);
      expect(preferences.containsKey('refreshToken'), isFalse);
    },
  );
}
