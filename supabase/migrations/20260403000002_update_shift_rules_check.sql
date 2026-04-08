-- Update shift_rules rule_type check constraint to include new rule types
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
    'no_evening_then_day'
  ));
