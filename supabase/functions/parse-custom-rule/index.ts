import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// 무료 버전: 팀당 누적 "생성 시도" 한도. 앱 우회(함수 직접 호출)도 막는 서버측 가드.
const MAX_ATTEMPTS_PER_TEAM = 20;

interface ParseRequest {
  text: string;          // 유저가 입력한 자연어 원문 (최대 200자)
  teamId: string;        // 비용 가드용 — 팀 누적 호출수 기준
  teamMembers: { id: string; name: string }[];
  shiftTypes: { id: string; name: string; code: string }[];
}

interface ParsedDsl {
  rule_type: string;
  // member_shift_ban: { member_id, shift_code }
  // anti_pair:        { member_id_a, member_id_b, shift_code? }
  // require_pair:     { member_id_a (junior), member_id_b (senior), shift_code? }
  // date_off:         { member_id, dates: string[] }
  // post_night_off:   { consecutive_nights: number, min_off_days: number }
  // skill_condition:  { shift_code, min_skill: number, min_count: number }
  // freeform:         { description }
  [key: string]: unknown;
}

interface ParseResponse {
  rule_type: string;
  rule_value: Record<string, unknown>;
  parsed_dsl: ParsedDsl | null;  // null = freeform
  priority: 'hard' | 'soft';
  display_summary: string;       // 사람이 읽을 수 있는 요약
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body: ParseRequest = await req.json();

    // ── 비용 가드 (서버측, OpenAI 호출 전) ──
    // 팀별 누적 호출수를 원자적으로 올리고 한도 초과면 거부한다.
    // 앱 클라이언트를 우회해 함수를 직접 호출해도 여기서 막힌다.
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (supabaseUrl && serviceRoleKey && anonKey) {
      // 1) 호출자가 정말 그 팀의 멤버인지 검증한다.
      //    (검증 없이 body.teamId를 믿으면, 임의의 teamId로 매번 새 20회 quota를
      //     얻어 한도를 무력화할 수 있다.)
      const authHeader = req.headers.get('Authorization') ?? '';
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData } = await userClient.auth.getUser();
      const callerId = userData?.user?.id;

