-- =============================================================================
-- 본인 shift INSERT 정책
--
-- 기존: shifts_all_team_admin (관리자만 INSERT)
-- 추가: 팀원이 본인(user_id=auth.uid) shift를 새로 생성할 수 있도록 허용
--       (OFF 상태에서 본인이 직접 근무를 추가하는 UX 지원)
-- =============================================================================

DROP POLICY IF EXISTS "shifts_insert_self" ON public.shifts;
CREATE POLICY "shifts_insert_self"
  ON public.shifts FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND NOT is_deleted
    )
  );
