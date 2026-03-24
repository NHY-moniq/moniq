---
name: moniq-design-system
description: "Moniq 디자인 시스템 관리. 테마, 컬러, 타이포그래피, 컴포넌트 스펙, 아이콘, 다크 모드. '디자인 시스템', '테마', '컬러 팔레트' 시 사용."
---

# Moniq Design System — 디자인 시스템 관리

## 디자인 토큰

### 컬러 시스템

```dart
// lib/presentation/theme/app_colors.dart

abstract class AppColors {
  // Primary
  static const primary = Color(0xFF0D7377);      // Teal 700
  static const primaryLight = Color(0xFF14A3A8);  // Teal 500
  static const primaryDark = Color(0xFF095252);   // Teal 900
  static const onPrimary = Color(0xFFFFFFFF);

  // Secondary
  static const secondary = Color(0xFFF77F00);     // Amber accent
  static const onSecondary = Color(0xFFFFFFFF);

  // Surface
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF5F5F5);
  static const onSurface = Color(0xFF1A1A1A);
  static const onSurfaceVariant = Color(0xFF666666);

  // Semantic
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFF9A825);
  static const success = Color(0xFF2E7D32);

  // Shift Type Colors
  static const shiftDay = Color(0xFF42A5F5);      // 주간
  static const shiftEvening = Color(0xFFFF8A65);   // 준야
  static const shiftNight = Color(0xFF7E57C2);     // 야간
  static const shiftOff = Color(0xFFBDBDBD);       // 오프

  // Dark Mode
  static const darkSurface = Color(0xFF121212);
  static const darkSurfaceVariant = Color(0xFF1E1E1E);
  static const darkOnSurface = Color(0xFFE0E0E0);
}
```

### 타이포그래피

```dart
// lib/presentation/theme/app_typography.dart

abstract class AppTypography {
  static const displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700, height: 1.2,
  );
  static const headlineMedium = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w600, height: 1.3,
  );
  static const titleLarge = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w600, height: 1.3,
  );
  static const titleMedium = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, height: 1.4,
  );
  static const bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
  );
  static const labelLarge = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, height: 1.4,
  );
  static const labelSmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500, height: 1.3,
  );
}
```

### 스페이싱 & 사이징

```dart
// lib/presentation/theme/app_spacing.dart

abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;
}

abstract class AppRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const full = 999.0;
}

abstract class AppSizing {
  static const touchTarget = 48.0;   // 최소 터치 영역
  static const iconSm = 16.0;
  static const iconMd = 24.0;
  static const iconLg = 32.0;
  static const avatarSm = 32.0;
  static const avatarMd = 40.0;
  static const avatarLg = 56.0;
}
```

## 핵심 컴포넌트 스펙

### ShiftBadge

```
┌──────────┐
│  D  주간  │  ← 코드 + 이름, 배경색 = shiftDay
└──────────┘

크기: 높이 28px, 패딩 좌우 12px
글꼴: labelLarge, 컬러 white
모서리: radius md
```

### TodayCard

```
┌────────────────────────────────┐
│  오늘의 근무                      │
│  ┌──────┐                      │
│  │ D 주간 │  09:00 - 18:00     │
│  └──────┘                      │
│  내과 3병동                      │
└────────────────────────────────┘

배경: surfaceVariant
패딩: lg
모서리: radius xl
그림자: elevation 1
```

### CalendarCell (월간)

```
┌─────┐
│  15  │  ← 날짜
│ ● ● │  ← 근무 유형 도트 (컬러)
└─────┘

오늘: primary 원형 배경
선택: primary 아웃라인
근무 있음: 하단에 컬러 도트 (최대 3개)
```

### RequestCard

```
┌────────────────────────────────┐
│  🔄 교환 요청         대기 중    │
│  3/15(토) 주간 → 3/17(월) 야간  │
│  김간호사 → 이간호사              │
│  사유: 개인 사정                  │
└────────────────────────────────┘
```

## ThemeData 생성 패턴

```dart
// lib/presentation/theme/app_theme.dart

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    // ... typography, component themes
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
    // ... typography, component themes
  );
}
```

## 접근성 체크리스트

- [ ] 모든 터치 영역 >= 48x48dp
- [ ] 텍스트 명암비 >= 4.5:1 (일반), >= 3:1 (대형)
- [ ] 근무 유형 구분: 컬러 + 코드 텍스트 (색맹 대응)
- [ ] 폰트 크기 스케일링 지원 (0.8x ~ 1.4x)
- [ ] 시맨틱 라벨 제공 (Semantics 위젯)
