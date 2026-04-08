-- custom_rules table
CREATE TABLE IF NOT EXISTS custom_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  rule_type TEXT NOT NULL,
  -- DSL types: 'member_shift_ban', 'anti_pair', 'require_pair',
  --            'date_off', 'post_night_off', 'skill_condition', 'freeform'
  rule_value JSONB NOT NULL DEFAULT '{}',
  original_text TEXT NOT NULL,
  parsed_dsl JSONB,               -- null → freeform
  priority TEXT NOT NULL DEFAULT 'soft' CHECK (priority IN ('hard', 'soft')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS
ALTER TABLE custom_rules ENABLE ROW LEVEL SECURITY;

-- 같은 팀 멤버만 조회 가능
CREATE POLICY "team members can view custom_rules"
  ON custom_rules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = custom_rules.team_id
        AND tm.user_id = auth.uid()
        AND tm.is_deleted = false
    )
  );

-- 팀 관리자만 추가/수정/삭제 가능
CREATE POLICY "team admins can insert custom_rules"
  ON custom_rules FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = custom_rules.team_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'admin'
        AND tm.is_deleted = false
    )
  );

CREATE POLICY "team admins can update custom_rules"
  ON custom_rules FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = custom_rules.team_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'admin'
        AND tm.is_deleted = false
    )
  );

CREATE POLICY "team admins can delete custom_rules"
  ON custom_rules FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = custom_rules.team_id
        AND tm.user_id = auth.uid()
        AND tm.role = 'admin'
        AND tm.is_deleted = false
    )
  );
