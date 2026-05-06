# Screenshots

이 폴더에 실제 앱 스크린샷 PNG를 넣으면 랜딩 페이지가 자동으로 mock 대신 사용해요.

| 파일명 | 사용 위치 | 권장 비율 |
|--------|----------|----------|
| `personal_calendar.png` | Feature 1 — 개인 캘린더 동기화 | 9:19.5 (iPhone) |
| `team_calendar.png` | Feature 2 — 팀 캘린더 | 9:19.5 |
| `schedule_rules.png` | Feature 3-1 — 자동 생성 + 규칙 | 9:19.5 |
| `custom_rules.png` | Feature 3-2 — 자연어 커스텀 규칙 | 9:19.5 |
| `shift_day.png` | Per-shift theming — Day | 9:19.5 |
| `shift_evening.png` | Per-shift theming — Evening | 9:19.5 |
| `shift_night.png` | Per-shift theming — Night | 9:19.5 |

권장 사양:
- 해상도 750×1624 이상 (고밀도 디스플레이 대응)
- 포맷 PNG (배경 cream `#FCF6E3` 또는 투명)
- 상단 status bar 포함 가능 (PhoneFrame이 자체 notch를 그리므로 top 여백 살짝 남겨도 무방)

PNG가 없으면 `ScreenshotImage`가 자동으로 mock UI를 fallback으로 표시합니다.
