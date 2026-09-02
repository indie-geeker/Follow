import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migratedSources = <String>[
  'lib/router/app_router.dart',
  'lib/features/auth/login_page.dart',
  'lib/features/home/home_page.dart',
  'lib/features/library/library_page.dart',
  'lib/features/library/widgets/albums_tab.dart',
  'lib/features/library/widgets/artists_tab.dart',
  'lib/features/library/widgets/library_search_box.dart',
  'lib/features/search/search_page.dart',
  'lib/features/search/widgets/sidebar_search_box.dart',
  'lib/features/downloads/downloads_page.dart',
  'lib/features/settings/settings_page.dart',
  'lib/shared/widgets/app_logo.dart',
  'lib/shared/widgets/mini_player.dart',
  'lib/shared/widgets/smart_track_tile.dart',
  'lib/shared/widgets/track_tile.dart',
  'lib/shared/widgets/track_cover_image.dart',
  'lib/shared/widgets/user_avatar.dart',
];

String _source(String path) => File(path).readAsStringSync();

void main() {
  test(
    'populated UI uses semantic tokens instead of legacy visual constants',
    () {
      final violations = <String>[];

      for (final path in _migratedSources) {
        final source = _source(path);
        if (source.contains('LoginColors')) {
          violations.add('$path still uses LoginColors');
        }
        if (source.contains('Color(0x')) {
          violations.add('$path still declares a raw color');
        }
        if (RegExp(r'fontSize\s*:\s*28\b').hasMatch(source)) {
          violations.add('$path still declares a page-local H1 size');
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test('shell and populated pages retain the approved component hierarchy', () {
    final router = _source('lib/router/app_router.dart');
    expect(router, contains('NavigationDestination('));
    expect(router, contains('NavigationRailDestination('));
    expect(router, contains('tokens.minimumTapTarget'));

    final login = _source('lib/features/auth/login_page.dart');
    expect('GlassPanel('.allMatches(login), hasLength(1));
    expect(login, contains('tier: GlassTier.strong'));

    final home = _source('lib/features/home/home_page.dart');
    expect(home, contains('HomeCollapsingHeader('));
    expect(home, contains('tabs:'));

    for (final path in [
      'lib/features/library/library_page.dart',
      'lib/features/downloads/downloads_page.dart',
      'lib/features/settings/settings_page.dart',
    ]) {
      expect(_source(path), contains('SectionHeader('), reason: path);
    }

    for (final path in [
      'lib/features/library/widgets/albums_tab.dart',
      'lib/features/library/widgets/artists_tab.dart',
      'lib/shared/widgets/track_tile.dart',
    ]) {
      final source = _source(path);
      expect(source, contains('Card('), reason: path);
      expect(source, contains('textTheme'), reason: path);
    }

    for (final path in [
      'lib/features/library/widgets/library_search_box.dart',
      'lib/features/search/widgets/sidebar_search_box.dart',
    ]) {
      final source = _source(path);
      expect(source, contains('GlassPanel('), reason: path);
      expect(source, contains('tier: GlassTier.standard'), reason: path);
    }

    final settings = _source('lib/features/settings/settings_page.dart');
    expect(settings, contains('tokens.error'));
  });

  test('the token extension is the only production brand color source', () {
    final violations = <String>[];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final source in sources) {
      final contents = source.readAsStringSync();
      if (RegExp(
        r'\b(LoginColors|AppColors|AppColorsDark)\b',
      ).hasMatch(contents)) {
        violations.add('${source.path} retains a legacy color class');
      }
      if (contents.contains('Color(0x') &&
          source.path != 'lib/core/theme/follow_theme_tokens.dart') {
        violations.add('${source.path} declares a raw brand color');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
