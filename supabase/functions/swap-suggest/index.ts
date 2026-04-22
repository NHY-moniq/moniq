// Swap Suggest — 본인 근무에 대해 1:N 교환 후보 추천 (OpenAI 기반)
//
// 요청 body:
// {
//   teamName: string,
//   periodLabel: string,
//   myUserId: string,
//   myDisplayName: string,
//   myShift: { date: 'YYYY-MM-DD', shiftCode: 'D'|'E'|'N'|... },
//   memberSchedules: { displayName: { 'YYYY-MM-DD': 'D'|'E'|'N'|'O' } },
//   members: { user_id: string, display_name: string }[],
//   hardRules: string[],
//   topK?: number   // 기본 5
// }
//
// 응답:
// {
//   candidates: [
//     { user_id: string, display_name: string, date: 'YYYY-MM-DD',
//       shift_code: string, reason: string }
//   ]
// }
//
// 필요 시크릿: OPENAI_API_KEY (이미 schedule-analyze에서 사용 중)

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface SwapSuggestRequest {
  teamName: string;
  periodLabel: string;
  myUserId: string;
  myDisplayName: string;
  myShift: { date: string; shiftCode: string };
  memberSchedules: Record<string, Record<string, string>>;
  members: { user_id: string; display_name: string }[];
  hardRules: string[];
  topK?: number;
}

interface Candidate {
  user_id: string;
  display_name: string;
  date: string;
  shift_code: string;
  reason: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body: SwapSuggestRequest = await req.json();

    const apiKey = Deno.env.get('OPENAI_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'OPENAI_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const topK = body.topK ?? 5;
    const nameToId: Record<string, string> = {};
    for (const m of body.members) nameToId[m.display_name] = m.user_id;

    const scheduleLines = Object.entries(body.memberSchedules)
      .map(([name, days]) => {
        const sorted = Object.entries(days)
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([date, code]) => `${date.slice(5)}=${code}`)
          .join(', ');
        return `${name}: ${sorted}`;
      })
      .join('\n');

    const hardRulesSummary = (body.hardRules ?? []).map((r) => `  - ${r}`).join('\n');

    const systemPrompt = `당신은 병원 3교대 근무 교환 추천 전문가입니다.
역할: 한 멤버의 특정 근무를 다른 멤버와 1:1로 교환할 때, 양쪽 모두 하드룰 위반이 발생하지 않는 안전한 후보를 추천합니다.

추천 원칙:
- 같은 날짜의 다른 멤버 (다른 shift_type을 가진 멤버 우선) — 오프(O) 멤버는 후보에서 제외
- 같은 날짜에 적합한 후보가 부족하면, 다른 날짜에 같은 shift_type을 가진 멤버 (Day↔Day는 의미 없으므로 제외)
- 교환 후 양쪽 멤버의 전후 3일 시퀀스가 모두 하드룰을 만족하는 경우만 추천
- 안전한 후보가 없으면 빈 배열 반환

응답은 반드시 JSON 형식이며, 다른 텍스트나 마크다운 없이 JSON만 출력합니다.`;

    const userPrompt = `## 팀: ${body.teamName} | 기간: ${body.periodLabel}

## 하드룰
${hardRulesSummary}

## 배정표 (D=데이, E=이브닝, N=나이트, O=오프)
${scheduleLines}

## 교환을 원하는 사람
- 이름: ${body.myDisplayName}
- 근무 날짜: ${body.myShift.date}
- 근무 유형: ${body.myShift.shiftCode}

## 작업
${body.myDisplayName} 님의 ${body.myShift.date} ${body.myShift.shiftCode} 근무와 교환할 후보를 최대 ${topK}명 추천하세요.
반드시 다음 JSON 형식으로만 응답:
{"candidates":[{"display_name":"...","date":"YYYY-MM-DD","shift_code":"D|E|N","reason":"교환이 안전한 이유 (양쪽 시퀀스 검증 결과)"}]}

추천 후보가 없으면 {"candidates":[]} 로 응답.`;

    const model = Deno.env.get('OPENAI_MODEL') ?? 'gpt-4o-mini';

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        max_tokens: 700,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
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
    const content: string = data.choices?.[0]?.message?.content ?? '{}';

    let parsed: { candidates?: Candidate[] } = {};
    try {
      parsed = JSON.parse(content);
    } catch (_) {
      parsed = { candidates: [] };
    }

    const enriched: Candidate[] = (parsed.candidates ?? [])
      .map((c) => ({
        ...c,
        user_id: nameToId[c.display_name] ?? '',
      }))
      .filter((c) => c.user_id !== '' && c.user_id !== body.myUserId);

    return new Response(JSON.stringify({ candidates: enriched }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
