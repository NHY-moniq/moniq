import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/screens/calendar/calendar_providers.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/character_blob.dart';

/// Per-shift UI theme data that drives scaffold bg, card colors, character asset.
class ShiftThemeData {
  const ShiftThemeData({
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.cardColor,
    required this.accentText,
    required this.displayName,
    required this.characterAsset,
    required this.characterType,
  });

  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color cardColor;
  final Color accentText; // 밝은 배경 위에 쓸 강조 텍스트 색
  final String displayName; // 카드에 표시할 영어 이름
  final String characterAsset;
  final CharacterType characterType;

  // ── Light mode ──
  static const day = ShiftThemeData(
    primary: Color(0xFFFFD700),
    onPrimary: Color(0xFF2D1F00),
    background: Color(0xFFFCF6E3),
    cardColor: Color(0xFFFFD700),
    accentText: Color(0xFFB8860B),
    displayName: 'Day Shift',
    characterAsset: 'assets/images/yellow.png',
    characterType: CharacterType.yellow,
  );

  static const evening = ShiftThemeData(
    primary: Color(0xFFFF8C00),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFFCF6E3),
    cardColor: Color(0xFFFF8C00),
    accentText: Color(0xFFE07800),
    displayName: 'Evening Shift',
    characterAsset: 'assets/images/orange.png',
    characterType: CharacterType.orange,
  );

  static const night = ShiftThemeData(
    primary: Color(0xFF0061A4),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFF8F9FF),
    cardColor: Color(0xFF0061A4),
    accentText: Color(0xFF0061A4),
    displayName: 'Night Shift',
    characterAsset: 'assets/images/blue.png',
    characterType: CharacterType.blue,
  );

  static const off = ShiftThemeData(
    primary: Color(0xFFA0AEC0),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFFCF6E3),
    cardColor: Color(0xFFA0AEC0),
    accentText: Color(0xFF718096),
    displayName: 'OFF',
    characterAsset: 'assets/images/off.png',
    characterType: CharacterType.grey,
  );

  // ── Dark mode ──
  static const dayDark = ShiftThemeData(
    primary: Color(0xFFFFD700),
    onPrimary: Color(0xFF453900),
    background: Color(0xFF121212),
    cardColor: Color(0xFFFFD700),
    accentText: Color(0xFFFFD700),
    displayName: 'Day Shift',
    characterAsset: 'assets/images/yellow.png',
    characterType: CharacterType.yellow,
  );

  static const eveningDark = ShiftThemeData(
    primary: Color(0xFFFF8C00),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFF121212),
    cardColor: Color(0xFFFF8C00),
    accentText: Color(0xFFFF8C00),
    displayName: 'Evening Shift',
    characterAsset: 'assets/images/orange.png',
    characterType: CharacterType.orange,
  );

  static const nightDark = ShiftThemeData(
    primary: Color(0xFF2196F3),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFF121212),
    cardColor: Color(0xFF2196F3),
    accentText: Color(0xFF2196F3),
    displayName: 'Night Shift',
    characterAsset: 'assets/images/blue.png',
    characterType: CharacterType.blue,
  );

  static const offDark = ShiftThemeData(
    primary: Color(0xFFA0AEC0),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFF121212),
    cardColor: Color(0xFFA0AEC0),
    accentText: Color(0xFFA0AEC0),
    displayName: 'OFF',
    characterAsset: 'assets/images/off.png',
    characterType: CharacterType.grey,
  );

  /// 캐릭터 타입별 이미지 에셋 경로
  static String _assetForType(CharacterType type) => switch (type) {
        CharacterType.yellow => 'assets/images/yellow.png',
        CharacterType.orange => 'assets/images/orange.png',
        CharacterType.blue => 'assets/images/blue.png',
        CharacterType.grey => 'assets/images/off.png',
        CharacterType.green => 'assets/images/green.png',
        CharacterType.pink => 'assets/images/pink.png',
        CharacterType.purple => 'assets/images/purple.png',
        CharacterType.coral => 'assets/images/coral.png',
      };

  /// 커스텀 색상에서 동적으로 테마 생성
  factory ShiftThemeData.fromColor(Color color, {bool isDark = false, String? displayName}) {
    final hsl = HSLColor.fromColor(color);
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final charType = characterTypeFromColor(color);
    final asset = _assetForType(charType);

    if (isDark) {
      return ShiftThemeData(
        primary: color,
        onPrimary: brightness == Brightness.dark ? Colors.white : const Color(0xFF121212),
        background: const Color(0xFF121212),
        cardColor: color,
        accentText: color,
        displayName: displayName ?? 'Shift',
        characterAsset: asset,
        characterType: charType,
      );
    }

    // 밝은 배경: 채도를 유지하면서 밝기를 올림 (기존 프리셋 #FCF6E3 수준)
    final lightBg = hsl.withSaturation((hsl.saturation * 0.5).clamp(0, 1))
        .withLightness(0.92).toColor();
    // 강조 텍스트: 색상의 밝기를 내림
    final accent = hsl.withLightness((hsl.lightness * 0.6).clamp(0, 0.5)).toColor();

    return ShiftThemeData(
      primary: color,
      onPrimary: brightness == Brightness.dark ? Colors.white : const Color(0xFF2D1F00),
      background: lightBg,
      cardColor: color,
      accentText: accent,
      displayName: displayName ?? 'Shift',
      characterAsset: asset,
      characterType: charType,
    );
  }

  /// Map a [CharacterType] to the matching [ShiftThemeData].
  static ShiftThemeData fromCharacterType(CharacterType type, {bool isDark = false}) {
    if (isDark) {
      return switch (type) {
        CharacterType.yellow => dayDark,
        CharacterType.orange => eveningDark,
        CharacterType.blue => nightDark,
        CharacterType.grey => offDark,
        _ => ShiftThemeData.fromColor(
              const Color(0xFFA0AEC0), isDark: true),
      };
    }
    return switch (type) {
      CharacterType.yellow => day,
      CharacterType.orange => evening,
      CharacterType.blue => night,
      CharacterType.grey => off,
      _ => ShiftThemeData.fromColor(const Color(0xFFA0AEC0)),
    };
  }
}

