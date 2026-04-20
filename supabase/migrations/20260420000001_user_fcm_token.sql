-- =============================================================================
-- Add FCM device token column to public.users
--
-- send-push Edge Function과 FcmTokenService(client)가 users.fcm_token을 읽고/쓴다.
-- 컬럼이 없어 푸시가 silent fail되던 이슈를 해결.
-- =============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 본인 토큰만 갱신 가능 (기존 "Users can update own profile" 정책으로 커버되지만
-- 명시적으로 사용자 본인이 fcm_token을 update할 수 있는지 회귀 방지 차원에서 확인용 주석).
-- (정책 추가는 불필요 — 기존 update 정책이 컬럼 단위가 아닌 row 단위로 허용함)

-- send-push Edge Function이 in-list로 다수 사용자 토큰을 한 번에 조회하므로 인덱스가
-- 의미는 적지만, 존재하는 토큰만 빠르게 추리도록 부분 인덱스를 둔다.
CREATE INDEX IF NOT EXISTS users_fcm_token_present_idx
  ON public.users (id)
  WHERE fcm_token IS NOT NULL;
