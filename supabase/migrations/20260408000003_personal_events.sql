-- Personal Events: 사용자 개인 일정 (캘린더)
-- 본인만 CRUD 가능. 사용자별 격리.

CREATE TABLE IF NOT EXISTS public.personal_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_date DATE NOT NULL,
  title TEXT NOT NULL,
  start_time TEXT,           -- "HH:mm" — null이면 종일
  end_time TEXT,             -- "HH:mm"
  description TEXT,
  color TEXT,                -- hex
  recurrence TEXT,           -- none, daily, weekly, biweekly, monthly, yearly
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personal_events_user_date
  ON public.personal_events(user_id, event_date);

ALTER TABLE public.personal_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own personal events"
  ON public.personal_events FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own personal events"
  ON public.personal_events FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own personal events"
  ON public.personal_events FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own personal events"
  ON public.personal_events FOR DELETE
  USING (user_id = auth.uid());
