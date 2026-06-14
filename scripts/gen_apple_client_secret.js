#!/usr/bin/env node
/**
 * Apple "Sign in with Apple" client secret(JWT) 생성기
 *
 * Supabase Apple Provider의 "Secret Key (for OAuth)" 칸에 넣을 ES256 JWT를 만든다.
 * (웹 Apple 로그인 전용. iOS 네이티브와 무관)
 *
 * ⚠️ Apple client secret은 최대 6개월 유효 → 만료 전 재발급 필요.
 *
 * 사용법:
 *   APPLE_TEAM_ID=DNZ4K5RRY6 \
 *   APPLE_KEY_ID=XXXXXXXXXX \
 *   APPLE_CLIENT_ID=com.maybeornot.onoroff.signin \   # ← 웹용 Services ID
 *   APPLE_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8 \
 *   node scripts/gen_apple_client_secret.js
 *
 *  - APPLE_TEAM_ID  : Apple Developer Team ID
 *  - APPLE_KEY_ID   : Sign in with Apple Key ID (.p8 파일의 키 ID)
 *  - APPLE_CLIENT_ID: 웹용 Services ID (App ID/번들 ID 아님!)
 *  - APPLE_KEY_PATH : 다운로드한 .p8 파일 경로
 */

const crypto = require('crypto');
const fs = require('fs');

const TEAM_ID = process.env.APPLE_TEAM_ID;
const KEY_ID = process.env.APPLE_KEY_ID;
const CLIENT_ID = process.env.APPLE_CLIENT_ID;
const KEY_PATH = process.env.APPLE_KEY_PATH;

if (!TEAM_ID || !KEY_ID || !CLIENT_ID || !KEY_PATH) {
  console.error(
    'Missing env. Required: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID, APPLE_KEY_PATH',
  );
  process.exit(1);
}

const b64url = (input) => Buffer.from(input).toString('base64url');

const now = Math.floor(Date.now() / 1000);
const SIX_MONTHS = 60 * 60 * 24 * 180; // 15,552,000s (Apple 최대 15,777,000s 이내)

const header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' };
const payload = {
  iss: TEAM_ID,
  iat: now,
  exp: now + SIX_MONTHS,
  aud: 'https://appleid.apple.com',
  sub: CLIENT_ID,
};

const signingInput = `${b64url(JSON.stringify(header))}.${b64url(
  JSON.stringify(payload),
)}`;

const privateKey = fs.readFileSync(KEY_PATH, 'utf8');

// ES256 → JOSE(P1363, raw R||S) 형식 서명
const signature = crypto.sign('SHA256', Buffer.from(signingInput), {
  key: privateKey,
  dsaEncoding: 'ieee-p1363',
});

const jwt = `${signingInput}.${b64url(signature)}`;

console.log(jwt);
console.error(
  `\n[ok] client secret 생성됨 (만료: ${new Date(
    (now + SIX_MONTHS) * 1000,
  ).toISOString().slice(0, 10)}). 위 JWT를 Supabase Apple Provider "Secret Key (for OAuth)"에 붙여넣으세요.`,
);
