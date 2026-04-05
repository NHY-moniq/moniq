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
  softViolations: Record<string, number>; // {'NOD':1,'NOOD':3,'NOE':2,'EOD':1}
  members: { name: string; attributes: string[] }[];
  activeRules: string[];
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

    const memberSummary = body.members
      .filter((m) => m.attributes.length > 0)
      .map((m) => `${m.name}(${m.attributes.join(',')})`)
      .join(', ');

    // 소프트 기피 패턴 위반 요약
    const softViol = body.softViolations ?? {};
    const softLines: string[] = [];
    if (softViol['NOD'])  softLines.push(`NOD(나이트→오프→데이) ${softViol['NOD']}회`);
    if (softViol['NOOD']) softLines.push(`NOOD(나이트→오프×2→데이) ${softViol['NOOD']}회`);
    if (softViol['NOE'])  softLines.push(`NOE(나이트→오프→이브닝) ${softViol['NOE']}회`);
    if (softViol['EOD'])  softLines.push(`EOD(이브닝→오프→데이) ${softViol['EOD']}회`);
    const softSummary = softLines.length > 0 ? softLines.join(', ') : '없음';

    const prompt = `당신은 병원 근무표 분석 전문가입니다. 아래 생성된 근무표 정보를 분석하고 한국어로 간결하게 피드백을 제공해주세요.

## 근무표 정보
- 기간: ${body.periodLabel}
- 팀명: ${body.teamName}
- 팀원 수: ${body.members.length}명
- 특별 속성 팀원: ${memberSummary || '없음'}

## 결과 요약
- 인원 부족 발생: ${body.understaffedCount}건
- 원티드 반영률: ${body.wantedSatisfied}/${body.wantedTotal} (${wantedPct}%)
- 하드 위반: ${body.hardViolations.length}건
${body.hardViolations.length > 0 ? body.hardViolations.map((v) => `  - ${v}`).join('\n') : '  - 없음'}

## 소프트 기피패턴 위반 (생체리듬 관련)
- 실제 발생: ${softSummary}
※ NOD/NOOD = 나이트 후 짧은 간격으로 데이 복귀 (피로 누적 위험)
※ NOE = 나이트 후 이브닝 (역방향 순환)
※ EOD = 이브닝 후 데이 (짧은 간격)

## 적용 규칙
${body.activeRules.map((r) => `- ${r}`).join('\n')}

다음 형식으로 응답해주세요 (마크다운 없이 plain text, 번호 목록):
1. 전체 요약 (1~2문장)
2. 주요 문제점 (있는 경우만, 최대 3개 — 소프트 기피패턴 위반이 있으면 반드시 포함)
3. 개선 제안 (있는 경우만, 최대 2개)

없는 항목은 생략하세요. 전체 250자 이내로 간결하게 작성하세요.`;

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
