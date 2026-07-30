import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';

abstract final class AppTheme {
  /// [color]의 색조를 유지한 채 밝기만 [lightness]로 올려 옅은 배경색을 만든다.
  static Color _tint(Color color, double lightness) => HSLColor.fromColor(color)
      .withLightness(lightness.clamp(0.0, 1.0))
      .withSaturation(
          (HSLColor.fromColor(color).saturation * 0.85).clamp(0.0, 1.0))
      .toColor();

  /// 라이트 테마.
  ///
  /// primary 계열은 [shift]가 있으면 항상 그날 근무 색을 따른다.
  /// surface 계열만 톤을 나눠, 쿨톤(나이트·오프)이면 상아색 대신 쿨 계열을 쓰고
  /// 웜톤(데이·이브닝)이면 기존 상아색을 그대로 유지한다.
  static ThemeData light({ShiftThemeData? shift}) {
    final cool = shift?.isCoolTone ?? false;

    final primary = shift?.primary ?? AppColors.primary;
    final onPrimary = shift?.onPrimary ?? AppColors.onPrimary;
    // primaryContainer(아이콘 배지 등)는 시프트 색을 옅게 깐다.
    final primaryContainer =
        shift == null ? AppColors.primaryContainer : _tint(primary, 0.88);
    final onPrimaryContainer =
        shift == null ? AppColors.onPrimaryContainer : shift.accentText;
    final secondary = shift?.primary ?? AppColors.secondary;
    final secondaryContainer =
        shift == null ? AppColors.secondaryContainer : _tint(primary, 0.82);

    final surface = cool ? AppColors.surfaceCool : AppColors.surface;
    final surfaceContainerLowest = cool
        ? AppColors.surfaceContainerLowestCool
        : AppColors.surfaceContainerLowest;
    final surfaceContainerLow =
        cool ? AppColors.surfaceContainerLowCool : AppColors.surfaceContainerLow;
    final surfaceContainer =
        cool ? AppColors.surfaceContainerCool : AppColors.surfaceContainer;
    final surfaceContainerHigh = cool
        ? AppColors.surfaceContainerHighCool
        : AppColors.surfaceContainerHigh;
    final surfaceContainerHighest = cool
        ? AppColors.surfaceContainerHighestCool
        : AppColors.surfaceContainerHighest;
    final outlineVariant =
        cool ? AppColors.outlineVariantCool : AppColors.outlineVariant;
    final border = cool ? AppColors.borderCool : AppColors.borderLight;
    final divider = cool ? AppColors.dividerCool : AppColors.dividerLight;
    final background = cool ? AppColors.backgroundCool : AppColors.backgroundLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: secondaryContainer,
      tertiary: AppColors.tertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      surface: surface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: outlineVariant,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: AppTypography.displayLarge,
      displayMedium: AppTypography.displayMedium,
      headlineLarge: AppTypography.headlineLarge,
      headlineMedium: AppTypography.headlineMedium,
      titleLarge: AppTypography.titleLarge,
      titleMedium: AppTypography.titleMedium,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.bodyMedium,
      labelLarge: AppTypography.labelLarge,
      labelMedium: AppTypography.labelMedium,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: 0.8),
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(AppSizing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          minimumSize: const Size.fromHeight(AppSizing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
          side: BorderSide(color: outlineVariant, width: 2),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondary,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: const BorderSide(color: Colors.transparent, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(color: AppColors.outline.withValues(alpha: 0.4)),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusXl,
          side: BorderSide(
            color: border.withValues(alpha: 0.45),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusXl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl),
            topRight: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusLg),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusFull),
      ),
    );
  }

  /// 다크 테마.
  ///
  /// [shift]가 있으면 primary와 컨테이너 계열을 그날 근무 색으로 맞춘다.
  /// 다크 모드의 surface는 원래 무채색이라 웜/쿨 구분 없이 항상 적용한다.
  static ThemeData dark({ShiftThemeData? shift}) {
    final primary = shift?.primary ?? AppColors.primary;
    final onPrimary = shift?.onPrimary ?? AppColors.onPrimary;
    final primaryContainer =
        shift == null ? AppColors.primaryContainerDark : _tint(primary, 0.18);
    final onPrimaryContainer =
        shift == null ? AppColors.onPrimaryContainerDark : _tint(primary, 0.80);
    final secondaryContainer =
        shift == null ? AppColors.secondaryContainerDark : _tint(primary, 0.22);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: shift?.primary ?? AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: secondaryContainer,
      tertiary: AppColors.tertiary,
      tertiaryContainer: AppColors.tertiaryContainerDark,
      error: AppColors.error,
      onError: AppColors.onError,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      onSurfaceVariant: AppColors.textSecondaryDark,
      surfaceContainerLowest: AppColors.surfaceDark,
      surfaceContainerLow: AppColors.surfaceContainerLowDark,
      surfaceContainer: AppColors.surfaceContainerDark,
      surfaceContainerHigh: AppColors.surfaceContainerHighDark,
      surfaceContainerHighest: AppColors.surfaceContainerHighestDark,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariantDark,
    );

    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(
          displayLarge: AppTypography.displayLarge,
          displayMedium: AppTypography.displayMedium,
          headlineLarge: AppTypography.headlineLarge,
          headlineMedium: AppTypography.headlineMedium,
          titleLarge: AppTypography.titleLarge,
          titleMedium: AppTypography.titleMedium,
          bodyLarge: AppTypography.bodyLarge,
          bodyMedium: AppTypography.bodyMedium,
          labelLarge: AppTypography.labelLarge,
          labelMedium: AppTypography.labelMedium,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.8),
        foregroundColor: AppColors.textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.textPrimaryDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(AppSizing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          minimumSize: const Size.fromHeight(AppSizing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusFull,
          ),
          side: BorderSide(color: AppColors.borderDark, width: 2),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTypography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: const BorderSide(color: Colors.transparent, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusLg,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondaryDark.withValues(alpha: 0.4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusXl,
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusXl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl),
            topRight: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusLg),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusFull),
      ),
    );
  }
}
