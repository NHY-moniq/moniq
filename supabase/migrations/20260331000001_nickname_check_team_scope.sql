-- Change nickname duplicate check to team-scoped
-- Only checks for duplicates among members of the same team(s)

CREATE OR REPLACE FUNCTION check_nickname_duplicate(p_nickname TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.users u
    WHERE u.display_name = p_nickname
      AND u.id != auth.uid()
      AND NOT u.is_deleted
      AND u.id IN (
        SELECT tm2.user_id
        FROM public.team_members tm1
        JOIN public.team_members tm2 ON tm1.team_id = tm2.team_id
        WHERE tm1.user_id = auth.uid()
          AND NOT tm1.is_deleted
          AND NOT tm2.is_deleted
      )
  ) INTO v_exists;
  RETURN v_exists;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
