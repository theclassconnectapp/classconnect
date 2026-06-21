import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Factory that exposes the main ThemeData used by the app.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.light.primary,
      onPrimary: AppColors.light.onPrimary,
      secondary: AppColors.light.secondary,
      onSecondary: AppColors.light.onSecondary,
      error: AppColors.light.error,
      onError: Colors.white,
      surface: AppColors.light.surface,
      onSurface: AppColors.light.onSurface,
    );

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: AppColors.light.background,
      canvasColor: AppColors.light.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        titleTextStyle: AppTextThemes.lightTextTheme.titleLarge?.copyWith(
          color: colorScheme.onPrimary,
        ),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      textTheme: AppTextThemes.lightTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        titleTextStyle: AppTextThemes.lightTextTheme.titleLarge?.copyWith(
          color: AppColors.light.onSurface,
        ),
        contentTextStyle: AppTextThemes.lightTextTheme.bodyMedium,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.12),
        contentTextStyle: AppTextThemes.lightTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onPrimary,
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static ThemeData get dark {
    final ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.dark.primary,
      onPrimary: AppColors.dark.onPrimary,
      secondary: AppColors.dark.secondary,
      onSecondary: AppColors.dark.onSecondary,
      error: AppColors.dark.error,
      onError: Colors.black,
      surface: AppColors.dark.surface,
      onSurface: AppColors.dark.onSurface,
    );

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: AppColors.dark.background,
      canvasColor: AppColors.dark.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        titleTextStyle: AppTextThemes.darkTextTheme.titleLarge?.copyWith(
          color: colorScheme.onPrimary,
        ),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      textTheme: AppTextThemes.darkTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        titleTextStyle: AppTextThemes.darkTextTheme.titleLarge?.copyWith(
          color: AppColors.dark.onSurface,
        ),
        contentTextStyle: AppTextThemes.darkTextTheme.bodyMedium,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.12),
        contentTextStyle: AppTextThemes.darkTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onPrimary,
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
