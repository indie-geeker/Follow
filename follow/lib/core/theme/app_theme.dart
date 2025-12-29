import 'package:flutter/material.dart';

/// App color scheme for light theme
class AppColors {
  static const primary = Color(0xFF6750A4);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFEADDFF);
  static const onPrimaryContainer = Color(0xFF21005D);
  static const secondary = Color(0xFF625B71);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFE8DEF8);
  static const onSecondaryContainer = Color(0xFF1D192B);
  static const background = Color(0xFFFFFBFE);
  static const onBackground = Color(0xFF1C1B1F);
  static const surface = Color(0xFFFFFBFE);
  static const onSurface = Color(0xFF1C1B1F);
  static const surfaceVariant = Color(0xFFE7E0EC);
  static const onSurfaceVariant = Color(0xFF49454F);
  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
}

/// App color scheme for dark theme
class AppColorsDark {
  static const primary = Color(0xFFD0BCFF);
  static const onPrimary = Color(0xFF381E72);
  static const primaryContainer = Color(0xFF4F378B);
  static const onPrimaryContainer = Color(0xFFEADDFF);
  static const secondary = Color(0xFFCCC2DC);
  static const onSecondary = Color(0xFF332D41);
  static const secondaryContainer = Color(0xFF4A4458);
  static const onSecondaryContainer = Color(0xFFE8DEF8);
  static const background = Color(0xFF1C1B1F);
  static const onBackground = Color(0xFFE6E1E5);
  static const surface = Color(0xFF1C1B1F);
  static const onSurface = Color(0xFFE6E1E5);
  static const surfaceVariant = Color(0xFF49454F);
  static const onSurfaceVariant = Color(0xFFCAC4D0);
  static const error = Color(0xFFF2B8B5);
  static const onError = Color(0xFF601410);
}

/// App theme configuration
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        onError: AppColors.onError,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.primaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.primary,
        onPrimary: AppColorsDark.onPrimary,
        primaryContainer: AppColorsDark.primaryContainer,
        onPrimaryContainer: AppColorsDark.onPrimaryContainer,
        secondary: AppColorsDark.secondary,
        onSecondary: AppColorsDark.onSecondary,
        secondaryContainer: AppColorsDark.secondaryContainer,
        onSecondaryContainer: AppColorsDark.onSecondaryContainer,
        surface: AppColorsDark.surface,
        onSurface: AppColorsDark.onSurface,
        error: AppColorsDark.error,
        onError: AppColorsDark.onError,
      ),
      scaffoldBackgroundColor: AppColorsDark.background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColorsDark.primaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
