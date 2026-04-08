-- Phase A: 멤버 속성 컬럼 추가 + schedule_feedback 테이블 생성

-- 1. team_members: 멤버 속성 추가
ALTER TABLE public.team_members
  ADD COLUMN IF NOT EXISTS night_exempt   BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS day_only       BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS night_dedicated BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS skill_level_num INT;

-- 2. schedule_feedback: 퍼블리시된 스케줄에 대한 피드백 (버전당 1건)
CREATE TABLE IF NOT EXISTS public.schedule_feedback (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id     UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  team_id         UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  overall_rating  INT CHECK (overall_rating BETWEEN 1 AND 5),
  -- rule_ratings: { "wanted": 1|-1, "avoid_pattern": 1|-1, "skill_balance": 1|-1 }
  -- 1=만족, -1=불만, 미평가 시 키 없음
  rule_ratings    JSONB,
  notes           TEXT,
  created_by      UUID REFERENCES auth.users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(schedule_id)
);

-- RLS
ALTER TABLE public.schedule_feedback ENABLE ROW LEVEL SECURITY;

-- 팀 멤버만 조회 가능
CREATE POLICY "team members can view feedback"
  ON public.schedule_feedback FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE tm.team_id = schedule_feedback.team_id
        AND tm.user_id = auth.uid()
        AND tm.is_deleted = FALSE
    )
  );

-- 팀 관리자만 작성/수정 가능
CREATE POLICY "team admin can insert feedback"
  ON public.schedule_feedback FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE tm.team_id = schedule_feedback.team_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'admin'
        AND tm.is_deleted = FALSE
    )
  );

CREATE POLICY "team admin can update feedback"
  ON public.schedule_feedback FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE tm.team_id = schedule_feedback.team_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'admin'
        AND tm.is_deleted = FALSE
    )
  );
