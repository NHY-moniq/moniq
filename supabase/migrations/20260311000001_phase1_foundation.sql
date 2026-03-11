-- Phase 1: Foundation Schema
-- users, teams, team_members + RLS + RPCs + triggers

-- =============================================================================
-- Helper: update_updated_at trigger function
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Table: users
-- =============================================================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create public.users row when auth.users is created
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================================================
-- Table: teams
-- =============================================================================
CREATE TABLE public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  icon TEXT,
  description TEXT,
  team_type TEXT NOT NULL DEFAULT 'organizational',
  invite_code TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(6), 'hex'),
  created_by UUID NOT NULL REFERENCES public.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE TRIGGER teams_updated_at
  BEFORE UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_teams_invite_code ON public.teams(invite_code) WHERE NOT is_deleted;
CREATE INDEX idx_teams_created_by ON public.teams(created_by);

-- =============================================================================
-- Table: team_members
-- =============================================================================
CREATE TABLE public.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  skill_level TEXT,
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  UNIQUE(team_id, user_id)
);

CREATE TRIGGER team_members_updated_at
  BEFORE UPDATE ON public.team_members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_team_members_team_id ON public.team_members(team_id) WHERE NOT is_deleted;
CREATE INDEX idx_team_members_user_id ON public.team_members(user_id) WHERE NOT is_deleted;

-- =============================================================================
-- RPC: create_team
-- Creates a team and adds the creator as admin
-- =============================================================================
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
  VALUES (v_team_id, v_user_id, 'admin', true);

  RETURN json_build_object(
    'team_id', v_team_id,
    'invite_code', v_invite_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- RPC: join_team_by_invite
-- Validates invite code and adds user as member
-- =============================================================================
CREATE OR REPLACE FUNCTION join_team_by_invite(p_invite_code TEXT)
RETURNS JSON AS $$
DECLARE
  v_team_id UUID;
  v_team_name TEXT;
  v_user_id UUID;
  v_existing UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id, name INTO v_team_id, v_team_name
  FROM public.teams
  WHERE invite_code = p_invite_code
    AND NOT is_deleted;

  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  SELECT id INTO v_existing
  FROM public.team_members
  WHERE team_id = v_team_id
    AND user_id = v_user_id
    AND NOT is_deleted;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'Already a member of this team';
  END IF;

  INSERT INTO public.team_members (team_id, user_id, role)
  VALUES (v_team_id, v_user_id, 'member');

  RETURN json_build_object(
    'team_id', v_team_id,
    'team_name', v_team_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- RLS Policies
-- =============================================================================

-- Users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can view team members profiles"
  ON public.users FOR SELECT
  USING (
    id IN (
      SELECT tm.user_id FROM public.team_members tm
      WHERE tm.team_id IN (
        SELECT team_id FROM public.team_members
        WHERE user_id = auth.uid() AND NOT is_deleted
      )
      AND NOT tm.is_deleted
    )
  );

-- Teams
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Team members can view their teams"
  ON public.teams FOR SELECT
  USING (
    id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND NOT is_deleted
    )
  );

CREATE POLICY "Team admins can update their teams"
  ON public.teams FOR UPDATE
  USING (
    id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
        AND role = 'admin'
        AND NOT is_deleted
    )
  );

-- Anyone can view a team by invite code (for join flow)
CREATE POLICY "Anyone can view team by invite code"
  ON public.teams FOR SELECT
  USING (NOT is_deleted);

-- Team Members
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Team members can view members of their teams"
  ON public.team_members FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND NOT is_deleted
    )
  );

CREATE POLICY "Users can update own membership"
  ON public.team_members FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Team admins can manage members"
  ON public.team_members FOR ALL
  USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid()
        AND role = 'admin'
        AND NOT is_deleted
    )
  );
