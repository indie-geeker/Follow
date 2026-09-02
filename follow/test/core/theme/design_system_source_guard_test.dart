import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature code does not add legacy visual dependencies', () {
    const directErrorIconAllowlist = <String>{
      'lib/shared/widgets/create_playlist_dialog.dart',
    };

    final violations = <String>[];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final source in sources) {
      final path = source.path;
      final contents = source.readAsStringSync();
      if (contents.contains('EmptyState(') ||
          contents.contains('EmptyStateCard(') ||
          contents.contains('empty_state.dart') ||
          contents.contains('empty_state_card.dart')) {
        violations.add('$path depends on a legacy empty-state widget');
      }
      if (RegExp(
        r'\b(LoginColors|AppColors|AppColorsDark)\b',
      ).hasMatch(contents)) {
        violations.add('$path depends on a legacy color class');
      }
      if (contents.contains('Color(0x') &&
          path != 'lib/core/theme/follow_theme_tokens.dart') {
        violations.add('$path declares a raw color outside the token source');
      }
      if (contents.contains('Icons.error_outline') &&
          !directErrorIconAllowlist.contains(path)) {
        violations.add('$path renders a page-state error icon directly');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
