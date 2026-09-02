import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/visual_test_app.dart';

void main() {
  final scenarios = <_PlayerScenario>[
    const _PlayerScenario(
      name: 'dark_cover',
      themeMode: ThemeMode.dark,
      coverColor: Color(0xFF12182A),
      secondary: Color(0xFFC6B8FF),
      ambient: Color(0xFF4C9ACC),
    ),
    const _PlayerScenario(
      name: 'bright_cover',
      themeMode: ThemeMode.light,
      coverColor: Color(0xFFF8CC54),
      secondary: Color(0xFF7B3F00),
      ambient: Color(0xFF2A8EAF),
    ),
    const _PlayerScenario(
      name: 'monochrome_cover',
      themeMode: ThemeMode.light,
      coverColor: Color(0xFF848484),
      secondary: Color(0xFF5B46F0),
      ambient: Color(0xFF5C5968),
    ),
    const _PlayerScenario(
      name: 'neon_cover',
      themeMode: ThemeMode.dark,
      coverColor: Color(0xFFFF20A4),
      secondary: Color(0xFFFF8FC5),
      ambient: Color(0xFF67D4FF),
    ),
    const _PlayerScenario(
      name: 'missing_cover',
      themeMode: ThemeMode.dark,
      secondary: Color(0xFFFF8FC5),
      ambient: Color(0xFF67D4FF),
    ),
    const _PlayerScenario(
      name: 'failed_cover',
      themeMode: ThemeMode.light,
      secondary: Color(0xFFB62D71),
      ambient: Color(0xFF2A8EAF),
      failedCover: true,
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets('mobile player ${scenario.name}', (tester) async {
      await _pumpScenario(tester, scenario, const Size(375, 812));
      await expectLater(
        find.byKey(visualFixtureKey),
        matchesGoldenFile('baselines/player_${scenario.name}.png'),
      );
    });
  }

  testWidgets('compact-height mobile player', (tester) async {
    await _pumpScenario(tester, scenarios[3], const Size(375, 640));
    await expectLater(
      find.byKey(visualFixtureKey),
      matchesGoldenFile('baselines/player_compact_height.png'),
    );
  });

  testWidgets('desktop player surface', (tester) async {
    await _pumpScenario(tester, scenarios.first, const Size(1280, 800));
    await expectLater(
      find.byKey(visualFixtureKey),
      matchesGoldenFile('baselines/player_desktop.png'),
    );
  });
}

Future<void> _pumpScenario(
  WidgetTester tester,
  _PlayerScenario scenario,
  Size size,
) async {
  await pumpVisualFixture(
    tester,
    surfaceSize: size,
    themeMode: scenario.themeMode,
    child: PlayerAuroraFixture(
      palette: paletteForVisual(
        themeMode: scenario.themeMode,
        secondary: scenario.secondary,
        ambient: scenario.ambient,
      ),
      coverColor: scenario.coverColor,
      failedCover: scenario.failedCover,
    ),
  );
  await tester.pump();
}

class _PlayerScenario {
  const _PlayerScenario({
    required this.name,
    required this.themeMode,
    required this.secondary,
    required this.ambient,
    this.coverColor,
    this.failedCover = false,
  });

  final String name;
  final ThemeMode themeMode;
  final Color secondary;
  final Color ambient;
  final Color? coverColor;
  final bool failedCover;
}
