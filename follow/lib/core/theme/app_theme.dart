import 'package:flutter/material.dart';

/// Login page gradient colors (matching follow-admin Vue design)
class LoginColors {
  // Background gradient colors
  static const gradientStart = Color(0xFF1a1a2e);
  static const gradientMid1 = Color(0xFF16213e);
  static const gradientMid2 = Color(0xFF0f3460);
  static const gradientEnd = Color(0xFF533483);
  
  // Accent colors for logo and buttons
  static const accentPurple = Color(0xFF667eea);
  static const accentPink = Color(0xFF764ba2);
  
  // Circle gradient colors
  static const circlePurple = Color(0xFF667eea);
  static const circleViolet = Color(0xFF764ba2);
  static const circlePink = Color(0xFFec4899);
  static const circleRed = Color(0xFFef4444);
  static const circleCyan = Color(0xFF22d3ee);
  static const circleBlue = Color(0xFF3b82f6);
  
  // Card and input colors
  static const cardBackground = Color(0x1AFFFFFF); // 10% white
  static const cardBorder = Color(0x2EFFFFFF); // 18% white
  static const inputBackground = Color(0x14FFFFFF); // 8% white
  static const inputBorder = Color(0x1FFFFFFF); // 12% white
  static const inputFocusBorder = Color(0xFF667eea);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xB3FFFFFF); // 70% white
  static const textHint = Color(0x80FFFFFF); // 50% white
}

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

/// App color scheme for dark theme (enhanced to match login design)
class AppColorsDark {
  // Primary accent - purple/violet gradient
  static const primary = Color(0xFF667eea);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF4F378B);
  static const onPrimaryContainer = Color(0xFFEADDFF);
  
  // Secondary - pink accent
  static const secondary = Color(0xFF764ba2);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFF533483);
  static const onSecondaryContainer = Color(0xFFE8DEF8);
  
  // Background - deep dark blue matching login
  static const background = Color(0xFF1a1a2e);
  static const onBackground = Color(0xFFE6E1E5);
  
  // Surface - slightly lighter for cards
  static const surface = Color(0xFF16213e);
  static const onSurface = Color(0xFFE6E1E5);
  static const surfaceVariant = Color(0xFF0f3460);
  static const onSurfaceVariant = Color(0xFFCAC4D0);
  
  // Tertiary - cyan accent
  static const tertiary = Color(0xFF22d3ee);
  static const onTertiary = Color(0xFF003544);
  
  // Error
  static const error = Color(0xFFf87171);
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
      colorScheme: ColorScheme.dark(
        primary: AppColorsDark.primary,
        onPrimary: AppColorsDark.onPrimary,
        primaryContainer: AppColorsDark.primaryContainer,
        onPrimaryContainer: AppColorsDark.onPrimaryContainer,
        secondary: AppColorsDark.secondary,
        onSecondary: AppColorsDark.onSecondary,
        secondaryContainer: AppColorsDark.secondaryContainer,
        onSecondaryContainer: AppColorsDark.onSecondaryContainer,
        tertiary: AppColorsDark.tertiary,
        onTertiary: AppColorsDark.onTertiary,
        surface: AppColorsDark.surface,
        onSurface: AppColorsDark.onSurface,
        surfaceContainerHighest: AppColorsDark.surfaceVariant,
        error: AppColorsDark.error,
        onError: AppColorsDark.onError,
      ),
      scaffoldBackgroundColor: AppColorsDark.background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColorsDark.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColorsDark.surface.withValues(alpha: 0.8),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColorsDark.primary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColorsDark.primary);
          }
          return IconThemeData(color: AppColorsDark.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColorsDark.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            color: AppColorsDark.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: LoginColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: LoginColors.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LoginColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: LoginColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: LoginColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColorsDark.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColorsDark.primary,
        unselectedLabelColor: AppColorsDark.onSurfaceVariant,
        indicatorColor: AppColorsDark.primary,
        dividerColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColorsDark.primary,
        inactiveTrackColor: AppColorsDark.surfaceVariant,
        thumbColor: AppColorsDark.primary,
        overlayColor: AppColorsDark.primary.withValues(alpha: 0.2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColorsDark.primary;
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: AppColorsDark.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: LoginColors.cardBorder,
        thickness: 1,
      ),
    );
  }
}
