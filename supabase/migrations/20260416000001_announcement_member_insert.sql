-- 팀원도 공지사항 작성 가능하도록 RLS 완화
-- (기존: admin만 가능 → 변경: 팀 멤버 누구나 insert)

-- 기존 admin-only ALL 정책 삭제 후 action별로 재정의
DROP POLICY IF EXISTS "Team admins can manage announcements" ON public.team_announcements;

-- 팀 멤버는 본인 명의로 공지 생성 가능
CREATE POLICY "Team members can insert announcements"
  ON public.team_announcements FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND team_id IN (SELECT get_my_team_ids())
  );

-- 본인 공지 수정 가능
CREATE POLICY "Members can update own announcements"
  ON public.team_announcements FOR UPDATE
  USING (created_by = auth.uid());

-- 관리자는 팀 내 모든 공지 수정/삭제 가능
CREATE POLICY "Team admins can update team announcements"
  ON public.team_announcements FOR UPDATE
  USING (team_id IN (SELECT get_my_admin_team_ids()));

CREATE POLICY "Team admins can delete team announcements"
  ON public.team_announcements FOR DELETE
  USING (team_id IN (SELECT get_my_admin_team_ids()));

-- 본인 공지 삭제 가능
CREATE POLICY "Members can delete own announcements"
  ON public.team_announcements FOR DELETE
  USING (created_by = auth.uid());