      const admin = createClient(supabaseUrl, serviceRoleKey);
      let isMember = false;
      if (callerId && body.teamId) {
        const { data: membership } = await admin
          .from('team_members')
          .select('user_id')
          .eq('team_id', body.teamId)
          .eq('user_id', callerId)
          .eq('is_deleted', false)
          .maybeSingle();
        isMember = membership != null;
      }
      if (!isMember) {
        return new Response(
          JSON.stringify({ error: 'not_authorized' }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      // 2) 누적 카운터 원자적 증가 + 한도 검사
      const { data: attemptCount, error: bumpError } = await admin.rpc(
        'bump_custom_rule_attempts_unchecked',
        { p_team_id: body.teamId },
      );
      if (!bumpError && typeof attemptCount === 'number' &&
          attemptCount > MAX_ATTEMPTS_PER_TEAM) {
        // 클라이언트가 data.error로 읽도록 200으로 반환 (supabase invoke는 non-2xx에서 throw)
        return new Response(
          JSON.stringify({ error: 'limit_reached' }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
    }

    const apiKey = Deno.env.get('OPENAI_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'OPENAI_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const memberList = body.teamMembers
      .map((m) => `${m.name}(id:${m.id})`)
      .join(', ');

    const shiftList = body.shiftTypes
      .map((s) => `${s.name}(code:${s.code},id:${s.id})`)
      .join(', ');

    const systemPrompt = `당신은 간호사 근무표 커스텀 규칙 파서입니다.
유저의 자연어 입력을 분석하여 구조화된 DSL JSON으로 변환하세요.

## 팀원 목록
${memberList}

## 근무 유형 목록
${shiftList}

## DSL 규칙 유형

1. **member_shift_ban** — 특정 멤버 특정 근무 금지
   rule_value: { "member_id": "<id>", "shift_code": "<code 또는 null(전체 근무 금지)>" }
   예: "홍길동은 나이트 안 서요" → member_shift_ban, shift_code: "N"
   예: "김나연은 절대 근무 서지 않아" → member_shift_ban, shift_code: null (모든 근무 금지)

2. **anti_pair** — 두 멤버 같은 근무 동시 배정 금지
   rule_value: { "member_id_a": "<id>", "member_id_b": "<id>", "shift_code": "<code 또는 null(전체)>" }
   예: "A와 B는 같은 나이트를 서지 않게" → anti_pair

3. **require_pair** — 두 멤버를 같은 근무에 함께 배정
   rule_value: { "member_id_a": "<id>", "member_id_b": "<id>", "shift_code": "<code 또는 null(전체)>" }
   예: "신입 A는 선배 B와 항상 같은 데이" → require_pair

4. **date_off** — 특정 날짜 오프 강제
   rule_value: { "member_id": "<id>", "dates": ["YYYY-MM-DD", ...] }
   날짜를 특정할 수 없으면 freeform으로 처리.

5. **post_night_off** — 나이트 연속 후 최소 오프
   rule_value: { "consecutive_nights": <int>, "min_off_days": <int> }
   예: "나이트 3연속이면 2일 쉬어야" → post_night_off

6. **skill_condition** — 특정 근무에 최소 숙련도 멤버 조건
   rule_value: { "shift_code": "<code>", "min_skill": <int>, "min_count": <int> }
   숙련도 표현 매핑: 신규/신입/주니어 → min_skill: 1, 중간/중급 → min_skill: 2, 올드/시니어/선배/고숙련 → min_skill: 3
   예: "데이에 올드 1명 필수" → skill_condition, shift_code: "D", min_skill: 3, min_count: 1
   예: "나이트에 신규만 서면 안 돼요" → 이건 skill_balance로 처리

7. **skill_balance** — 신규(junior)가 있는 근무에 올드(senior)가 반드시 함께
   rule_value: { "shift_code": "<code 또는 null(전체 근무)>" }
   예: "신규가 있으면 올드 한 명은 꼭 있어야 해요" → skill_balance, shift_code: null
   예: "신규끼리만 같은 근무 서지 않게 해주세요" → skill_balance, shift_code: null
   예: "데이 근무에 신규만 있으면 안 돼요" → skill_balance, shift_code: "D"
   예: "신입이 있는 나이트엔 선배도 꼭 있어야 해요" → skill_balance, shift_code: "N"

8. **freeform** — 위에 해당 안 하는 복잡한 규칙
   rule_value: { "description": "<원문 그대로>" }

## 응답 형식 (JSON만, 다른 텍스트 없음)
{
  "rule_type": "<유형>",
  "rule_value": { ... },
  "parsed_dsl": { ... } or null (freeform이면 null),
  "priority": "hard" or "soft",
  "display_summary": "<한국어 1문장 요약>"
}

## 하드/소프트 기본값
- member_shift_ban: hard
- anti_pair: soft
- require_pair: soft
- date_off: hard
- post_night_off: hard
- skill_condition: hard
- skill_balance: soft
- freeform: soft (항상)

멤버 이름이 일치하지 않거나 모호한 경우 freeform으로 처리하세요.
날짜 정보가 필요한데 없는 경우도 freeform으로 처리하세요.`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 512,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: body.text },
        ],
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      return new Response(
        JSON.stringify({ error: `OpenAI API error: ${err}` }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content ?? '{}';

    let parsed: ParseResponse;
    try {
      parsed = JSON.parse(content);
    } catch {
      // JSON 파싱 실패 시 freeform으로 폴백
      parsed = {
        rule_type: 'freeform',
        rule_value: { description: body.text },
        parsed_dsl: null,
        priority: 'soft',
        display_summary: body.text,
      };
    }

    // freeform은 항상 soft
    if (parsed.rule_type === 'freeform') {
      parsed.priority = 'soft';
      parsed.parsed_dsl = null;
    }

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
