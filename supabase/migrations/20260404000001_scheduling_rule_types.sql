-- Add new scheduling rule types to shift_rules check constraint
ALTER TABLE public.shift_rules DROP CONSTRAINT IF EXISTS shift_rules_rule_type_check;

ALTER TABLE public.shift_rules ADD CONSTRAINT shift_rules_rule_type_check
  CHECK (rule_type IN (
    -- 팀 고정 규칙
    'min_staffing',
    'max_staffing',
    'max_consecutive_work_days',
    'max_monthly_shifts',
    'max_monthly_night_shifts',
    'min_rest_after_night',
    'max_consecutive_night_shifts',
    'min_weekly_off_days',
    'no_night_then_day',
    'no_night_then_evening',
    'no_evening_then_day',
    -- 스케줄 생성 유동 규칙
    'nod_disabled',
    'avoid_nood',
    'avoid_noe',
    'avoid_eod',
    'wanted_priority_order',
    'consider_skill_level'
  ));
