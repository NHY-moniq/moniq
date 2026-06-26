-- 나이트 전담 전용 규칙을 shift_rules.rule_type 허용목록에 추가한다.
-- max_night_dedicated_shifts(월 최대 야간)는 솔버에서 이미 읽고 있었으나
-- CHECK 제약에 없어 저장이 불가능했다(항상 기본 14 적용). 함께 추가한다.
ALTER TABLE public.shift_rules DROP CONSTRAINT IF EXISTS shift_rules_rule_type_check;

ALTER TABLE public.shift_rules ADD CONSTRAINT shift_rules_rule_type_check
  CHECK (rule_type IN (
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
    'nod_disabled',
    'avoid_nood',
    'avoid_noe',
    'avoid_eod',
    'wanted_priority_order',
    'scheduling_priority_order',
    'consider_skill_level',
    'wanted_p1_limit',
    'wanted_p2_limit',
    'max_night_dedicated_shifts',
    'night_dedicated_max_consecutive',
    'night_dedicated_min_off_after',
    'night_dedicated_weekly_max'
  ));
