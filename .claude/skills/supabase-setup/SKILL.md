---
name: supabase-setup
description: "Supabase 스키마, RLS, 마이그레이션, Edge Function을 설정한다. 'DB 스키마', '마이그레이션', 'RLS', 'Edge Function', 'Supabase 설정' 요청 시 사용."
---

# Supabase Setup — 백엔드 인프라 설정

## 목적
Moniq의 Supabase 백엔드를 설정하고, Flutter Data 레이어와 연결한다.

## 워크플로우

### Step 1: 마이그레이션 SQL 작성
`supabase/migrations/` 하위에 타임스탬프 기반 파일 생성:

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_create_tables.sql
```

**테이블 생성 순서 (FK 종속성 기준):**
1. `users` (Supabase Auth와 연동 — profiles 테이블로 확장)
2. `teams`
3. `team_members`
4. `shift_types`
5. `shift_rules`
6. `schedules`
7. `shifts`
8. `requests`
9. `app_settings`

### Step 2: RLS 정책 설정
각 테이블에 대해 최소 권한 원칙 적용:

```sql
-- 기본: 모든 접근 차단
ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;

-- 패턴별 정책:
-- 1. 본인 데이터만 조회/수정 (users, app_settings)
-- 2. 팀 멤버만 조회, 관리자만 수정 (teams, shift_types, schedules, shifts)
-- 3. 요청자/관리자만 접근 (requests)
```

### Step 3: Flutter Data 레이어 구현

#### DTO (Data Transfer Object)
```dart
// lib/data/models/{entity}_dto.dart
@freezed
class EntityDto with _$EntityDto {
  const factory EntityDto({
    required String id,
    // ... fields matching DB columns
  }) = _EntityDto;

  factory EntityDto.fromJson(Map<String, dynamic> json) =>
      _$EntityDtoFromJson(json);
}
```

#### Data Source
```dart
// lib/data/data_sources/{entity}_data_source.dart
class EntityDataSource {
  final SupabaseClient _client;

  Future<List<EntityDto>> getAll() async {
    final response = await _client.from('entities').select();
    return response.map((e) => EntityDto.fromJson(e)).toList();
  }
}
```

#### Repository Implementation
```dart
// lib/data/repositories/{entity}_repository_impl.dart
class EntityRepositoryImpl implements EntityRepository {
  final EntityDataSource _dataSource;

  @override
  Future<List<Entity>> getAll() async {
    final dtos = await _dataSource.getAll();
    return dtos.map((dto) => dto.toDomain()).toList();
  }
}
```

### Step 4: Edge Function (필요 시)
```bash
supabase functions new {function-name}
```
- Deno/TypeScript로 작성
- 입력 검증 필수
- 적절한 HTTP 상태 코드 반환

### Step 5: 검증
```bash
supabase db reset        # 마이그레이션 적용 테스트
supabase functions serve  # Edge Function 로컬 테스트
```

## 출력 규칙
- SQL은 멱등성을 고려한다 (IF NOT EXISTS 등)
- RLS 정책은 테이블별로 명확히 문서화한다
- DTO ↔ Domain 변환 로직을 명시한다
- 민감 정보(API 키 등)를 코드에 하드코딩하지 않는다
