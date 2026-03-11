---
name: moniq-schema
description: "Supabase 스키마 및 마이그레이션 관리. 테이블 생성, RLS 정책, 인덱스, Edge Function. '스키마', '마이그레이션', 'RLS' 시 사용."
---

# Moniq Schema — Supabase 스키마 관리

## 테이블 공통 규칙

모든 테이블에 다음 필드를 포함한다:
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `is_deleted BOOLEAN NOT NULL DEFAULT false`

`updated_at` 자동 갱신 트리거:
```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 각 테이블에 적용
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.{table_name}
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

소프트 삭제 쿼리 패턴:
```sql
-- 읽기 시 is_deleted = false 필터 항상 적용
SELECT * FROM public.teams WHERE is_deleted = false;
-- 삭제 시 is_deleted = true로 업데이트
UPDATE public.teams SET is_deleted = true WHERE id = $1;
```

## 테이블 정의 (spec 섹션 14 기반)

### users
```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);
```

### teams
```sql
CREATE TABLE public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  team_type TEXT NOT NULL CHECK (team_type IN ('organizational', 'personal')),
  icon TEXT,
  invite_code TEXT UNIQUE DEFAULT encode(gen_random_bytes(6), 'hex'),
  created_by UUID NOT NULL REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);
```

### team_members
```sql
CREATE TABLE public.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (team_id, user_id)
);
```

### shift_types
```sql
CREATE TABLE public.shift_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  start_time TIME,
  end_time TIME,
  color TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (team_id, code)
);
```

### shift_rules
```sql
CREATE TABLE public.shift_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  rule_type TEXT NOT NULL,
  rule_payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);
```

### schedules
```sql
CREATE TABLE public.schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  created_by UUID NOT NULL REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);
```

### shifts
```sql
CREATE TABLE public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id),
  shift_date DATE NOT NULL,
  shift_type_id UUID NOT NULL REFERENCES public.shift_types(id),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);
```

### requests
```sql
CREATE TABLE public.requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  requester_user_id UUID NOT NULL REFERENCES public.users(id),
  request_type TEXT NOT NULL CHECK (request_type IN ('swap', 'change')),
  source_shift_id UUID NOT NULL REFERENCES public.shifts(id),
  target_user_id UUID REFERENCES public.users(id),
  target_shift_id UUID REFERENCES public.shifts(id),
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by UUID REFERENCES public.users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);
```

### app_settings
```sql
CREATE TABLE public.app_settings (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  theme_mode TEXT NOT NULL DEFAULT 'system' CHECK (theme_mode IN ('light', 'dark', 'system')),
  font_scale REAL NOT NULL DEFAULT 1.0,
  calendar_start_day INTEGER NOT NULL DEFAULT 1 CHECK (calendar_start_day IN (0, 1)),
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  external_calendar_connected BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);
```

## RLS 정책 패턴

```sql
-- 읽기: 팀 멤버만
CREATE POLICY "team_members_read" ON public.shifts
  FOR SELECT USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
    )
  );

-- 쓰기: 팀 관리자만
CREATE POLICY "team_admin_write" ON public.shifts
  FOR INSERT WITH CHECK (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
```

## 마이그레이션 작성 규칙

1. 파일명: `supabase/migrations/YYYYMMDDHHMMSS_description.sql`
2. 한 파일에 관련 테이블을 그룹으로 작성
3. RLS 활성화 및 정책을 같은 파일에 포함
4. 필요한 인덱스를 함께 생성
5. 롤백 불가능한 변경은 별도 파일로 분리

## 인덱스 가이드

```sql
-- 자주 조회되는 외래 키
CREATE INDEX idx_shifts_schedule_id ON public.shifts(schedule_id);
CREATE INDEX idx_shifts_user_date ON public.shifts(user_id, shift_date);
CREATE INDEX idx_team_members_user ON public.team_members(user_id);
CREATE INDEX idx_requests_team_status ON public.requests(team_id, status);
```
