-- Wanted Entries Priority: 희망 휴무일 1/2/3순위 추가
-- priority: 1=최우선(반드시 휴무 희망), 2=차선, 3=가능하면
-- 기존 데이터와의 호환을 위해 nullable이며 기본값 1.

ALTER TABLE public.wanted_entries
  ADD COLUMN IF NOT EXISTS priority SMALLINT DEFAULT 1
  CHECK (priority IS NULL OR priority BETWEEN 1 AND 3);

CREATE INDEX IF NOT EXISTS idx_wanted_entries_priority
  ON public.wanted_entries(wanted_request_id, priority);
