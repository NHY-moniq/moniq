// Send Push Notification via Firebase Cloud Messaging (HTTP v1 API)
//
// Required Supabase secrets:
//   FCM_PROJECT_ID         — Firebase project id (e.g., "moniq-12345")
//   FCM_SERVICE_ACCOUNT_JSON — Base64-encoded service account JSON, OR raw JSON string
//
// Request body:
//   {
//     teamId?: string,        // 팀 멤버 전체에게 발송
//     userIds?: string[],     // 특정 사용자들에게 발송
//     excludeUserId?: string, // 발신자 본인 제외 (선택)
//     title: string,
//     body: string,
//     data?: Record<string,string>
//   }
//
// 응답: { sent: number, failed: number, errors?: string[] }

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface SendPushRequest {
  teamId?: string;
  userIds?: string[];
  excludeUserId?: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

// ─── Google OAuth: service account → access token ────────────────────────────
async function getAccessToken(): Promise<string> {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('FCM_SERVICE_ACCOUNT_JSON not configured');

  // Allow base64-encoded or raw JSON
  let jsonText = raw;
  if (!raw.trim().startsWith('{')) {
    jsonText = new TextDecoder().decode(
      Uint8Array.from(atob(raw), (c) => c.charCodeAt(0)),
    );
  }
  const sa = JSON.parse(jsonText);

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');

  const headerB64 = enc(header);
  const claimB64 = enc(claim);
  const signingInput = `${headerB64}.${claimB64}`;

  // Import the private key
  const pkPem = sa.private_key as string;
  const pkDer = pemToDer(pkPem);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pkDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
  const jwt = `${signingInput}.${sigB64}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`OAuth token failed: ${await tokenRes.text()}`);
  }
  const tokenJson = await tokenRes.json();
  return tokenJson.access_token as string;
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// ─── Main handler ────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const projectId = Deno.env.get('FCM_PROJECT_ID');
    if (!projectId) throw new Error('FCM_PROJECT_ID not configured');

    const { teamId, userIds, excludeUserId, title, body, data } =
      (await req.json()) as SendPushRequest;

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: 'title and body required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ─── 대상 사용자 토큰 조회 ───
    let targetUserIds: string[] = [];
    if (userIds && userIds.length > 0) {
      targetUserIds = userIds;
    } else if (teamId) {
      const { data: members, error } = await supabase
        .from('team_members')
        .select('user_id')
        .eq('team_id', teamId)
        .eq('is_deleted', false);
      if (error) throw error;
      targetUserIds = (members ?? []).map((m) => m.user_id as string);
    } else {
      throw new Error('teamId or userIds required');
    }

    if (excludeUserId) {
      targetUserIds = targetUserIds.filter((id) => id !== excludeUserId);
    }
    if (targetUserIds.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, failed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { data: users, error: userErr } = await supabase
      .from('users')
      .select('id, fcm_token')
      .in('id', targetUserIds);
    if (userErr) throw userErr;

    const tokens = (users ?? [])
      .map((u) => u.fcm_token as string | null)
      .filter((t): t is string => !!t && t.length > 0);

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, failed: 0, note: 'no fcm tokens' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ─── FCM HTTP v1 발송 ───
    const accessToken = await getAccessToken();
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    let sent = 0;
    let failed = 0;
    const errors: string[] = [];

    for (const token of tokens) {
      const message = {
        message: {
          token,
          notification: { title, body },
          data: data ?? {},
        },
      };
      const res = await fetch(fcmEndpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      });
      if (res.ok) {
        sent++;
      } else {
        failed++;
        errors.push(`${res.status}: ${await res.text()}`);
      }
    }

    return new Response(
      JSON.stringify({ sent, failed, errors: errors.length ? errors : undefined }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
