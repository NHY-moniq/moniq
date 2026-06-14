-- =============================================================================
-- Sign in with Apple — refresh token 보관 테이블
-- 계정 삭제 시 Apple 토큰을 revoke 하려면 refresh token이 필요하다.
-- (App Store Guideline 5.1.1 / "Offering Account Deletion" 요건)
--
-- 이 테이블은 service_role(Edge Function)에서만 접근한다.
-- RLS를 켜고 정책을 두지 않아 anon/authenticated 접근을 모두 차단한다.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.apple_oauth_tokens (
  user_id       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  apple_sub     TEXT,            -- Apple 사용자 고유 ID(server-to-server 알림 매핑용)
  refresh_token TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS apple_oauth_tokens_apple_sub_idx
  ON public.apple_oauth_tokens (apple_sub);

ALTER TABLE public.apple_oauth_tokens ENABLE ROW LEVEL SECURITY;

-- 정책 없음 → anon/authenticated 전면 차단, service_role만 RLS 우회 접근.
REVOKE ALL ON TABLE public.apple_oauth_tokens FROM anon, authenticated;
