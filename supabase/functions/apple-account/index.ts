// =============================================================================
// Sign in with Apple — refresh token 저장 / 폐기 Edge Function
//
//  action: "store"  → 로그인 직후 클라이언트가 보낸 authorizationCode 를
//                     Apple 과 교환하여 refresh_token 을 저장한다.
//  action: "revoke" → 계정 삭제 직전 저장된 refresh_token 으로 Apple 토큰을
//                     폐기한다. (App Store "Offering Account Deletion" 요건)
//
// 필요한 환경변수(Supabase Function Secrets):
//   APPLE_TEAM_ID      Apple Developer Team ID (예: DNZ4K5RRY6)
//   APPLE_KEY_ID       Sign in with Apple Key ID
//   APPLE_CLIENT_ID    네이티브 앱 Bundle ID (예: com.onoroff.onoroff)
//   APPLE_PRIVATE_KEY  .p8 파일 내용 (BEGIN/END PRIVATE KEY 포함)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY (플랫폼 기본 제공)
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// --- ES256 client_secret(JWT) 생성 ------------------------------------------
function base64url(input: Uint8Array | string): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : input;
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function makeClientSecret(): Promise<string> {
  const teamId = Deno.env.get("APPLE_TEAM_ID")!;
  const keyId = Deno.env.get("APPLE_KEY_ID")!;
  const clientId = Deno.env.get("APPLE_CLIENT_ID")!;
  const privateKeyPem = Deno.env.get("APPLE_PRIVATE_KEY")!;

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId };
  const payload = {
    iss: teamId,
    iat: now,
    exp: now + 60 * 5, // 5분
    aud: "https://appleid.apple.com",
    sub: clientId,
  };

  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(
    JSON.stringify(payload),
  )}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(unsigned),
    ),
  );

  return `${unsigned}.${base64url(sig)}`;
}

// --- handler -----------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "missing bearer token" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 호출자 신원 확인 (사용자 JWT)
    const userClient = createClient(supabaseUrl, serviceKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return json({ error: "unauthorized" }, 401);
    }
    const userId = userData.user.id;

    // service-role 클라이언트 (RLS 우회, 토큰 테이블 접근)
    const admin = createClient(supabaseUrl, serviceKey);

    const { action, authorizationCode, appleSub } = await req
      .json()
      .catch(() => ({}));
    const clientId = Deno.env.get("APPLE_CLIENT_ID")!;

    if (action === "store") {
      if (!authorizationCode) return json({ error: "missing authorizationCode" }, 400);

      const clientSecret = await makeClientSecret();
      const res = await fetch(APPLE_TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          grant_type: "authorization_code",
          code: authorizationCode,
        }),
      });
      const body = await res.json();
      if (!res.ok || !body.refresh_token) {
        return json({ error: "apple token exchange failed", detail: body }, 502);
      }

      await admin.from("apple_oauth_tokens").upsert({
        user_id: userId,
        apple_sub: appleSub ?? null,
        refresh_token: body.refresh_token,
        updated_at: new Date().toISOString(),
      });
      return json({ ok: true });
    }

    if (action === "revoke") {
      const { data: row } = await admin
        .from("apple_oauth_tokens")
        .select("refresh_token")
        .eq("user_id", userId)
        .maybeSingle();

      // Apple 로그인 사용자가 아니면 그냥 통과 (no-op).
      if (!row?.refresh_token) return json({ ok: true, skipped: true });

      const clientSecret = await makeClientSecret();
      const res = await fetch(APPLE_REVOKE_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          token: row.refresh_token,
          token_type_hint: "refresh_token",
        }),
      });
      if (!res.ok) {
        const detail = await res.text();
        return json({ error: "apple revoke failed", detail }, 502);
      }

      await admin.from("apple_oauth_tokens").delete().eq("user_id", userId);
      return json({ ok: true });
    }

    return json({ error: "unknown action" }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
