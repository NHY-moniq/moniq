---
name: ui-design
description: "UI/UX 디자인 명세를 생성한다. 화면 레이아웃, 디자인 시스템, 컴포넌트 스펙 설계. '화면 디자인', 'UI 설계', '디자인 시스템', '컴포넌트 디자인', '레이아웃 설계' 요청 시 사용."
---

# UI Design — UI/UX 디자인 명세 생성

## 목적
spec.md 기반으로 화면별 디자인 명세와 디자인 시스템을 생성한다.

## 워크플로우

### Step 1: 디자인 시스템 정의
대상 화면 작업 전, 프로젝트 디자인 시스템이 정의되어 있는지 확인하고 없으면 먼저 생성한다.

#### 색상 체계
- Primary, Secondary, Tertiary
- Surface, Background, Error
- Shift type별 색상 (Day=파랑, Evening=주황, Night=보라, Off=회색 등)
- 다크 모드 매핑

#### 타이포그래피 스케일
- Display, Headline, Title, Body, Label, Caption
- 각 단계별 fontSize, fontWeight, letterSpacing

#### 간격 체계
- 4pt 기반 그리드: 4, 8, 12, 16, 20, 24, 32, 48
- 컴포넌트 내부 패딩 / 컴포넌트 간 간격 규칙

#### 기본 컴포넌트
- 버튼 (Primary, Secondary, Text, Icon)
- 카드 (표준, Today 카드, Shift 카드)
- 입력 필드
- 바텀 네비게이션
- 앱 바
- 바텀 시트 / 모달

### Step 2: 화면 구조 명세
각 화면에 대해 다음을 정의한다:

```markdown
## [화면 이름]

### 레이아웃 구조
- 전체 배치 (AppBar + Body + BottomNav 등)
- 섹션 순서와 계층

### 컴포넌트 목록
| 컴포넌트 | 위치 | 동작 |
|---------|------|------|
| ... | ... | ... |

### 상태별 변형
- Loading: ...
- Empty: ...
- Error: ...
- Normal: ...

### 인터랙션
- 탭/스와이프/롱프레스 동작 정의

### 반응형 가이드 (해당 시)
- Mobile: ...
- Tablet/Web: ...
```

### Step 3: 캘린더 전용 디자인
Moniq의 핵심인 캘린더 컴포넌트에 대해 별도 상세 명세:
- 월간 캘린더 셀 구조 (날짜 + 근무 표시 dot/badge)
- 주간 뷰 레이아웃
- 일간 뷰 레이아웃
- 선택 날짜 하이라이트
- Today 강조
- Roster 패널 구조 (근무 유형별 그룹)

### Step 4: 명세 저장
생성된 디자인 명세는 `docs/design/` 하위에 저장한다:
- `docs/design/design-system.md` — 디자인 시스템
- `docs/design/screens/{screen-name}.md` — 화면별 명세

## 출력 규칙
- Flutter로 구현 가능한 수준의 구체적 명세를 작성한다
- Material Design 3 가이드라인을 참조하되, Moniq 스타일로 커스터마이즈한다
- 색상은 Hex 코드로, 크기는 dp/pt로 명시한다
- ASCII 와이어프레임은 복잡한 레이아웃에만 사용한다
