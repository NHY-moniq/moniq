-- Add 'education' as a valid change_type for requests

ALTER TABLE public.requests
  DROP CONSTRAINT IF EXISTS requests_change_type_check;

ALTER TABLE public.requests
  ADD CONSTRAINT requests_change_type_check
  CHECK (change_type IN ('day_off', 'shift_change', 'swap', 'schedule_change', 'education'));