/// Reactive provider that resolves today's shift theme.
///
/// Priority:
/// 1. Server shifts from [homeViewModelProvider]
/// 2. Personal calendar shifts from [dateEventsProvider] + [personalShiftTypesProvider]
/// 3. Fallback: [ShiftThemeData.off]
final todayShiftThemeProvider = Provider<ShiftThemeData>((ref) {
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);
  final themeMode = ref.watch(themeModeProvider);
  final isDark = switch (themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
  };

  // 1. Try server shifts
  final calendarAsync = ref.watch(homeViewModelProvider);
  final serverShifts = calendarAsync.whenOrNull(
    data: (state) => state.monthlyShifts[todayKey],
  );

  if (serverShifts != null && serverShifts.isNotEmpty) {
    final code = serverShifts.first.shiftType.code.toUpperCase();
    if (code == 'OFF') {
      return isDark ? ShiftThemeData.offDark : ShiftThemeData.off;
    }
    final color = parseHexColor(serverShifts.first.shiftType.color);
    return ShiftThemeData.fromColor(color,
        isDark: isDark, displayName: serverShifts.first.shiftType.name);
  }

  // 2. Fallback to personal calendar (may throw if SharedPreferences not ready)
  try {
    final personalEvents = ref.watch(dateEventsProvider(todayKey));
    final personalShiftTypes = ref.watch(personalShiftTypesProvider);
    final shiftTypeNames = personalShiftTypes.map((st) => st.name).toSet();

    final personalShiftEvent = personalEvents
        .where((e) => shiftTypeNames.contains(e.title))
        .firstOrNull;

    if (personalShiftEvent != null) {
      final matchedType = personalShiftTypes
          .where((st) => st.name == personalShiftEvent.title)
          .firstOrNull;
      if (matchedType != null) {
        if (matchedType.code.toUpperCase() == 'OFF') {
          return isDark ? ShiftThemeData.offDark : ShiftThemeData.off;
        }
        final color = parseHexColor(matchedType.color);
        return ShiftThemeData.fromColor(color,
            isDark: isDark, displayName: matchedType.name);
      }
    }
  } catch (_) {
    // SharedPreferences not yet initialized
  }

  // 3. Off
  return isDark ? ShiftThemeData.offDark : ShiftThemeData.off;
});
