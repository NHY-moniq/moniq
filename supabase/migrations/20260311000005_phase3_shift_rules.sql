-- =============================================================================
-- Phase 3: Team Management — shift_rules table
-- =============================================================================

CREATE TABLE public.shift_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  rule_type TEXT NOT NULL CHECK (rule_type IN (
    'min_staffing',
    'max_staffing',
    'max_consecutive_work_days',
    'max_monthly_shifts',
    'max_monthly_night_shifts',
    'min_rest_after_night'
  )),
  rule_value JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(team_id, rule_type)
);

CREATE TRIGGER shift_rules_updated_at
  BEFORE UPDATE ON public.shift_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_shift_rules_team_id ON public.shift_rules(team_id) WHERE is_active;

-- RLS
ALTER TABLE public.shift_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shift_rules_select_team_member"
  ON public.shift_rules FOR SELECT
  USING (team_id IN (SELECT get_my_team_ids()));

CREATE POLICY "shift_rules_all_team_admin"
  ON public.shift_rules FOR ALL
  USING (team_id IN (SELECT get_my_admin_team_ids()));
