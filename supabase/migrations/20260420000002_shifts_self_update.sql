-- =============================================================================
-- 본인 shift update/delete 정책
--
-- 기존: shifts_all_team_admin (관리자만 ALL)
-- 추가: 팀원이 본인 shift는 update/delete 할 수 있도록 허용 (팀 캘린더에서
--       본인 근무 유형 변경 / 삭제 UX 지원)
-- =============================================================================

DROP POLICY IF EXISTS "shifts_update_self" ON public.shifts;
CREATE POLICY "shifts_update_self"
  ON public.shifts FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "shifts_delete_self" ON public.shifts;
CREATE POLICY "shifts_delete_self"
  ON public.shifts FOR DELETE
  USING (user_id = auth.uid());
