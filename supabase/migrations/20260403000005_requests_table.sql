-- Requests table: 근무 교환/변경 요청
CREATE TABLE public.requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  requester_user_id UUID NOT NULL REFERENCES public.users(id),
  source_shift_id UUID,
  change_type TEXT NOT NULL CHECK (change_type IN ('day_off', 'shift_change', 'swap', 'schedule_change')),
  requested_date DATE,
  requested_shift_type_id UUID,
  reason TEXT,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by UUID REFERENCES public.users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER requests_updated_at
  BEFORE UPDATE ON public.requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_requests_team ON public.requests(team_id);
CREATE INDEX idx_requests_requester ON public.requests(requester_user_id);

ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;

-- 팀 멤버는 해당 팀의 요청을 조회 가능
CREATE POLICY "Team members can view requests"
  ON public.requests FOR SELECT
  USING (team_id IN (SELECT get_my_team_ids()));

-- 팀 멤버는 자신의 요청을 생성 가능
CREATE POLICY "Team members can create requests"
  ON public.requests FOR INSERT
  WITH CHECK (
    requester_user_id = auth.uid()
    AND team_id IN (SELECT get_my_team_ids())
  );

-- 본인 요청 취소 또는 관리자 승인/거절
CREATE POLICY "Users can update own or admin can manage"
  ON public.requests FOR UPDATE
  USING (
    requester_user_id = auth.uid()
    OR team_id IN (SELECT get_my_admin_team_ids())
  );
