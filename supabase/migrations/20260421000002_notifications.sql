-- =============================================================================
-- 알림 히스토리 테이블 — 각 사용자가 받은 푸시 알림 기록.
-- send-push Edge Function이 FCM 발송과 함께 이 테이블에 INSERT.
-- 종 아이콘 탭 시 본인 row들을 최신순으로 조회.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id)
  WHERE read_at IS NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 본인 알림만 조회 가능
DROP POLICY IF EXISTS "notifications_select_self" ON public.notifications;
CREATE POLICY "notifications_select_self"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());

-- 본인 알림만 업데이트 가능 (read_at 토글 등)
DROP POLICY IF EXISTS "notifications_update_self" ON public.notifications;
CREATE POLICY "notifications_update_self"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 본인 알림만 삭제 가능
DROP POLICY IF EXISTS "notifications_delete_self" ON public.notifications;
CREATE POLICY "notifications_delete_self"
  ON public.notifications FOR DELETE
  USING (user_id = auth.uid());

-- INSERT는 Edge Function이 service_role 키로 직접 하므로 RLS 정책 불필요
-- (authenticated가 임의로 남의 user_id에 INSERT 못하도록 정책 없음 = RLS 기본 deny)
