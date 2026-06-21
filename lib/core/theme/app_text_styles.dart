import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Provides app-wide text theme variants used consistently in the UI.
class AppTextThemes {
  AppTextThemes._();

  static TextTheme lightTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      color: AppColors.light.onSurface,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w600,
      color: AppColors.light.onSurface,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: AppColors.light.onSurface,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: AppColors.light.onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.light.onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.light.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.light.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.light.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.light.onSurface,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.light.secondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.light.onSurface,
    ),
  );

  static TextTheme darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      color: AppColors.dark.onSurface,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w600,
      color: AppColors.dark.onSurface,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: AppColors.dark.onSurface,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: AppColors.dark.onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.dark.onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.dark.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.dark.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.dark.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.dark.onSurface,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.dark.onSurface,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.dark.onSurface,
    ),
  );
}
