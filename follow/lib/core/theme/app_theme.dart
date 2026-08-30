import 'package:flutter/material.dart';

/// Shared brand colors used by the login and music surfaces.
class LoginColors {
  static const gradientStart = Color(0xFF090D18);
  static const gradientMid1 = Color(0xFF10172A);
  static const gradientMid2 = Color(0xFF18203A);
  static const gradientEnd = Color(0xFF291D52);

  // Accent colors for logo and buttons
  static const accentPurple = Color(0xFFA99CFF);
  static const accentPink = Color(0xFFF58AC0);

  // Circle gradient colors
  static const circlePurple = Color(0xFF8B7CFF);
  static const circleViolet = Color(0xFF6D5BD0);
  static const circlePink = Color(0xFFF472B6);
  static const circleRed = Color(0xFFFB7185);
  static const circleCyan = Color(0xFF38BDF8);
  static const circleBlue = Color(0xFF60A5FA);

  // Card and input colors
  static const cardBackground = Color(0xD9141A2A);
  static const cardBorder = Color(0x26FFFFFF);
  static const inputBackground = Color(0xB3121828);
  static const inputBorder = Color(0x24FFFFFF);
  static const inputFocusBorder = Color(0xFFA99CFF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xC7FFFFFF);
  static const textHint = Color(0x99FFFFFF);
}

/// App color scheme for light theme
class AppColors {
  static const primary = Color(0xFF5B46F0);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE9E5FF);
  static const onPrimaryContainer = Color(0xFF1D1455);
  static const secondary = Color(0xFFB62D71);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFFFD8E9);
  static const onSecondaryContainer = Color(0xFF3D0922);
  static const background = Color(0xFFF7F6FC);
  static const onBackground = Color(0xFF181720);
  static const surface = Color(0xFFFFFBFF);
  static const onSurface = Color(0xFF181720);
  static const surfaceVariant = Color(0xFFECEAF4);
  static const onSurfaceVariant = Color(0xFF5C5968);
  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
}

/// App color scheme for dark theme (enhanced to match login design)
class AppColorsDark {
  // Primary accent - purple/violet gradient
  static const primary = Color(0xFFA99CFF);
  static const onPrimary = Color(0xFF21145F);
  static const primaryContainer = Color(0xFF40328B);
  static const onPrimaryContainer = Color(0xFFE9E5FF);

  // Secondary - pink accent
  static const secondary = Color(0xFFFF8FC5);
  static const onSecondary = Color(0xFF52002D);
  static const secondaryContainer = Color(0xFF6B234A);
  static const onSecondaryContainer = Color(0xFFFFD8E9);

  // Background - deep dark blue matching login
  static const background = Color(0xFF090D18);
  static const onBackground = Color(0xFFF4F2FA);

  // Surface - slightly lighter for cards
  static const surface = Color(0xFF141A2A);
  static const onSurface = Color(0xFFF4F2FA);
  static const surfaceVariant = Color(0xFF232B42);
  static const onSurfaceVariant = Color(0xFFC8C5D3);

  // Tertiary - cyan accent
  static const tertiary = Color(0xFF67D4FF);
  static const onTertiary = Color(0xFF003548);

  // Error
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
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
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onSurface,
        titleTextStyle: TextStyle(
          color: AppColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColors.surface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x145C5968)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1F5C5968),
        thickness: 1,
      ),
      textTheme: _textTheme(AppColors.onSurface, AppColors.onSurfaceVariant),
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
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColorsDark.onSurface,
        titleTextStyle: const TextStyle(
          color: AppColorsDark.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
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
          return TextStyle(fontSize: 12, color: AppColorsDark.onSurfaceVariant);
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColorsDark.surfaceVariant,
        contentTextStyle: const TextStyle(color: AppColorsDark.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: _textTheme(
        AppColorsDark.onSurface,
        AppColorsDark.onSurfaceVariant,
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: primary,
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        color: primary,
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        color: primary,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: primary,
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: primary, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: primary, fontSize: 14, height: 1.5),
      bodySmall: TextStyle(color: secondary, fontSize: 12, height: 1.45),
      labelLarge: TextStyle(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
