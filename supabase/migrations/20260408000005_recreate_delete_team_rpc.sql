-- delete_team RPC 재생성 (기존 마이그레이션이 기록상 적용됐으나 실제 함수 부재)
CREATE OR REPLACE FUNCTION public.delete_team(p_team_id UUID)
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

GRANT EXECUTE ON FUNCTION public.delete_team(UUID) TO authenticated;

-- PostgREST 스키마 캐시 리로드
NOTIFY pgrst, 'reload schema';
