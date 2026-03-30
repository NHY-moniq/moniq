-- 팀 삭제 RPC: admin 권한을 DB 레벨에서 검증
CREATE OR REPLACE FUNCTION delete_team(p_team_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id
      AND user_id = v_user_id
      AND role = 'admin'
      AND NOT is_deleted
  ) THEN
    RAISE EXCEPTION 'Permission denied: admin only';
  END IF;

  UPDATE public.teams
  SET is_deleted = true
  WHERE id = p_team_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
