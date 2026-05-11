-- Shift Handovers: 시프트 인수인계 노트
-- 같은 팀의 시프트 멤버들이 함께 보는 공동 인계 노트.
-- 1:1 인계가 아니라 (team_id, shift_type, shift_date) 단위의 공유 메모.
-- 환자 식별 정보(이름/병실/차트번호 등)는 입력 금지 — 클라이언트 가이드로 안내.

CREATE TABLE public.shift_handovers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  shift_type_id UUID NOT NULL REFERENCES public.shift_types(id) ON DELETE CASCADE,
  shift_date DATE NOT NULL,
  body TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- updated_at 자동 갱신 (다른 테이블과 동일한 trigger 함수 재사용)
CREATE TRIGGER shift_handovers_updated_at
  BEFORE UPDATE ON public.shift_handovers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 팀별 최신순 조회용 복합 인덱스. is_deleted=false 인 행만 인덱싱하여 핫셋 축소.
CREATE INDEX idx_shift_handovers_team_date
  ON public.shift_handovers(team_id, shift_date DESC, created_at DESC)
  WHERE NOT is_deleted;

ALTER TABLE public.shift_handovers ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RLS Policies
-- get_my_team_ids() 헬퍼를 사용하여 재귀 방지 (20260311000003 참고).
-- =============================================================================

-- SELECT: 같은 팀 멤버이고 soft delete 되지 않은 행만 조회
CREATE POLICY "shift_handovers_select_team_member"
  ON public.shift_handovers FOR SELECT
  USING (
    team_id IN (SELECT get_my_team_ids())
    AND NOT is_deleted
  );

-- INSERT: 본인이 해당 팀의 멤버이고, created_by 가 본인일 때만 작성 가능
CREATE POLICY "shift_handovers_insert_team_member"
  ON public.shift_handovers FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND team_id IN (SELECT get_my_team_ids())
  );

-- UPDATE: 본인이 작성한 행만 수정 (soft delete 포함)
-- 팀 변경/타인 행 가로채기 방지를 위해 WITH CHECK 도 강제.
CREATE POLICY "shift_handovers_update_own"
  ON public.shift_handovers FOR UPDATE
  USING (created_by = auth.uid())
  WITH CHECK (
    created_by = auth.uid()
    AND team_id IN (SELECT get_my_team_ids())
  );

-- DELETE: 사용하지 않음 (소프트 삭제만). 정책 미정의 = 클라이언트 DELETE 차단.
-- 30일 retention 은 service_role 로 동작하는 pg_cron 이 RLS 우회로 처리.

-- =============================================================================
-- Retention: 30일 이상 된 행 hard delete (pg_cron)
-- 패턴: 20260511000001_notifications_retention.sql
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  PERFORM cron.unschedule('moniq_handover_retention');
EXCEPTION WHEN OTHERS THEN NULL;
END$$;

SELECT cron.schedule(
  'moniq_handover_retention',
  '30 3 * * *', -- 매일 03:30 UTC (notifications 03:15 과 분산)
  $$
    DELETE FROM public.shift_handovers
    WHERE created_at < now() - interval '30 days';
  $$
);
