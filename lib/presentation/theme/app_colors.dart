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

  // Surface - warm white canvas + tinted cards
  static const surface = Color(0xFFFFFDF7);
  static const surfaceContainerLowest = Color(0xFFFFFDF7);
  static const surfaceContainerLow = Color(0xFFFFF6EA);
  static const surfaceContainer = Color(0xFFFFF1E2);
  static const surfaceContainerHigh = Color(0xFFF7EAD6);
  static const surfaceContainerHighest = Color(0xFFF2DEC2);
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
  static const surfaceContainerHighestDark = Color(0xFF333333);
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

  // ── Menu accent palette ──
  // 메뉴 항목을 색으로 구분하기 위한 팔레트.
  // 시프트 테마(primary)와 달리 고정색이라 근무가 바뀌어도 항목의 정체성이
  // 유지된다. 의미를 갖는 error/success와는 역할이 다르다.
  static const accentBlue = Color(0xFF2196F3);
  static const accentGreen = Color(0xFF38A169);
  static const accentPurple = Color(0xFF9F7AEA);
  static const accentPink = Color(0xFFED64A6);
  static const accentIndigo = Color(0xFF5A67D8);
  static const accentTeal = Color(0xFF0D9488);
  static const accentAmber = Color(0xFFED8936);

  // ── Cool surface family ──
  // 나이트·오프처럼 쿨톤 시프트일 때 위 웜(상아색) 계열을 통째로 대체한다.
  // 밝기 단계는 웜 팔레트와 1:1로 맞춰, 위젯 쪽 코드는 그대로 두고
  // ColorScheme만 갈아끼우면 되도록 했다.
  static const surfaceCool = Color(0xFFFBFDFF);
  static const surfaceContainerLowestCool = Color(0xFFFBFDFF);
  static const surfaceContainerLowCool = Color(0xFFF8FBFE);
  static const surfaceContainerCool = Color(0xFFF1F6FB);
  static const surfaceContainerHighCool = Color(0xFFEDF3F9);
  static const surfaceContainerHighestCool = Color(0xFFE3ECF4);
  static const backgroundCool = Color(0xFFFBFDFF);
  static const outlineVariantCool = Color(0xFFD3DDE6);
  static const borderCool = Color(0xFFDCE5EE);
  static const dividerCool = Color(0xFFDCE5EE);
}
