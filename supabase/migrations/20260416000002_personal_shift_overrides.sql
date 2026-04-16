-- 개인 캘린더 표시용 근무 오버라이드
-- 팀 shift 레코드는 그대로 두고, 사용자가 개인 뷰에서 보이는 근무만 변경

CREATE TABLE IF NOT EXISTS public.personal_shift_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE CASCADE,
  shift_type_id UUID NOT NULL REFERENCES public.shift_types(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  start_time TEXT,
  end_time TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, shift_id)
);

CREATE INDEX IF NOT EXISTS idx_personal_shift_overrides_user
  ON public.personal_shift_overrides(user_id);

ALTER TABLE public.personal_shift_overrides ENABLE ROW LEVEL SECURITY;

-- 본인 것만 조회/관리
CREATE POLICY "User can view own shift overrides"
  ON public.personal_shift_overrides FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "User can insert own shift overrides"
  ON public.personal_shift_overrides FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "User can update own shift overrides"
  ON public.personal_shift_overrides FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "User can delete own shift overrides"
  ON public.personal_shift_overrides FOR DELETE
  USING (user_id = auth.uid());
