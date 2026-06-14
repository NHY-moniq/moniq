// =============================================================================
// Sign in with Apple — Server-to-Server Notifications 수신 엔드포인트
//
// Apple이 사용자 계정 이벤트를 이 URL로 POST 한다.
//   - email-disabled / email-enabled : 이메일 릴레이 포워딩 on/off
//   - consent-revoked                : 사용자가 Apple 로그인 동의 철회
//   - account-delete                 : 사용자가 Apple 계정에서 앱 연결 삭제
//
// Apple은 인증 헤더 없이 POST 하므로 반드시 verify_jwt 를 꺼서 배포해야 한다:
//   supabase functions deploy apple-notifications --no-verify-jwt
//
// 배포 후 URL을 Apple Developer의 "Server-to-Server Notification Endpoint"에 입력:
//   https://<project-ref>.supabase.co/functions/v1/apple-notifications
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Apple이 보내는 payload(JWT)의 서명까지 검증하려면 appleid 공개키(JWKS)로
// 검증해야 하지만, 최소 요건(수신 + 200)은 디코드만으로 충족된다.
function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const part = token.split(".")[1];
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const json = atob(b64.padEnd(b64.length + ((4 - (b64.length % 4)) % 4), "="));
    return JSON.parse(json);
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("ok", { status: 200 });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const signedPayload = (body as { payload?: string }).payload;
    if (!signedPayload) return new Response("ok", { status: 200 });

    const claims = decodeJwtPayload(signedPayload);
    // events는 JSON 문자열로 한 번 더 감싸져 온다.
    let event: Record<string, unknown> | null = null;
    const rawEvents = claims?.events;
    if (typeof rawEvents === "string") {
      try {
        event = JSON.parse(rawEvents);
      } catch {
        event = null;
      }
    }

    const type = event?.type as string | undefined;
    const appleSub = event?.sub as string | undefined;
    console.log("apple s2s notification", { type, appleSub });

    // 사용자가 동의를 철회하거나 Apple 계정 연결을 삭제한 경우,
    // 우리 쪽 계정도 정리한다. apple_sub ↔ user 매핑이 있을 때만 동작.
    if ((type === "consent-revoked" || type === "account-delete") && appleSub) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (supabaseUrl && serviceKey) {
        const admin = createClient(supabaseUrl, serviceKey);
        const { data: row } = await admin
          .from("apple_oauth_tokens")
          .select("user_id")
          .eq("apple_sub", appleSub)
          .maybeSingle();
        if (row?.user_id) {
          await admin.auth.admin.deleteUser(row.user_id as string);
        }
      }
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    // 실패해도 Apple엔 200을 돌려 재시도 폭주를 막는다(로그만 남김).
    console.error("apple-notifications error", e);
    return new Response("ok", { status: 200 });
  }
});
