import 'package:flutter/material.dart';

/// Centralized app color palette used across the application.
class AppColors {
  AppColors._();

  static const AppColorsTheme light = AppColorsTheme._(
    primary: Color(0xFF1A1A1A),
    primaryVariant: Color(0xFF000000),
    secondary: Color(0xFF6B6B6B),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F5F5),
    error: Color(0xFFD32F2F),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF0A0A0A),
    onSurface: Color(0xFF0A0A0A),
  );

  static const AppColorsTheme dark = AppColorsTheme._(
    primary: Color(0xFFF5F5F5),
    primaryVariant: Color(0xFFFFFFFF),
    secondary: Color(0xFFB0B0B0),
    background: Color(0xFF000000),
    surface: Color(0xFF1A1A1A),
    error: Color(0xFFEF5350),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFF000000),
    onBackground: Color(0xFFF5F5F5),
    onSurface: Color(0xFFF5F5F5),
  );
}

class AppColorsTheme {
  const AppColorsTheme._({
    required this.primary,
    required this.primaryVariant,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
    required this.onPrimary,
    required this.onSecondary,
    required this.onBackground,
    required this.onSurface,
  });

  final Color primary;
  final Color primaryVariant;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;
  final Color onPrimary;
  final Color onSecondary;
  final Color onBackground;
  final Color onSurface;
}
