import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand colors (from ONOROFF logo)
  static const brandYellow = Color(0xFFF0C040);
  static const brandOrange = Color(0xFFE8923A);
  static const brandBlue = Color(0xFF5A8BB5);

  // Primary - Orange (center character)
  static const primary = Color(0xFFE8923A);
  static const primaryLight = Color(0xFFF0AD6B);
  static const primaryDark = Color(0xFFD07520);
  static const onPrimary = Colors.white;

  // Secondary - Yellow (left character)
  static const secondary = Color(0xFFF0C040);
  static const secondaryLight = Color(0xFFF5D470);
  static const secondaryDark = Color(0xFFD4A520);
  static const onSecondary = Color(0xFF1A1A1A);

  // Tertiary - Blue (right character)
  static const tertiary = Color(0xFF5A8BB5);
  static const tertiaryLight = Color(0xFF7EADD0);
  static const tertiaryDark = Color(0xFF3D6E96);

  // Background
  static const backgroundLight = Color(0xFFF8F9FA);
  static const backgroundDark = Color(0xFF121212);
  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF1E1E1E);

  // Text
  static const textPrimaryLight = Color(0xFF1A1A1A);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textPrimaryDark = Color(0xFFF0F0F0);
  static const textSecondaryDark = Color(0xFF9CA3AF);

  // Error
  static const error = Color(0xFFE53E3E);
  static const errorLight = Color(0xFFFEE2E2);
  static const onError = Colors.white;

  // Success
  static const success = Color(0xFF38A169);
  static const successLight = Color(0xFFC6F6D5);

  // Shift type colors (mapped to brand characters)
  static const shiftDay = Color(0xFFF0C040);       // Yellow character
  static const shiftEvening = Color(0xFFE8923A);    // Orange character
  static const shiftNight = Color(0xFF5A8BB5);      // Blue character
  static const shiftOff = Color(0xFFA0AEC0);

  // Border
  static const borderLight = Color(0xFFE2E8F0);
  static const borderDark = Color(0xFF374151);

  // Divider
  static const dividerLight = Color(0xFFEDF2F7);
  static const dividerDark = Color(0xFF2D3748);
}
