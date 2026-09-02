import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/visual_test_app.dart';

void main() {
  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('all illustrated states ${themeMode.name}', (tester) async {
      await pumpVisualFixture(
        tester,
        surfaceSize: const Size(1280, 800),
        themeMode: themeMode,
        child: const StateViewsBoard(),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(visualFixtureKey),
        matchesGoldenFile('baselines/states_${themeMode.name}.png'),
      );
    });
  }
}
