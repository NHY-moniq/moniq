---
name: moniq-dev
description: "Moniq 개발 오케스트레이터. 에이전트 팀 조율, Phase별 구현 관리, 통합 검증. 'moniq 개발', '다음 phase', '구현 시작' 시 사용."
---

# Moniq Dev — 개발 오케스트레이터

Moniq 프로젝트의 개발 팀을 조율하는 오케스트레이터 스킬.

## 에이전트 팀

| 에이전트 | 역할 | 스킬 |
|---------|------|------|
| moniq-pm | 앱 방향성 검증, UX 일관성 감독, 스펙 정합성 | - |
| moniq-designer | UI/UX 디자인, 디자인 시스템 | moniq-design-system |
| moniq-backend | Supabase 백엔드, Data 레이어 | moniq-schema |
| moniq-ui | Flutter Presentation 레이어 | moniq-screen |
| moniq-scheduler | 근무표 생성 알고리즘 | moniq-schedule-gen |
| moniq-reviewer | 기능 정합성, 컨벤션 준수 코드 리뷰 | - |
| moniq-guardian | 코드 품질 감독, 파일 분리, 비효율 탐지 | - |

## Phase별 워크플로우

### Phase 1: 기반 구성
```
순차: moniq-setup 스킬 실행 (프로젝트 초기화)
병렬:
  - moniq-designer: 디자인 시스템 정의 (컬러, 타이포, 스페이싱, 테마)
  - moniq-backend: Auth 스키마, users/teams/team_members 테이블, RLS
  - moniq-ui: 앱 셸 (하단 탭, 라우터), 로그인 화면, 빈 상태 화면
통합: 팀 생성/참여 플로우 연결
```

### Phase 2: 핵심 캘린더
```
순차: moniq-backend → shifts/schedules 테이블 및 Repository
병렬:
  - moniq-ui: 홈 개인 캘린더, 팀 공유 캘린더, 날짜 상세 Bottom Sheet
  - moniq-backend: 캘린더 데이터 쿼리 최적화
통합: 즐겨찾기 팀 동작 검증
```

### Phase 3: 팀 관리
```
병렬:
  - moniq-backend: shift_types, shift_rules 테이블 및 Repository
  - moniq-ui: 팀 리스트, 팀 상세, 멤버 섹션, 근무 유형 관리, 룰 관리
통합: 관리자 권한 기반 UI 분기 검증
```

### Phase 4: 근무표 생성
```
순차:
  1. moniq-scheduler: 생성 알고리즘 구현 및 단위 테스트
  2. moniq-backend: 생성 결과 저장 Repository/Edge Function
  3. moniq-ui: 생성 폼, 미리보기, 게시 플로우
통합: 전체 생성→미리보기→게시 E2E 검증
```

### Phase 5: 요청
```
병렬:
  - moniq-backend: requests 테이블, RLS, 상태 관리
  - moniq-ui: 요청 생성 화면, 요청 목록, 요청 상세
통합: 교환/변경 요청 제출→승인/거절 플로우 검증
```

### Phase 6: 설정
```
병렬:
  - moniq-backend: app_settings 테이블 및 Repository
  - moniq-ui: 테마, 폰트 크기, 캘린더 시작 요일, 계정 설정
통합: 설정 변경 → 앱 전체 반영 검증
```

## 에이전트 간 데이터 흐름

```
moniq-designer (디자인 토큰/컴포넌트 스펙)
       ↓
moniq-backend (Repository/Provider)
       ↓
moniq-ui (ViewModel → Provider 참조 + 디자인 시스템 적용)
       ↑
moniq-scheduler (UseCase → Repository 인터페이스)
```

## 작업 프로세스

### 작업 시작 전
1. **moniq-pm**: 요구사항 정리, 방향성 확인, 우선순위 결정
2. main 브랜치에서 feature 브랜치 생성 (`fix/xxx` 또는 `feat/xxx`)

### 작업 중
3. **moniq-ui / moniq-backend**: 구현 (병렬 가능한 건 병렬)
4. 논리적 기능 단위로 커밋 분리

### 작업 후
5. **moniq-reviewer**: 기능 정합성, 컨벤션 준수 리뷰
6. **moniq-guardian**: 코드 품질, 파일 크기, 비효율 탐지 리뷰
7. **moniq-pm**: 전체 동선 및 방향성 최종 검증

## 통합 검증 체크리스트

Phase 완료 시 확인:
- [ ] 빌드 성공 (`flutter build`)
- [ ] 린트 통과 (`flutter analyze`)
- [ ] 테스트 통과 (`flutter test`)
- [ ] 빈 상태/로딩/오류 상태 모두 처리
- [ ] 관리자/멤버 역할별 UI 분기 정상
- [ ] 다크 모드 정상 렌더링
- [ ] 코드 품질 리포트 통과 (moniq-guardian)
- [ ] PM 방향성 검증 통과 (moniq-pm)

## 참고

- 전체 스펙: `spec.md`
- 프로젝트 컨벤션: `references/project-conventions.md`
- Apple 앱 심사 가이드라인: `references/apple-review-guidelines.md`
