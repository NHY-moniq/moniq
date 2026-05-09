-- join_team_by_invite: also return team_type so the client can trigger the right tutorial flow.

CREATE OR REPLACE FUNCTION join_team_by_invite(p_invite_code TEXT)
RETURNS JSON AS $$
DECLARE
  v_team_id     UUID;
  v_team_name   TEXT;
  v_team_type   TEXT;
  v_user_id     UUID;
  v_existing_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id, name, team_type INTO v_team_id, v_team_name, v_team_type
  FROM public.teams
  WHERE invite_code = p_invite_code AND NOT is_deleted;

  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  -- 활성 멤버십 확인 (이미 가입된 경우)
  SELECT id INTO v_existing_id
  FROM public.team_members
  WHERE team_id = v_team_id
    AND user_id = v_user_id
    AND is_deleted = false
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RAISE EXCEPTION 'Already a member of this team';
  END IF;

  -- soft-deleted 레코드 확인 (재가입 케이스)
  SELECT id INTO v_existing_id
  FROM public.team_members
  WHERE team_id = v_team_id
    AND user_id = v_user_id
    AND is_deleted = true
  ORDER BY updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- 중복 soft-deleted 레코드 정리 후 가장 최신 것 복구
    DELETE FROM public.team_members
    WHERE team_id = v_team_id
      AND user_id = v_user_id
      AND is_deleted = true
      AND id != v_existing_id;

    UPDATE public.team_members
    SET is_deleted = false, role = 'member', is_favorite = false
    WHERE id = v_existing_id;
  ELSE
    INSERT INTO public.team_members (team_id, user_id, role)
    VALUES (v_team_id, v_user_id, 'member');
  END IF;

  RETURN json_build_object(
    'team_id',    v_team_id,
    'team_name',  v_team_name,
    'team_type',  v_team_type
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
