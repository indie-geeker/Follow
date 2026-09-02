import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';
import 'package:follow/core/theme/follow_theme_tokens.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    test(
      '${theme.brightness.name} theme keeps primary actions touch friendly',
      () {
        final buttonSize = theme.filledButtonTheme.style?.minimumSize?.resolve(
          const <WidgetState>{},
        );
        final iconConstraints = theme.iconButtonTheme.style?.minimumSize
            ?.resolve(const <WidgetState>{});

        expect(buttonSize?.height, greaterThanOrEqualTo(48));
        expect(iconConstraints?.height, greaterThanOrEqualTo(48));
        expect(theme.navigationBarTheme.height, greaterThanOrEqualTo(68));
        expect(theme.extension<FollowThemeTokens>(), isNotNull);
        expect(theme.textTheme.displayLarge?.fontSize, 32);
        expect(theme.textTheme.headlineLarge?.fontSize, 28);
        expect(theme.textTheme.headlineMedium?.fontSize, 24);
        expect(theme.textTheme.titleLarge?.fontSize, 20);
        expect(theme.textTheme.titleMedium?.fontSize, 16);
        expect(theme.textTheme.bodyLarge?.fontSize, 16);
        expect(theme.textTheme.bodyMedium?.fontSize, 14);
        expect(theme.textTheme.labelMedium?.fontSize, 12);
      },
    );
  }
}
