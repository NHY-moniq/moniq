import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
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

  static const day = ShiftThemeData(
    primary: Color(0xFFFFD700),
    onPrimary: Color(0xFF2D1F00),
    background: Color(0xFFFCF6E3),
    cardColor: Color(0xFFFFD700),
    accentText: Color(0xFFB8860B), // dark goldenrod — 밝은 배경에서 잘 보임
    displayName: 'Day Shift',
    characterAsset: 'assets/images/day.png',
    characterType: CharacterType.yellow,
  );

  static const evening = ShiftThemeData(
    primary: Color(0xFFFF8C00),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFFCF6E3),
    cardColor: Color(0xFFFF8C00),
    accentText: Color(0xFFE07800), // darker orange
    displayName: 'Evening Shift',
    characterAsset: 'assets/images/evening.png',
    characterType: CharacterType.orange,
  );

  static const night = ShiftThemeData(
    primary: Color(0xFF0061A4),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFF8F9FF),
    cardColor: Color(0xFF0061A4),
    accentText: Color(0xFF0061A4), // same — already dark enough
    displayName: 'Night Shift',
    characterAsset: 'assets/images/night.png',
    characterType: CharacterType.blue,
  );

  static const off = ShiftThemeData(
    primary: Color(0xFFA0AEC0),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFFCF6E3),
    cardColor: Color(0xFFA0AEC0),
    accentText: Color(0xFF718096), // darker grey
    displayName: 'OFF',
    characterAsset: 'assets/images/off.png',
    characterType: CharacterType.grey,
  );

  /// Map a [CharacterType] to the matching [ShiftThemeData].
  static ShiftThemeData fromCharacterType(CharacterType type) {
    return switch (type) {
      CharacterType.yellow => day,
      CharacterType.orange => evening,
      CharacterType.blue => night,
      CharacterType.grey => off,
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

  // 1. Try server shifts
  final calendarAsync = ref.watch(homeViewModelProvider);
  final serverShifts = calendarAsync.whenOrNull(
    data: (state) => state.monthlyShifts[todayKey],
  );

  if (serverShifts != null && serverShifts.isNotEmpty) {
    final color = parseHexColor(serverShifts.first.shiftType.color);
    final charType = characterTypeFromColor(color);
    return ShiftThemeData.fromCharacterType(charType);
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
        final color = parseHexColor(matchedType.color);
        final charType = characterTypeFromColor(color);
        return ShiftThemeData.fromCharacterType(charType);
      }
    }
  } catch (_) {
    // SharedPreferences not yet initialized
  }

  // 3. Off
  return ShiftThemeData.off;
});
