import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';
import 'package:follow/shared/widgets/surfaces/aurora_background.dart';

void main() {
  testWidgets('uses semantic theme colors for two static aurora glows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AuroraBackground(child: SizedBox()),
      ),
    );

    final decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>();
    final gradientColors = decorations
        .expand((decoration) => decoration.gradient?.colors ?? const <Color>[])
        .toSet();

    expect(gradientColors, contains(FollowThemeTokens.light.brandPrimary));
    expect(gradientColors, contains(FollowThemeTokens.light.auroraCyan));
    expect(
      find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('reduced motion remains a complete static background', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const AuroraBackground(
          reduceMotion: true,
          child: Text('content'),
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });
}
