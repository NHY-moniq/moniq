import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface AnalyzeRequest {
  teamName: string;
  periodLabel: string;
  hardViolations: string[];
  understaffedCount: number;
  wantedTotal: number;
  wantedSatisfied: number;
  softViolations: Record<string, number>;
  customRuleViolations: string[];
  members: { name: string; attributes: string[] }[];
  activeRules: string[];
  memberSchedules: Record<string, Record<string, string>>; // { 멤버명: { 날짜: 근무코드 } }
  hardRules: string[]; // 절대 지켜야 할 하드룰 목록
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body: AnalyzeRequest = await req.json();

    const apiKey = Deno.env.get('OPENAI_API_KEY');
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'OPENAI_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const wantedPct =
      body.wantedTotal > 0
        ? Math.round((body.wantedSatisfied / body.wantedTotal) * 100)
        : 100;


    // 소프트 기피 패턴 위반 요약
    const softViol = body.softViolations ?? {};
    const softLines: string[] = [];
    if (softViol['NOD'])  softLines.push(`NOD(나이트→오프→데이) ${softViol['NOD']}회`);
    if (softViol['NOOD']) softLines.push(`NOOD(나이트→오프×2→데이) ${softViol['NOOD']}회`);
    if (softViol['NOE'])  softLines.push(`NOE(나이트→오프→이브닝) ${softViol['NOE']}회`);
    if (softViol['EOD'])  softLines.push(`EOD(이브닝→오프→데이) ${softViol['EOD']}회`);
    const softSummary = softLines.length > 0 ? softLines.join(', ') : '없음';

    const customViol = body.customRuleViolations ?? [];
    const customViolSummary = customViol.length > 0
      ? customViol.map((v) => `  - ${v}`).join('\n')
      : '  - 없음';

    // 전체 근무 배정표 compact 문자열
    const scheduleLines = Object.entries(body.memberSchedules ?? {})
      .map(([name, days]) => {
        const sorted = Object.entries(days)
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([date, code]) => `${date.slice(5)}=${code}`)  // MM-DD=X
          .join(', ');
        return `${name}: ${sorted}`;
      })
      .join('\n');

    const hardRulesSummary = (body.hardRules ?? []).map((r) => `  - ${r}`).join('\n');

    const prompt = `당신은 병원 근무표 분석 전문가입니다. 아래 전체 근무표와 하드룰을 기반으로 **검증된 해결 방안**만 제시해주세요.

## 절대 지켜야 할 하드룰 (제안 전 반드시 확인)
${hardRulesSummary}

## 전체 근무 배정표 (D=데이, E=이브닝, N=나이트, O=오프)
${scheduleLines}

## 위반 현황
- 인원 부족: ${body.understaffedCount}건
- 원티드 반영: ${body.wantedSatisfied}/${body.wantedTotal} (${wantedPct}%)
- 하드 위반: ${body.hardViolations.length}건
${body.hardViolations.length > 0 ? body.hardViolations.map((v) => `  - ${v}`).join('\n') : '  - 없음'}
- 기피패턴: ${softSummary}
- 커스텀 룰 위반:
${customViolSummary}

## 해결 방안 제안 절차 (반드시 이 순서로 실행)
1. 위 전체 배정표에서 관련 멤버의 해당 월 전체 근무를 확인하세요
2. 변경/교체하려는 날짜의 앞뒤 모든 날짜를 배정표에서 직접 읽어서 하드룰 위반 여부를 검증하세요
   - N→D: 변경일 전날이 N이면 해당 멤버에게 D 배정 불가
   - NOD: 변경일 전날이 오프이고 전전날이 N이면 해당 멤버에게 D 배정 불가
   - N→E: 전날이 N이면 E 배정 불가 (해당 룰 활성 시)
   - E→D: 전날이 E이면 D 배정 불가 (해당 룰 활성 시)
   - 연속 근무: 변경으로 인해 연속 근무일이 최대치 초과하는지 확인
   - 월 최대 근무: 변경 멤버의 월 총 근무 횟수 초과 여부 확인
3. 검증을 통과한 방안만 제안하세요. 하나도 없으면 "안전한 해결 방안을 찾지 못했습니다"라고 하세요

다음 형식으로 응답 (마크다운 없이 plain text, 전체 350자 이내):
1. 한줄 요약
2. 문제점 (있는 경우만, 최대 2개)
3. 해결 방안 (최대 2개, 검증 근거 간략 포함)
   예: "A의 MM/DD를 D→O로 변경하면 해결됩니다 (전날=O, 전전날=E이므로 시퀀스 위반 없음)"

없는 항목은 생략하세요.`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 512,
        messages: [{ role: 'user', content: prompt }],
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
    const analysis: string =
      data.choices?.[0]?.message?.content ?? '분석 결과를 가져올 수 없습니다.';

    return new Response(JSON.stringify({ analysis }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
