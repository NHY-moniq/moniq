import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart'
    show isOffShiftName;
import 'package:moniq/data/models/shift_type_model.dart';
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
    required this.scaffoldBackground,
    required this.elevatedSurface,
    required this.cardColor,
    required this.accentText,
    required this.displayName,
    required this.characterAsset,
    required this.characterType,
  });

  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color scaffoldBackground; // 화면 전체 배경 (Scaffold)
  final Color elevatedSurface; // 배경 위에 떠 있는 면 (하단 dock, 배너 래퍼 등)
  final Color cardColor;
  final Color accentText; // 밝은 배경 위에 쓸 강조 텍스트 색
  final String displayName; // 카드에 표시할 영어 이름
  final String characterAsset;
  final CharacterType characterType;

  // ── 배경 톤 ──
  // 데이·이브닝(웜톤)은 기존 상아색을 그대로 쓰고,
  // 나이트·오프(쿨톤)는 상아색보다 차갑고 하얀 배경을 쓴다.
  static const warmBackground = Color(0xFFFCF6E3);
  static const warmScaffold = Color(0xFFFFF6EA);
  static const warmElevated = Color(0xFFF7EAD6);
  static const coolBackground = Color(0xFFF4F8FC);
  static const coolScaffold = Color(0xFFF8FBFE);
  static const coolElevated = Color(0xFFEDF3F9);
  /// 오프 테마의 강조색 — 옅은 하늘색. "면적이 큰" 요소 전용:
  /// 히어로 카드 배경, 채움 버튼(저장·발행) 배경, 스위치 활성 트랙,
  /// 하단 독 활성 pill 등. 테마에서는 [cardColor]로 소비된다.
  static const offBlue = Color(0xFFD5EBFF);

  /// 오프 테마의 "잉크" 강조색 — 글자·아이콘·테두리 전용. 옅은 하늘색을
  /// 그대로 쓰면 밝은 배경에서 안 보이므로 진한 잉크색을 따로 둔다.
  /// 면(배경) 채움에는 쓰지 않는다 — 면은 [offBlue]([cardColor])가 담당.
  ///
  /// 밝고 채도 높은 스카이블루. 슬레이트/페리윙클 계열은 탁하거나 보라로
  /// 읽힌다는 피드백으로 확정된 값. 나이트 라이트 primary(#0061A4, 어두운
  /// 남색)와는 명도 차로 구분되고, 파스텔 [offBlue](#D5EBFF)와 같은 쿨블루
  /// 계열을 유지한다. 대비: 흰 배경 3.7:1, 쿨 스캐폴드 3.5:1.
  static const offBlueInk = Color(0xFF1E88E5);

  /// 오프 색 위에 얹는 글자색. [offBlue]가 아주 밝아 흰 글자는 보이지 않는다.
  static const onOffBlue = Color(0xFF1A365D);
  static const darkBackground = Color(0xFF121212);
  static const darkScaffold = Color(0xFF181818);
  static const darkElevated = Color(0xFF282828);

  /// 색조가 웜톤(노랑·주황·빨강 계열)인지 여부.
  ///
  /// 웜톤이면 상아색 배경, 쿨톤이면 차가운 화이트 배경을 쓴다.
  static bool _isWarmHue(double hue) => hue < 75 || hue >= 330;

  /// 이 시프트가 쿨톤 배경을 쓰는지.
  ///
  /// 앱 전역 [ColorScheme]을 웜(상아색)/쿨(화이트) 중 어느 계열로 만들지
  /// 고르는 데 쓴다. 다크 모드는 자체 테마를 쓰므로 false다.
  bool get isCoolTone => background == coolBackground;

  // ── Light mode ──
  static const day = ShiftThemeData(
    primary: Color(0xFFFFD700),
    onPrimary: Color(0xFF2D1F00),
    background: warmBackground,
    scaffoldBackground: warmScaffold,
    elevatedSurface: warmElevated,
    cardColor: Color(0xFFFFD700),
    accentText: Color(0xFFB8860B),
    displayName: 'Day Shift',
    characterAsset: 'assets/images/yellow.png',
    characterType: CharacterType.yellow,
  );

  static const evening = ShiftThemeData(
    primary: Color(0xFFFF8C00),
    onPrimary: Color(0xFFFFFFFF),
    background: warmBackground,
    scaffoldBackground: warmScaffold,
    elevatedSurface: warmElevated,
    cardColor: Color(0xFFFF8C00),
    accentText: Color(0xFFE07800),
    displayName: 'Evening Shift',
    characterAsset: 'assets/images/orange.png',
    characterType: CharacterType.orange,
  );

  static const night = ShiftThemeData(
    primary: Color(0xFF0061A4),
    onPrimary: Color(0xFFFFFFFF),
    background: coolBackground,
    scaffoldBackground: coolScaffold,
    elevatedSurface: coolElevated,
    cardColor: Color(0xFF0061A4),
    accentText: Color(0xFF0061A4),
    displayName: 'Night Shift',
    characterAsset: 'assets/images/blue.png',
    characterType: CharacterType.blue,
  );

  static const off = ShiftThemeData(
    // primary는 전앱 강조색 중 "잉크"(텍스트·아이콘·링크)로 퍼지므로 잉크
    // 톤을 쓰고, 면(채움 버튼 배경·스위치 트랙·독 활성 pill·히어로 카드)은
    // cardColor(파스텔)가 담당한다. app_theme의 fill/onFill 참고.
    primary: offBlueInk,
    onPrimary: onOffBlue,
    background: coolBackground,
    scaffoldBackground: coolScaffold,
    elevatedSurface: coolElevated,
    cardColor: offBlue,
    accentText: Color(0xFF2C5282),
    displayName: 'OFF',
    characterAsset: 'assets/images/off.png',
    characterType: CharacterType.grey,
  );

  // ── Dark mode ──
  static const dayDark = ShiftThemeData(
    primary: Color(0xFFFFD700),
    onPrimary: Color(0xFF453900),
    background: darkBackground,
    scaffoldBackground: darkScaffold,
    elevatedSurface: darkElevated,
    cardColor: Color(0xFFFFD700),
    accentText: Color(0xFFFFD700),
    displayName: 'Day Shift',
    characterAsset: 'assets/images/yellow.png',
    characterType: CharacterType.yellow,
  );

  static const eveningDark = ShiftThemeData(
    primary: Color(0xFFFF8C00),
    onPrimary: Color(0xFFFFFFFF),
    background: darkBackground,
    scaffoldBackground: darkScaffold,
    elevatedSurface: darkElevated,
    cardColor: Color(0xFFFF8C00),
    accentText: Color(0xFFFF8C00),
    displayName: 'Evening Shift',
    characterAsset: 'assets/images/orange.png',
    characterType: CharacterType.orange,
  );

  static const nightDark = ShiftThemeData(
    primary: Color(0xFF2196F3),
    onPrimary: Color(0xFFFFFFFF),
    background: darkBackground,
    scaffoldBackground: darkScaffold,
    elevatedSurface: darkElevated,
    cardColor: Color(0xFF2196F3),
    accentText: Color(0xFF2196F3),
    displayName: 'Night Shift',
    characterAsset: 'assets/images/blue.png',
    characterType: CharacterType.blue,
  );

  static const offDark = ShiftThemeData(
    primary: offBlue,
    onPrimary: onOffBlue,
    background: darkBackground,
    scaffoldBackground: darkScaffold,
    elevatedSurface: darkElevated,
    cardColor: offBlue,
    accentText: offBlue,
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
        onPrimary: brightness == Brightness.dark ? Colors.white : darkBackground,
        background: darkBackground,
        scaffoldBackground: darkScaffold,
        elevatedSurface: darkElevated,
        cardColor: color,
        accentText: color,
        displayName: displayName ?? 'Shift',
        characterAsset: asset,
        characterType: charType,
      );
    }

    // 밝은 배경: 시프트 색조에 맞춰 웜톤(상아색)/쿨톤(화이트) 중 하나를 고른다.
    final isWarm = _isWarmHue(hsl.hue);
    // 강조 텍스트: 색상의 밝기를 내림
    final accent = hsl.withLightness((hsl.lightness * 0.6).clamp(0, 0.5)).toColor();

    return ShiftThemeData(
      primary: color,
      onPrimary: brightness == Brightness.dark ? Colors.white : const Color(0xFF2D1F00),
      background: isWarm ? warmBackground : coolBackground,
      scaffoldBackground: isWarm ? warmScaffold : coolScaffold,
      elevatedSurface: isWarm ? warmElevated : coolElevated,
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

/// 시프트 "면" 강조색을 위젯에서 조회하는 테마 확장.
///
/// [fill]은 채움 버튼 배경·스위치 활성 트랙처럼 면적이 큰 요소용이고,
/// [onFill]은 그 위 글자·아이콘 색이다. 오프(라이트)만 fill이 파스텔
/// ([ShiftThemeData.offBlue])로 primary(잉크)와 갈라지고, 나머지 시프트는
/// fill == primary다. 등록은 `AppTheme.light`에서 하며, 미등록 테마(다크 등)
/// 에서는 소비처가 `?.fill ?? colorScheme.primary`로 폴백한다.
class ShiftFillColors extends ThemeExtension<ShiftFillColors> {
  const ShiftFillColors({required this.fill, required this.onFill});

  final Color fill;
  final Color onFill;

  @override
  ShiftFillColors copyWith({Color? fill, Color? onFill}) => ShiftFillColors(
        fill: fill ?? this.fill,
        onFill: onFill ?? this.onFill,
      );

  @override
  ShiftFillColors lerp(ShiftFillColors? other, double t) {
    if (other == null) return this;
    return ShiftFillColors(
      fill: Color.lerp(fill, other.fill, t)!,
      onFill: Color.lerp(onFill, other.onFill, t)!,
    );
  }
}

/// 스위치·세그먼트 같은 컨트롤에 쓰는 근무 색.
///
/// 원색을 그대로 쓰면 채도가 높아 컨트롤이 화면에서 너무 튄다.
/// 설정 탭의 푸시 알림 토글이 쓰던 톤을 공용으로 뽑아, 근무 유형 폼 등
/// 다른 화면의 토글도 같은 색감을 따르게 한다.
///
/// 기준색은 [ShiftThemeData.cardColor](면 채움색)다 — 컨트롤 트랙은 면
/// 요소라, 오프에서는 잉크(primary)가 아닌 파스텔을 따라야 한다.
/// 오프 외 시프트는 cardColor == primary라 결과가 기존과 동일하다.
Color shiftControlColor(ShiftThemeData shift) {
  final hsl = HSLColor.fromColor(shift.cardColor);
  return hsl.withSaturation((hsl.saturation * 0.72).clamp(0.0, 1.0)).toColor();
}

/// Reactive provider that resolves today's shift theme.
///
/// Priority:
/// 1. Server shifts from [homeViewModelProvider] — 개인 근무 수정(오버라이드)이
///    있으면 그 색/이름을 우선 적용해 테마가 즉시 따라오게 한다.
/// 2. Personal calendar shifts from [dateEventsIncludingSpansProvider] +
///    [personalShiftTypesProvider]
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
    final shift = serverShifts.first;
    // "근무 수정"으로 만든 개인 오버라이드가 있으면 그쪽이 실제로 보이는 근무다.
    // (오버라이드는 개인 캘린더/홈 카드에 이미 반영되므로 테마도 같이 따라간다)
    final override =
        ref.watch(personalShiftOverridesProvider).valueOrNull?[shift.shift.id];
    final name = override?.name ?? shift.shiftType.name;
    final code = override?.code ?? shift.shiftType.code;
    if (isOffShiftName(name, code)) {
      return isDark ? ShiftThemeData.offDark : ShiftThemeData.off;
    }
    final color = parseHexColor(override?.color ?? shift.shiftType.color);
    return ShiftThemeData.fromColor(color, isDark: isDark, displayName: name);
  }

  // 2. Fallback to personal calendar (may throw if SharedPreferences not ready)
  try {
    final personalEvents =
        ref.watch(dateEventsIncludingSpansProvider(todayKey));
    final personalShiftTypes = ref.watch(personalShiftTypesProvider);
    // 빠른 추가 칩은 즐겨찾기 팀 유형(커스텀 포함) 기준으로 근무를 만들므로,
    // 개인 유형 목록에 없는 이름도 팀 유형까지 대조해야 근무로 인식된다.
    // (빠지면 커스텀 근무인 날 홈 테마가 오프로 떨어지는 버그)
    final favTeamTypes =
        ref.watch(favoriteTeamShiftTypesProvider).valueOrNull ??
        const <ShiftTypeModel>[];

    String? matchedName;
    String? matchedCode;
    String? matchedColor;
    for (final e in personalEvents) {
      final personal = personalShiftTypes
          .where((st) => st.name == e.title)
          .firstOrNull;
      if (personal != null) {
        matchedName = personal.name;
        matchedCode = personal.code;
        matchedColor = personal.color;
        break;
      }
      final team = favTeamTypes.where((st) => st.name == e.title).firstOrNull;
      if (team != null) {
        matchedName = team.name;
        matchedCode = team.code;
        matchedColor = team.color;
        break;
      }
    }

    if (matchedName != null) {
      if (isOffShiftName(matchedName, matchedCode ?? '')) {
        return isDark ? ShiftThemeData.offDark : ShiftThemeData.off;
      }
      final color = parseHexColor(matchedColor!);
      return ShiftThemeData.fromColor(color,
          isDark: isDark, displayName: matchedName);
    }
  } catch (_) {
    // SharedPreferences not yet initialized
  }

  // 3. Off
  return isDark ? ShiftThemeData.offDark : ShiftThemeData.off;
});
