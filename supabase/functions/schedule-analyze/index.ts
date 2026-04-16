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
  memberSchedules: Record<string, Record<string, string>>;
  hardRules: string[];
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

    // 위반 0건 — AI 호출 없이 즉시 양호 응답
    const totalSoftCount = Object.values(softViol).reduce((a, b) => a + b, 0);
    const totalIssues = (body.hardViolations?.length ?? 0) + (body.understaffedCount ?? 0);
    if (totalIssues === 0 && totalSoftCount === 0 && customViol.length === 0) {
      const quickAnalysis = `종합 평가: 양호\n희망 반영률: ${wantedPct}%${wantedPct < 100 ? ` (미반영 ${body.wantedTotal - body.wantedSatisfied}건)` : ''}\n심각한 위반 없이 규칙을 잘 준수한 근무표입니다.`;
      return new Response(JSON.stringify({ analysis: quickAnalysis }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 전체 근무 배정표 compact 문자열
    const scheduleLines = Object.entries(body.memberSchedules ?? {})
      .map(([name, days]) => {
        const sorted = Object.entries(days)
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([date, code]) => `${date.slice(5)}=${code}`)
          .join(', ');
        return `${name}: ${sorted}`;
      })
      .join('\n');

    const hardRulesSummary = (body.hardRules ?? []).map((r) => `  - ${r}`).join('\n');

    // System prompt — 역할 + 검증 원칙
    const systemPrompt = `당신은 병원 3교대 근무표 검증 전문가입니다.
역할: 위반 사항을 분석하고, 하드룰을 절대 위반하지 않는 교체 방안만 제시합니다.

허용되는 해결 방안:
- 같은 날 두 멤버 간 근무 교환 (예: A의 D ↔ B의 E)
- 다른 날짜 간 근무 교환 (예: A의 4/3 D ↔ A의 4/5 E)
- 반드시 1:1 교환이어야 하며, 교환 후 양쪽 모두 위반이 없어야 함

절대 금지되는 제안:
- 근무를 OFF로 변경 (총 근무 수 감소 — 불공정)
- OFF를 근무로 변경 (총 근무 수 증가 — 불공정)
- 특정 멤버에게만 불이익이 가는 일방적 변경

검증 원칙:
- 교체 제안 시 반드시 해당 멤버의 전후 3일 근무를 배정표에서 직접 확인
- 교체로 인해 새로운 위반이 생기면 해당 방안은 제외
- N→D, NOD, N→E, E→D 등 시퀀스 룰은 변경일 전후를 반드시 확인
- 안전한 방안이 없으면 "안전한 교환 방안을 찾지 못했습니다"로 명시
- 추측하지 말고, 배정표에 있는 데이터만 근거로 사용`;

    // User prompt — 위반 유형별 구조화
    const userPrompt = `## 팀: ${body.teamName} | 기간: ${body.periodLabel}

## 하드룰
${hardRulesSummary}

## 배정표 (D=데이, E=이브닝, N=나이트, O=오프)
${scheduleLines}

## 위반 분석 요청
### 심각 (하드 위반) — ${body.hardViolations.length}건
${body.hardViolations.length > 0 ? body.hardViolations.map((v) => `  - ${v}`).join('\n') : '  - 없음'}

### 인원 부족 — ${body.understaffedCount}건

### 희망 반영 — ${body.wantedSatisfied}/${body.wantedTotal} (${wantedPct}%)

### 기피 패턴 — ${softSummary}

### 커스텀 룰 위반
${customViolSummary}

## 응답 형식 (plain text, 500자 이내, 마크다운 금지)
1. 종합 평가 (한줄)
2. 심각한 문제 (하드 위반 우선, 최대 3개)
3. 교환 방안 (1:1 교환만 허용, 최대 3개)
   형식: "{멤버A}의 {MM/DD} {근무} ↔ {멤버B}의 {MM/DD} {근무} (근거: 교환 후 양쪽 전후 시퀀스 위반 없음)"

없는 항목은 생략하세요.`;

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
