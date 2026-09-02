import 'package:flutter/material.dart';

import 'follow_theme_tokens.dart';

class AppTheme {
  static ThemeData get light =>
      _build(brightness: Brightness.light, tokens: FollowThemeTokens.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, tokens: FollowThemeTokens.dark);

  static ThemeData _build({
    required Brightness brightness,
    required FollowThemeTokens tokens,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.brandPrimary,
          brightness: brightness,
        ).copyWith(
          primary: tokens.brandPrimary,
          onPrimary: tokens.onBrandPrimary,
          secondary: tokens.brandSecondary,
          tertiary: tokens.auroraCyan,
          surface: tokens.surface,
          onSurface: tokens.textPrimary,
          surfaceContainerHighest: tokens.surfaceElevated,
          error: tokens.error,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [tokens],
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: tokens.surface.withValues(alpha: 0.92),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: tokens.brandPrimary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? tokens.brandPrimary
                : tokens.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? tokens.brandPrimary
                : tokens.textSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          side: BorderSide(color: tokens.textSecondary.withValues(alpha: 0.12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, tokens.minimumTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size.square(tokens.minimumTapTarget),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusInput),
          borderSide: BorderSide(color: tokens.glassStandard.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusInput),
          borderSide: BorderSide(color: tokens.glassStandard.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusInput),
          borderSide: BorderSide(color: tokens.brandPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.brandPrimary,
        unselectedLabelColor: tokens.textSecondary,
        indicatorColor: tokens.brandPrimary,
        dividerColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.brandPrimary,
        inactiveTrackColor: tokens.surfaceElevated,
        thumbColor: tokens.brandPrimary,
        overlayColor: tokens.brandPrimary.withValues(alpha: 0.2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.brandPrimary
              : Colors.transparent;
        }),
        side: BorderSide(color: tokens.textSecondary),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusInput),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.textSecondary.withValues(alpha: 0.14),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.surfaceElevated,
        contentTextStyle: TextStyle(color: tokens.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: _textTheme(tokens.textPrimary, tokens.textSecondary),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        color: primary,
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: TextStyle(
        color: primary,
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: primary,
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: primary,
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: primary,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: primary, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: secondary, fontSize: 14, height: 20 / 14),
      bodySmall: TextStyle(color: secondary, fontSize: 12, height: 4 / 3),
      labelLarge: TextStyle(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        color: secondary,
        fontSize: 12,
        height: 4 / 3,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
