-- Wanted Feature: 희망 휴무 수집 요청 + 엔트리 테이블
-- 관리자가 수집 요청을 생성하면, 팀원들이 희망 휴무일을 입력

-- =============================================================================
-- Table: wanted_requests (관리자가 생성하는 수집 요청)
-- =============================================================================
CREATE TABLE public.wanted_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  deadline TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'collecting' CHECK (status IN ('collecting', 'closed')),
  created_by UUID NOT NULL REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_wanted_requests_team ON public.wanted_requests(team_id);
CREATE INDEX idx_wanted_requests_status ON public.wanted_requests(team_id, status);

-- =============================================================================
-- Table: wanted_entries (팀원이 입력한 희망 휴무일)
-- =============================================================================
CREATE TABLE public.wanted_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wanted_request_id UUID NOT NULL REFERENCES public.wanted_requests(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  wanted_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(wanted_request_id, user_id, wanted_date)
);

CREATE INDEX idx_wanted_entries_request ON public.wanted_entries(wanted_request_id);
CREATE INDEX idx_wanted_entries_user ON public.wanted_entries(user_id);

-- =============================================================================
-- RLS Policies
-- =============================================================================
ALTER TABLE public.wanted_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wanted_entries ENABLE ROW LEVEL SECURITY;

-- wanted_requests: 팀 멤버는 조회 가능, 관리자만 생성/수정
CREATE POLICY "Team members can view wanted requests"
  ON public.wanted_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = wanted_requests.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.is_deleted = false
    )
  );

CREATE POLICY "Team admins can create wanted requests"
  ON public.wanted_requests FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = wanted_requests.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role = 'admin'
        AND team_members.is_deleted = false
    )
  );

CREATE POLICY "Team admins can update wanted requests"
  ON public.wanted_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = wanted_requests.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role = 'admin'
        AND team_members.is_deleted = false
    )
  );

-- wanted_entries: 팀 멤버는 조회 가능, 본인 것만 생성/삭제
CREATE POLICY "Team members can view wanted entries"
  ON public.wanted_entries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = wanted_entries.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.is_deleted = false
    )
  );

CREATE POLICY "Users can insert own wanted entries"
  ON public.wanted_entries FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = wanted_entries.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.is_deleted = false
    )
  );

CREATE POLICY "Users can delete own wanted entries"
  ON public.wanted_entries FOR DELETE
  USING (user_id = auth.uid());
