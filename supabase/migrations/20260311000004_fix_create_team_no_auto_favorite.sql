-- Fix: create_team should NOT auto-favorite the new team
CREATE OR REPLACE FUNCTION create_team(
  p_name TEXT,
  p_icon TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_team_id UUID;
  v_invite_code TEXT;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.teams (name, icon, description, created_by)
  VALUES (p_name, p_icon, p_description, v_user_id)
  RETURNING id, invite_code INTO v_team_id, v_invite_code;

  INSERT INTO public.team_members (team_id, user_id, role, is_favorite)
  VALUES (v_team_id, v_user_id, 'admin', false);

  RETURN json_build_object(
    'team_id', v_team_id,
    'invite_code', v_invite_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
