import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow/core/theme/app_theme.dart';

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
      },
    );
  }
}
