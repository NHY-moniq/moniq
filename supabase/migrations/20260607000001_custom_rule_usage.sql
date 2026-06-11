-- 팀별 커스텀 룰 AI 파싱 "생성 시도" 누적 카운터.
-- 무료 버전 비용 보호용: 삭제→추가 churn으로도 줄지 않는 누적값이라
-- 팀당 최대 호출 횟수를 확실히 제한한다.
CREATE TABLE IF NOT EXISTS custom_rule_usage (
  team_id UUID PRIMARY KEY REFERENCES teams(id) ON DELETE CASCADE,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE custom_rule_usage ENABLE ROW LEVEL SECURITY;

-- 같은 팀 멤버는 카운터를 조회 가능 (UI 표시용)
CREATE POLICY "team members can view custom_rule_usage"
  ON custom_rule_usage FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = custom_rule_usage.team_id
        AND tm.user_id = auth.uid()
        AND tm.is_deleted = false
    )
  );

-- 서버(Edge Function, service_role)에서 호출하는 원자적 증가 함수.
-- parse-custom-rule 함수가 OpenAI 호출 전에 팀별 누적 호출수를 올리고 한도를
-- 검사하는 데 쓴다. (service_role 전용 — 일반 사용자는 호출 불가)
CREATE OR REPLACE FUNCTION bump_custom_rule_attempts_unchecked(p_team_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  INSERT INTO custom_rule_usage (team_id, attempt_count, updated_at)
  VALUES (p_team_id, 1, NOW())
  ON CONFLICT (team_id)
  DO UPDATE SET attempt_count = custom_rule_usage.attempt_count + 1,
                updated_at = NOW()
  RETURNING attempt_count INTO v_count;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION bump_custom_rule_attempts_unchecked(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION bump_custom_rule_attempts_unchecked(UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION bump_custom_rule_attempts_unchecked(UUID) TO service_role;
