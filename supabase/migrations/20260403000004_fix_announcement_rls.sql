-- Fix announcement RLS to use get_my_team_ids() helper function
DROP POLICY IF EXISTS "Team members can view announcements" ON public.team_announcements;
DROP POLICY IF EXISTS "Team admins can manage announcements" ON public.team_announcements;

CREATE POLICY "Team members can view announcements"
  ON public.team_announcements FOR SELECT
  USING (team_id IN (SELECT get_my_team_ids()));

CREATE POLICY "Team admins can manage announcements"
  ON public.team_announcements FOR ALL
  USING (team_id IN (SELECT get_my_admin_team_ids()));
