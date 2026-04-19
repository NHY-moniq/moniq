# 원티드 UI/UX 추가 개선 플랜

> moniq-designer 스펙 기반 (2026-04-19)  
> 현재 구현된 내용은 제외하고 남은 작업만 기록

---

## 우선순위 P0 — 즉시 개선 (버그/가독성)

### 1. 순위 색상 일관성 버그 수정

현재 `wanted_day_off_screen.dart`의 엔트리 카드에서 순위 배지(pill) 색이 `entryColor`를 그대로 씀.
OFF 엔트리이면 회색 순위 배지가 나와 1순위/2순위 구분이 불가능.

**수정 위치:** `_buildBody` → `itemBuilder` → 순위 배지 색상
```dart
// 현재 (잘못됨)
color: entryColor.withValues(alpha: 0.12)  // OFF면 회색 순위 배지

// 개선
final priorityColor = entry.priority == 1 ? AppColors.error : AppColors.brandOrange;
color: priorityColor.withValues(alpha: 0.12)
// Text color도 entryColor → priorityColor 로 변경
```

**영향 범위:** `wanted_day_off_screen.dart`만 (좁음)

---

### 2. 엔트리 카드 정보 계층 재구성

**현재 구조:**
```
[4px bar] [O 원형아바타 32px] [날짜 bodyMedium + 순위badge] [shiftName·reason] [X]
```

**개선 구조:**
```
[4px bar] [날짜 titleSmall w700 + 요일]  [순위 pill]  [X]
          [ShiftCodeBadge 20px] [shiftName · reason]
```

날짜가 가장 중요한 정보이므로 `titleSmall w700`으로 승격. 요일(월/화/...) 추가.  
원형 아바타(32px) 제거 → 소형 코드 뱃지(20px 정사각형)로 교체 → 카드 왼쪽 공간 회수.

**신규 private 위젯:**
```dart
class _PriorityPill extends StatelessWidget {
  // priority == 1 → AppColors.error, priority == 2 → AppColors.brandOrange
  // Container, borderRadius: AppRadius.full
  // padding: horizontal 6, vertical 2
  // Text: '1순위' / '2순위', fontSize 10, w700
}

class _ShiftCodeBadge extends StatelessWidget {
  // 20x20 정사각형, borderRadius: AppRadius.xs
  // background: entryColor.withValues(alpha: 0.15)
  // Text: code (O/D/E/N), fontSize 10, w800
}
```

---

## 우선순위 P1 — 다음 스프린트

### 3. 배너 레이아웃 재구성

**현재 문제:** 기간/마감/D-day/범례가 단일 Column에 쌓여 밀도 과다.

**개선 레이아웃:**
```
┌──────────────────────────────────────────┐
│ [수집 중 ●]                    D-3 pill  │
│ 원티드 정보를 입력해주세요               │  ← titleSmall w600
│ 근무 기간  2026.05.01 ~ 05.31            │  ← _InfoRow
│ 마감       2026.04.25  (주황 강조)       │  ← _InfoRow
│ ─────────────────────────────────────── │  ← Divider
│ ● 1순위 필수    ● 2순위 희망             │  ← 범례 가로 배치
└──────────────────────────────────────────┘
```

**신규 private 위젯:**
```dart
class _InfoRow extends StatelessWidget {
  // label: bodySmall, onSurfaceVariant, 고정폭 52px
  // value: bodySmall w600, 기본 onSurface / 긴급 시 brandOrange
}
```

배너 목표 높이: ~112px (현재 대비 약 16px 감소)

---

### 4. 바텀시트 — 근무 유형 타일 셀렉터

**현재:** `DropdownButton` (수직 목록)  
**개선:** 가로 타일 셀렉터 `_WantedTypeSelector`

```dart
class _WantedTypeSelector extends StatelessWidget {
  // 각 타일: width 72, height 64, BorderRadius.circular(AppRadius.sm)
  // 선택 상태: entryColor fill
  // 미선택: outlined (outlineVariant)
  // 타일 내부: ShiftCodeBadge(28px) + Text(label, 11px)
  // 5개 이상: SingleChildScrollView(horizontal)
}
```

타입이 4개(O/D/E/N) 이하일 때 특히 유효.

---

### 5. 바텀시트 — 우선순위 라디오 스타일

**현재:** `ChoiceChip` 두 개  
**개선:** 라디오 버튼 느낌의 가로 2-분할 컨테이너

```dart
// Row(children: [1, 2].map(...))
// 각 항목: Expanded, AnimatedContainer
// 선택 시: 우선순위 색(error/brandOrange) 배경 + 굵은 텍스트
// 미선택: outlineVariant 테두리
// 내부: Icons.radio_button_checked/unchecked + '1순위 필수' / '2순위 희망'
```

