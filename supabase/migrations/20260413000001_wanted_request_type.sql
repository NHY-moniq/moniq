-- 원티드 요청에 타입 필드 추가
-- day_off: 희망 휴무, preferred_shift: 수행하고 싶은 근무,
-- night_dedicated: 나이트 전담, education: 교육

ALTER TABLE public.wanted_requests
  ADD COLUMN IF NOT EXISTS wanted_type TEXT NOT NULL DEFAULT 'day_off'
  CHECK (wanted_type IN ('day_off', 'preferred_shift', 'night_dedicated', 'education'));

-- 원티드 엔트리에 선택한 근무 유형 ID 필드 추가 (preferred_shift 타입용)
ALTER TABLE public.wanted_entries
  ADD COLUMN IF NOT EXISTS shift_type_id UUID REFERENCES public.shift_types(id);

CREATE INDEX IF NOT EXISTS idx_wanted_requests_type
  ON public.wanted_requests(team_id, wanted_type, status);
