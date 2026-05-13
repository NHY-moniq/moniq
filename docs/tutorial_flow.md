# 팀 튜토리얼 플로우

## 개요
팀 생성 완료 후 "팀 설정하기" 버튼을 눌렀을 때 팀 유형별로 튜토리얼이 자동 시작됩니다.
Spotlight + 말풍선 오버레이 형태로, 주요 기능 카드를 순서대로 강조해서 설명합니다.

## 트리거 조건
- 팀 생성 성공 → `TeamCreateSuccessView`에서 "팀 설정하기" 클릭
- `tutorialPendingProvider`에 `(teamId, teamType)` 저장
- `TeamDetailScreen`이 해당 teamId를 watch하다가 data 로드 완료 시 튜토리얼 시작
- 한 번 시작 후 `_tutorialLaunched = true`로 중복 실행 방지

## 조직 팀 (5단계)

| 단계 | 강조 카드 | 제목 | 설명 |
|------|-----------|------|------|
| 1/5 | 멤버 관리 | 멤버 관리 | 초대 코드를 공유해서 팀원을 초대하고, 역할과 숙련도를 설정하세요. |
| 2/5 | 팀 상세 설정 | 팀 상세 설정 | 근무 유형(데이·이브닝·나이트 등)과 고정 규칙을 설정하면 자동 생성 품질이 높아져요. |
| 3/5 | 원티드 수집 | 원티드 수집 | 근무표 생성 전 팀원들이 원하는 날짜를 미리 수집할 수 있어요. 관리자만 사용 가능해요. |
| 4/5 | 근무표 자동 생성 | 근무표 자동 생성 | 설정한 규칙과 원티드를 반영해 근무표를 자동으로 만들어요. |
| 5/5 | 교환/변경 요청 | 교환/변경 요청 | 근무표 확정 후 팀원 간 근무 교환·변경 요청을 여기서 관리해요. |

## 개인 팀 (2단계)

| 단계 | 강조 카드 | 제목 | 설명 |
|------|-----------|------|------|
| 1/2 | 멤버 관리 | 멤버 초대 | 초대 코드를 공유해서 친구들을 팀에 초대하세요. |
| 2/2 | 멤버 근무 현황 | 멤버 근무 현황 | 각 멤버의 즐겨찾기 팀 근무가 여기서 보여요. 언제 다 같이 쉬는지 한눈에 확인하세요. |

## 구현 구조

```
lib/
  data/providers/
    tutorial_providers.dart          ← tutorialPendingProvider (StateProvider)
  presentation/widgets/tutorial/
    tutorial_step.dart               ← TutorialStep 모델
    tutorial_controller.dart         ← TutorialController (OverlayEntry 관리)
    tutorial_overlay.dart            ← TutorialOverlayWidget + _SpotlightPainter
```

## UX 동작
- 어두운 scrim (0xCC000000) + 타깃 카드 영역만 밝게 표시
- 말풍선: 타깃 아래 공간이 220px 미만이면 위에 표시
- 타깃 외 영역 탭: 다음 단계로 진행
- "건너뛰기": 튜토리얼 즉시 종료
- "다음 →" / 마지막 단계에서 "완료": 순서대로 진행
