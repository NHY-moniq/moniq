-- Ensure new teams always start with required default shift types (D/E/N/ED)
CREATE OR REPLACE FUNCTION create_team(
  p_name TEXT,
  p_icon TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_team_type TEXT DEFAULT 'organizational'
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

  INSERT INTO public.teams (name, icon, description, team_type, created_by)
  VALUES (p_name, p_icon, p_description, p_team_type, v_user_id)
  RETURNING id, invite_code INTO v_team_id, v_invite_code;

  INSERT INTO public.team_members (team_id, user_id, role, is_favorite)
  VALUES (v_team_id, v_user_id, 'admin', false);

  -- Required defaults: Day / Evening / Night / Education
  INSERT INTO public.shift_types (
    team_id,
    name,
    code,
    start_time,
    end_time,
    color,
    display_order
  )
  VALUES
    (v_team_id, '데이', 'D',  '07:00'::TIME, '15:00'::TIME, '#F0C040', 0),
    (v_team_id, '이브닝', 'E', '15:00'::TIME, '22:00'::TIME, '#E8923A', 1),
    (v_team_id, '나이트', 'N', '22:00'::TIME, '07:00'::TIME, '#5A8BB5', 2),
    (v_team_id, '교육', 'ED', '09:00'::TIME, '18:00'::TIME, '#9F7AEA', 3);

  RETURN json_build_object(
    'team_id', v_team_id,
    'invite_code', v_invite_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
