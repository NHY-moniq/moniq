-- 요청 삭제 정책: 본인이 만든 요청(취소된 건) 또는 관리자
-- 상태에 상관없이 허용하되, 보통은 앱에서 'cancelled'만 삭제

CREATE POLICY "Users can delete own requests"
  ON public.requests FOR DELETE
  USING (requester_user_id = auth.uid());

CREATE POLICY "Team admins can delete any requests"
  ON public.requests FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = requests.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role = 'admin'
        AND team_members.is_deleted = false
    )
  );
