-- =============================================================================
-- Fix: RLS infinite recursion on team_members
--
-- Problem: team_members RLS policy queries team_members → infinite recursion
-- Solution: SECURITY DEFINER helper functions that bypass RLS
-- =============================================================================

-- Helper: 현재 유저의 팀 ID 목록 (RLS 우회)
CREATE OR REPLACE FUNCTION get_my_team_ids()
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT team_id FROM team_members
  WHERE user_id = auth.uid() AND NOT is_deleted;
$$;

-- Helper: 현재 유저가 admin인 팀 ID 목록 (RLS 우회)
CREATE OR REPLACE FUNCTION get_my_admin_team_ids()
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT team_id FROM team_members
  WHERE user_id = auth.uid() AND role = 'admin' AND NOT is_deleted;
$$;

-- =============================================================================
-- Recreate: team_members policies
-- =============================================================================
DROP POLICY IF EXISTS "Team members can view members of their teams" ON public.team_members;
DROP POLICY IF EXISTS "Team admins can manage members" ON public.team_members;

CREATE POLICY "Team members can view members of their teams"
  ON public.team_members FOR SELECT
  USING (team_id IN (SELECT get_my_team_ids()));

CREATE POLICY "Team admins can manage members"
  ON public.team_members FOR ALL
  USING (team_id IN (SELECT get_my_admin_team_ids()));

-- =============================================================================
-- Recreate: teams policies
-- =============================================================================
DROP POLICY IF EXISTS "Team members can view their teams" ON public.teams;
DROP POLICY IF EXISTS "Team admins can update their teams" ON public.teams;

CREATE POLICY "Team members can view their teams"
  ON public.teams FOR SELECT
  USING (id IN (SELECT get_my_team_ids()));

CREATE POLICY "Team admins can update their teams"
  ON public.teams FOR UPDATE
  USING (id IN (SELECT get_my_admin_team_ids()));

-- =============================================================================
-- Recreate: users policy (team member profiles)
-- =============================================================================
DROP POLICY IF EXISTS "Users can view team members profiles" ON public.users;

CREATE POLICY "Users can view team members profiles"
  ON public.users FOR SELECT
  USING (
    id IN (
      SELECT tm.user_id FROM team_members tm
      WHERE tm.team_id IN (SELECT get_my_team_ids())
        AND NOT tm.is_deleted
    )
  );

-- =============================================================================
-- Recreate: shift_types policies
-- =============================================================================
DROP POLICY IF EXISTS "shift_types_select_team_member" ON public.shift_types;
DROP POLICY IF EXISTS "shift_types_all_team_admin" ON public.shift_types;

CREATE POLICY "shift_types_select_team_member"
  ON public.shift_types FOR SELECT
  USING (team_id IN (SELECT get_my_team_ids()));

CREATE POLICY "shift_types_all_team_admin"
  ON public.shift_types FOR ALL
  USING (team_id IN (SELECT get_my_admin_team_ids()));

-- =============================================================================
-- Recreate: schedules policies
-- =============================================================================
DROP POLICY IF EXISTS "schedules_select_team_member" ON public.schedules;
DROP POLICY IF EXISTS "schedules_all_team_admin" ON public.schedules;

CREATE POLICY "schedules_select_team_member"
  ON public.schedules FOR SELECT
  USING (team_id IN (SELECT get_my_team_ids()));

CREATE POLICY "schedules_all_team_admin"
  ON public.schedules FOR ALL
  USING (team_id IN (SELECT get_my_admin_team_ids()));

-- =============================================================================
-- Recreate: shifts policies
-- =============================================================================
DROP POLICY IF EXISTS "shifts_select_team_member" ON public.shifts;
DROP POLICY IF EXISTS "shifts_all_team_admin" ON public.shifts;

CREATE POLICY "shifts_select_team_member"
  ON public.shifts FOR SELECT
  USING (team_id IN (SELECT get_my_team_ids()));

CREATE POLICY "shifts_all_team_admin"
  ON public.shifts FOR ALL
  USING (team_id IN (SELECT get_my_admin_team_ids()));
