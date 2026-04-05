import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand colors (Moniq warm palette)
  static const brandYellow = Color(0xFFFFC107);
  static const brandOrange = Color(0xFFFF8F00);
  static const brandBlue = Color(0xFF2196F3);

  // Primary - Amber Gold
  static const primary = Color(0xFFFFC107);
  static const primaryContainer = Color(0xFFFFECB3);
  static const onPrimary = Color(0xFF453900);
  static const onPrimaryContainer = Color(0xFF5B4B00);

  // Secondary - Deep Orange
  static const secondary = Color(0xFFFF8F00);
  static const secondaryContainer = Color(0xFFFFE0B2);
  static const onSecondary = Colors.white;

  // Tertiary - Sky Blue
  static const tertiary = Color(0xFF2196F3);
  static const tertiaryContainer = Color(0xFFB3E5FC);

  // Surface - Warm Cream
  static const surface = Color(0xFFFFFDF7);
  static const surfaceContainer = Color(0xFFF9F6E5);
  static const surfaceContainerLow = Color(0xFFFFF8E1);
  static const surfaceContainerHigh = Color(0xFFF2ECD9);
  static const onSurface = Color(0xFF373830);
  static const onSurfaceVariant = Color(0xFF64655C);

  // Background
  static const backgroundLight = Color(0xFFFFFDF7);
  static const backgroundDark = Color(0xFF121212);

  // Dark surface variants (matching design HTML)
  static const surfaceDark = Color(0xFF121212);
  static const surfaceContainerDark = Color(0xFF1E1E1E);
  static const surfaceContainerLowDark = Color(0xFF181818);
  static const surfaceContainerHighDark = Color(0xFF282828);
  static const primaryContainerDark = Color(0xFF332B00);
  static const onPrimaryContainerDark = Color(0xFFFFECB3);
  static const secondaryContainerDark = Color(0xFF422E11);
  static const tertiaryContainerDark = Color(0xFF10334A);

  // Text
  static const textPrimaryLight = Color(0xFF373830);
  static const textSecondaryLight = Color(0xFF818177);
  static const textPrimaryDark = Color(0xFFF5F5F5);
  static const textSecondaryDark = Color(0xFFB0B0B0);

  // Outline
  static const outline = Color(0xFF818177);
  static const outlineVariant = Color(0xFFDEDBC0);
  static const outlineVariantDark = Color(0xFF2C2C2C);

  // Error
  static const error = Color(0xFFFF5252);
  static const errorLight = Color(0xFFFEE2E2);
  static const onError = Colors.white;

  // Success
  static const success = Color(0xFF38A169);
  static const successLight = Color(0xFFC6F6D5);

  // Shift type colors (mapped to brand characters)
  static const shiftDay = Color(0xFFFFC107);
  static const shiftEvening = Color(0xFFFF8F00);
  static const shiftNight = Color(0xFF2196F3);
  static const shiftOff = Color(0xFFA0AEC0);

  // Border
  static const borderLight = Color(0xFFE8E2D2);
  static const borderDark = Color(0xFF333333);

  // Divider
  static const dividerLight = Color(0xFFE8E2D2);
  static const dividerDark = Color(0xFF2C2C2C);
}
