-- Add preferred_shifts column to team_members
ALTER TABLE team_members
  ADD COLUMN IF NOT EXISTS preferred_shifts text[] DEFAULT '{}';
