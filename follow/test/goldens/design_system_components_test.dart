import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/visual_test_app.dart';

void main() {
  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('component board ${themeMode.name}', (tester) async {
      await pumpVisualFixture(
        tester,
        surfaceSize: const Size(375, 812),
        themeMode: themeMode,
        child: const DesignSystemComponentBoard(),
      );

      await expectLater(
        find.byKey(visualFixtureKey),
        matchesGoldenFile('baselines/components_${themeMode.name}.png'),
      );
    });
  }
}
