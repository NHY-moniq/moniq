---
name: code-review
description: "코드 리뷰 및 아키텍처 준수 검증을 수행한다. '코드 리뷰', '리뷰', '검증', '품질 확인', 'QA' 요청 시 사용."
---

# Code Review — 코드 품질 검증

## 목적
Moniq 프로젝트의 코드 품질, 아키텍처 준수, 보안을 검증한다.

## 워크플로우

### Step 1: 대상 파일 수집
- 변경된 파일 목록 확인 (git diff 또는 명시적 지정)
- 관련 spec.md 섹션 참조

### Step 2: 아키텍처 검증
| 체크 항목 | 기준 |
|----------|------|
| 레이어 분리 | Presentation → Domain → Data 단방향 의존 |
| ViewModel 위치 | `lib/presentation/view_models/` |
| 리포지토리 인터페이스 | `lib/domain/repositories/` |
| 리포지토리 구현 | `lib/data/repositories/` |
| Supabase 직접 호출 | Data 레이어에서만 허용 |
| go_router 설정 | `lib/presentation/routes/` |
| 비즈니스 로직 위치 | Domain 레이어 또는 ViewModel (Widget 내부 금지) |

### Step 3: 코드 품질 검증
- 네이밍 컨벤션 (lowerCamelCase for vars, UpperCamelCase for classes)
- 불필요한 중복 코드
- 매직 넘버/문자열 하드코딩
- 적절한 에러 핸들링
- 상태 처리 (Loading/Empty/Error/Normal)

### Step 4: 보안 검증
- RLS 정책 적절성
- 사용자 입력 검증
- API 키/시크릿 노출 여부
- SQL injection 가능성
- 권한 체크 누락

### Step 5: UX 일관성 검증
- 디자인 명세 대비 구현 일치
- 터치 타깃 크기 (최소 44x44)
- Empty/Error 상태 처리 존재 여부
- 접근성 (시맨틱 위젯, 라벨)

### Step 6: 리포트 생성

```markdown
## 리뷰 요약
- 전체 판정: ✅ / ⚠️ / ❌
- 🔴 Critical: N건
- 🟡 Warning: N건
- 🟢 Suggestion: N건

## 상세 피드백
### [파일경로:라인]
- [🔴/🟡/🟢] 내용
- 수정 제안: ...
```

## 심각도 분류 기준

| 심각도 | 기준 | 예시 |
|--------|------|------|
| 🔴 Critical | 반드시 수정 | 아키텍처 위반, 보안 취약점, 크래시 원인 |
| 🟡 Warning | 강력 권장 | 성능 이슈, 누락된 에러 처리, 네이밍 불일치 |
| 🟢 Suggestion | 선택 개선 | 리팩터링 제안, 더 나은 패턴, 가독성 |

## 출력 규칙
- 모든 피드백은 구체적 파일/라인 참조를 포함한다
- 수정 방법을 코드로 제시한다
- 긍정적 피드백도 포함한다 (잘된 부분)
