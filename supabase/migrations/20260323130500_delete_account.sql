-- =============================================================================
-- Drop teams.created_by FK and simplify account deletion
-- - Keep teams even when creator account is deleted
-- - Block deletion only when user is sole admin of an active team
-- =============================================================================

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  -- Block deletion when current user is the sole admin of any active team.
  IF EXISTS (
    SELECT 1
    FROM public.team_members tm
    WHERE tm.user_id = v_user_id
      AND tm.role = 'admin'
      AND NOT tm.is_deleted
      AND EXISTS (
        SELECT 1
        FROM public.teams t
        WHERE t.id = tm.team_id
          AND NOT t.is_deleted
      )
      AND (
        SELECT COUNT(*)
        FROM public.team_members adm
        WHERE adm.team_id = tm.team_id
          AND adm.role = 'admin'
          AND NOT adm.is_deleted
      ) = 1
  ) THEN
    RAISE EXCEPTION '유일한 관리자 팀이 있어 계정을 삭제할 수 없습니다. 다른 관리자를 먼저 지정해주세요.';
  END IF;

  DELETE FROM auth.users
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION '삭제할 계정을 찾을 수 없습니다.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO service_role;
