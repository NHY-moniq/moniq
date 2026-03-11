-- =============================================================================
-- Phase 2: Calendar Schema
-- shift_types, schedules, shifts + RLS + indexes
-- =============================================================================

-- =============================================================================
-- Table: shift_types (팀별 근무 유형 정의)
-- =============================================================================
CREATE TABLE public.shift_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  start_time TIME,
  end_time TIME,
  color TEXT NOT NULL DEFAULT '#A0AEC0',
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(team_id, code)
);

CREATE TRIGGER shift_types_updated_at
  BEFORE UPDATE ON public.shift_types
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_shift_types_team_id ON public.shift_types(team_id) WHERE is_active;

-- =============================================================================
-- Table: schedules (게시된 근무표 버전)
-- =============================================================================
CREATE TABLE public.schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  version_no INT NOT NULL DEFAULT 1,
  previous_version_id UUID REFERENCES public.schedules(id),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  created_by UUID NOT NULL REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER schedules_updated_at
  BEFORE UPDATE ON public.schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_schedules_team_id ON public.schedules(team_id);
CREATE INDEX idx_schedules_period ON public.schedules(team_id, period_start, period_end);

-- =============================================================================
-- Table: shifts (개별 근무 배정)
-- =============================================================================
CREATE TABLE public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  shift_date DATE NOT NULL,
  shift_type_id UUID NOT NULL REFERENCES public.shift_types(id),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER shifts_updated_at
  BEFORE UPDATE ON public.shifts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_shifts_schedule_id ON public.shifts(schedule_id);
CREATE INDEX idx_shifts_user_date ON public.shifts(user_id, shift_date);
CREATE INDEX idx_shifts_team_date ON public.shifts(team_id, shift_date);
CREATE INDEX idx_shifts_composite ON public.shifts(team_id, shift_date, shift_type_id);

-- =============================================================================
-- Seed: 기존 팀에 기본 근무 유형 4개 추가
-- =============================================================================
INSERT INTO public.shift_types (team_id, name, code, start_time, end_time, color, display_order)
SELECT
  t.id,
  s.name,
  s.code,
  s.start_time,
  s.end_time,
  s.color,
  s.display_order
FROM public.teams t
CROSS JOIN (
  VALUES
    ('데이', 'D', '07:00'::TIME, '15:00'::TIME, '#F0C040', 1),
    ('이브닝', 'E', '15:00'::TIME, '23:00'::TIME, '#E8923A', 2),
    ('나이트', 'N', '23:00'::TIME, '07:00'::TIME, '#5A8BB5', 3),
    ('오프', 'O', NULL::TIME, NULL::TIME, '#A0AEC0', 4)
) AS s(name, code, start_time, end_time, color, display_order)
WHERE NOT t.is_deleted;

-- =============================================================================
-- RLS Policies: shift_types
-- =============================================================================
ALTER TABLE public.shift_types ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shift_types_select_team_member"
  ON public.shift_types FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND NOT is_deleted
    )
  );

CREATE POLICY "shift_types_all_team_admin"
  ON public.shift_types FOR ALL
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role = 'admin' AND NOT is_deleted
    )
  );

-- =============================================================================
-- RLS Policies: schedules
-- =============================================================================
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "schedules_select_team_member"
  ON public.schedules FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND NOT is_deleted
    )
  );

CREATE POLICY "schedules_all_team_admin"
  ON public.schedules FOR ALL
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role = 'admin' AND NOT is_deleted
    )
  );

-- =============================================================================
-- RLS Policies: shifts
-- =============================================================================
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shifts_select_team_member"
  ON public.shifts FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND NOT is_deleted
    )
  );

CREATE POLICY "shifts_all_team_admin"
  ON public.shifts FOR ALL
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role = 'admin' AND NOT is_deleted
    )
  );