---

### 6. 바텀시트 — 오프 사유 인라인화 (AlertDialog 제거)

**현재:** 날짜 탭 → AlertDialog 팝업 → 사유 선택  
**개선:** 근무 유형이 '오프'일 때 바텀시트 안에 즉시 사유 선택 칩 표시

```dart
// 오프 선택 시 바텀시트에 인라인 표시:
if (currentShiftTypeId == null)
  Wrap(
    children: [
      if (currentPriority == 1) ...[
        _QuickReasonChip(label: '생리휴가', value: '#생리휴가'),
        _QuickReasonChip(label: '연차', value: '#연차'),
      ],
      _QuickReasonChip(label: '직접 입력', value: 'custom', icon: Icons.edit_outlined),
    ],
  )

// 날짜 탭 시: selectedDates에 currentReason 자동 적용 (AlertDialog 없음)
// 'custom' 선택 시에만 TextField 인라인으로 펼쳐짐
```

AlertDialog 2단계 흐름(날짜탭 → 팝업 → 확인) 완전 제거.

---

### 7. 캘린더 날짜 셀 — 배지 가시성 개선

**현재 문제:** `childAspectRatio: 1.0` 정사각형에 9px 폰트 배지가 너무 작음.

**개선:**
- `childAspectRatio: 0.9` (높이 10% 증가 → 배지 공간 확보)
- 선택 불가(기간 외) 셀: `opacity 0.3` (현재보다 의도 명확)

---

## 우선순위 P2 — 향후 개선

### 8. 관리자 수집 화면 — 미응답 멤버 섹션

전체 팀원 목록을 가져올 수 있다면 미응답자를 별도 섹션으로 표시.

```
응답 완료 (7명)
┌───────────────────────────────────────┐
│ [K] 김간호   5건  [05.01][05.02]...  │
└───────────────────────────────────────┘

미응답 (5명)
┌───────────────────────────────────────┐
│ [이] 이간호   아직 입력하지 않았습니다 │
└───────────────────────────────────────┘
```

**전제:** `state.allEntries`에서 응답한 userId Set 추출 후 전체 팀원과 비교.
팀 멤버 목록은 별도 provider(`teamMembersProvider`) 필요.

**섹션 헤더 위젯:**
```dart
class _SectionHeader extends StatelessWidget {
  // labelLarge w600, onSurfaceVariant
  // 오른쪽 count 배지: Container(borderRadius: full, primary.withValues(alpha: 0.12))
}
```

---

### 9. 관리자 수집 화면 — 배너 진행 바

전체 팀원 수를 알 때 응답률 시각화:

```dart
LinearProgressIndicator(
  value: respondedCount / totalMemberCount,
  backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
  color: colorScheme.primary,
  minHeight: 6,
)
// + '7/12명 응답' 텍스트
```

---

### 10. 관리자 수집 화면 — 칩 디자인 개선

Avatar(9px) 방식 대신 컨테이너 내 인라인 배치로 가독성 향상:

```dart
// 구조: [우선순위 dot 6px] [코드 10px w800] [날짜 labelSmall]
// 배경: shiftColor.withValues(alpha: 0.1)
// 테두리: shiftColor.withValues(alpha: 0.25)
// 최소 높이: 28px
```

---

### 11. 나이트 전담 뷰 설명 카드 추가

현재 아이콘+텍스트만 있는 빈 뷰에 설명 카드 추가:

```dart
Card(
  color: const Color(0xFF0061A4).withValues(alpha: 0.06),
  child: Text(
    '이 달의 나이트 근무를 전담으로 신청합니다.\n관리자가 검토 후 확정하면 적용됩니다.',
    textAlign: TextAlign.center,
  ),
)
```

---

### 12. 빈 상태 위젯 통일

현재 각 뷰마다 `Icon + Text` 직접 배치 → `MoniqEmptyState` 위젯으로 통일.

| 위치 | 현재 | 개선 |
|------|------|------|
| 엔트리 없음 | Icon + Text | `MoniqEmptyState(icon: Icons.calendar_today, ...)` |
| 응답자 없음 | Icon + Text | `MoniqEmptyState(icon: Icons.hourglass_empty, ...)` |
| 나이트 신청자 없음 | Icon + Text | `MoniqEmptyState(icon: Icons.nightlight_round, ...)` |

---

## 관련 파일

- `lib/presentation/screens/wanted/wanted_day_off_screen.dart` — P0~P1 주요 대상
- `lib/presentation/screens/wanted/wanted_request_widgets.dart` — P0, P2 대상
- `lib/presentation/theme/app_colors.dart` — 새 토큰 추가 불필요 (기존 활용)
