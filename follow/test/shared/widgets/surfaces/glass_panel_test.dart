import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/shared/widgets/surfaces/glass_panel.dart';

void main() {
  testWidgets('clips before applying a grouped backdrop filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BackdropGroup(
          child: const GlassPanel(
            tier: GlassTier.standard,
            child: SizedBox(key: Key('content')),
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byKey(const Key('content')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClipRRect),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  for (final tier in GlassTier.values) {
    testWidgets('${tier.name} tier resolves its semantic glass spec', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BackdropGroup(
            child: GlassPanel(tier: tier, child: const SizedBox()),
          ),
        ),
      );

      final expected = switch (tier) {
        GlassTier.light => FollowThemeTokens.dark.glassLight,
        GlassTier.standard => FollowThemeTokens.dark.glassStandard,
        GlassTier.strong => FollowThemeTokens.dark.glassStrong,
      };
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      final blur = filter.filter as ImageFilter;
      final decoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((value) => value.color == expected.fill);

      expect(blur, isNotNull);
      expect(decoration.border?.top.color, expected.border);
    });
  }
}
