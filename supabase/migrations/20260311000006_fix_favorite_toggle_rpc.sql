-- =============================================================================
-- Fix: Favorite toggle via SECURITY DEFINER RPCs
--
-- Problem: team_members UPDATE blocked by RLS (only admin ALL policy exists)
-- Solution: SECURITY DEFINER RPCs that bypass RLS for favorite toggle
-- =============================================================================

-- RPC: 즐겨찾기 팀 설정 (기존 즐겨찾기 해제 후 새로 설정)
CREATE OR REPLACE FUNCTION set_favorite_team(p_team_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 기존 즐겨찾기 모두 해제
  UPDATE team_members
  SET is_favorite = false
  WHERE user_id = auth.uid() AND is_favorite = true AND NOT is_deleted;

  -- 새 즐겨찾기 설정
  UPDATE team_members
  SET is_favorite = true
  WHERE team_id = p_team_id AND user_id = auth.uid() AND NOT is_deleted;
END;
$$;

-- RPC: 즐겨찾기 해제
CREATE OR REPLACE FUNCTION clear_favorite_team()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE team_members
  SET is_favorite = false
  WHERE user_id = auth.uid() AND is_favorite = true AND NOT is_deleted;
END;
$$;
