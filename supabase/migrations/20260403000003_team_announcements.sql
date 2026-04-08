-- Team Announcements: 팀 공지사항
CREATE TABLE public.team_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  created_by UUID NOT NULL REFERENCES public.users(id),
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER team_announcements_updated_at
  BEFORE UPDATE ON public.team_announcements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_team_announcements_team ON public.team_announcements(team_id);

ALTER TABLE public.team_announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Team members can view announcements"
  ON public.team_announcements FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = team_announcements.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.is_deleted = false
    )
  );

CREATE POLICY "Team admins can manage announcements"
  ON public.team_announcements FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = team_announcements.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role = 'admin'
        AND team_members.is_deleted = false
    )
  );
