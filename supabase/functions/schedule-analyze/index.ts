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

type ScheduleTable = Record<string, Record<string, string>>;

type WorkCell = {
  member: string;
  date: string;
  code: string;
};

type ViolationIssue = {
  type: string;
  member: string;
  date: string;
  detail: string;
};

type ViolationSummary = {
  issues: ViolationIssue[];
  byMember: Record<string, number>;
  byType: Record<string, number>;
  total: number;
};

type SwapCandidate = {
  aMember: string;
  aDate: string;
  aCode: string;
  bMember: string;
  bDate: string;
  bCode: string;
  reducedViolations: number;
  remainingViolations: number;
  sameDay: boolean;
  note: string;
};

type HardRuleFlags = {
  ndForbidden: boolean;
  nodForbidden: boolean;
  noNightThenEvening: boolean;
  noEveningThenDay: boolean;
  maxConsecutiveWorkDays: number | null;
};

const DAY_ONLY_ATTR = '데이전용';
const NIGHT_EXEMPT_ATTR = '야간제외';
const NIGHT_DEDICATED_ATTR = '나이트전담';

function normalizeCode(raw: string | undefined): string {
  const code = (raw ?? '').trim().toUpperCase();
  if (!code) return 'O';
  if (code === 'OFF') return 'O';
  return code;
}

function isWorkingCode(code: string): boolean {
  return code !== 'O';
}

function mmdd(date: string): string {
  return date.length >= 10 ? date.slice(5) : date;
}

function parseHardRuleFlags(hardRules: string[] = []): HardRuleFlags {
  let maxConsecutiveWorkDays: number | null = null;

  for (const line of hardRules) {
    const match = line.match(/최대\s*(\d+)\s*일\s*연속\s*근무/);
    if (match) {
      const parsed = Number(match[1]);
      if (Number.isFinite(parsed) && parsed > 0) {
        maxConsecutiveWorkDays = parsed;
        break;
      }
    }
  }

  return {
    ndForbidden: true,
    nodForbidden: hardRules.some((r) => r.includes('NOD 금지')),
    noNightThenEvening: hardRules.some((r) => r.includes('N→E 금지')),
    noEveningThenDay: hardRules.some((r) => r.includes('E→D 금지')),
    maxConsecutiveWorkDays,
  };
}

function buildScheduleTable(
  body: AnalyzeRequest,
): { schedule: ScheduleTable; members: string[]; dates: string[] } {
  const input = body.memberSchedules ?? {};
  const schedule: ScheduleTable = {};
  const dateSet = new Set<string>();

  for (const [member, days] of Object.entries(input)) {
    schedule[member] = {};
    for (const [date, code] of Object.entries(days ?? {})) {
      const normalized = normalizeCode(code);
      schedule[member][date] = normalized;
      dateSet.add(date);
    }
  }

  if (Object.keys(schedule).length === 0) {
    for (const m of body.members ?? []) {
      if (!m?.name) continue;
      schedule[m.name] = {};
    }
  }

  const members = Object.keys(schedule).sort((a, b) => a.localeCompare(b));
  const dates = [...dateSet].sort((a, b) => a.localeCompare(b));
  return { schedule, members, dates };
}

function buildAttributeMap(
  members: { name: string; attributes: string[] }[] = [],
): Record<string, Set<string>> {
  const map: Record<string, Set<string>> = {};
  for (const m of members) {
    if (!m?.name) continue;
    map[m.name] = new Set((m.attributes ?? []).filter(Boolean));
  }
  return map;
}

function getCode(
  schedule: ScheduleTable,
  member: string,
  date: string,
): string {
  return schedule[member]?.[date] ?? 'O';
}

function detectViolations(params: {
  schedule: ScheduleTable;
  members: string[];
  dates: string[];
  attrMap: Record<string, Set<string>>;
  flags: HardRuleFlags;
}): ViolationSummary {
  const { schedule, members, dates, attrMap, flags } = params;
  const issues: ViolationIssue[] = [];
  const byMember: Record<string, number> = {};
  const byType: Record<string, number> = {};

  const pushIssue = (issue: ViolationIssue) => {
    issues.push(issue);
    byMember[issue.member] = (byMember[issue.member] ?? 0) + 1;
    byType[issue.type] = (byType[issue.type] ?? 0) + 1;
  };

  for (const member of members) {
    const attrs = attrMap[member] ?? new Set<string>();

    for (let i = 0; i < dates.length; i++) {
      const date = dates[i];
      const code = getCode(schedule, member, date);

      if (attrs.has(DAY_ONLY_ATTR) && isWorkingCode(code) && code !== 'D') {
        pushIssue({
          type: 'ATTR_DAY_ONLY',
          member,
          date,
          detail: `${member} ${mmdd(date)} ${code}: 데이전용 위반`,
        });
      }
      if (attrs.has(NIGHT_EXEMPT_ATTR) && code === 'N') {
        pushIssue({
          type: 'ATTR_NIGHT_EXEMPT',
          member,
          date,
          detail: `${member} ${mmdd(date)} N: 야간제외 위반`,
        });
      }
      if (attrs.has(NIGHT_DEDICATED_ATTR) && isWorkingCode(code) && code !== 'N') {
        pushIssue({
          type: 'ATTR_NIGHT_DEDICATED',
          member,
          date,
          detail: `${member} ${mmdd(date)} ${code}: 나이트전담 위반`,
        });
      }

      const prev1 = i > 0 ? getCode(schedule, member, dates[i - 1]) : 'O';
      const prev2 = i > 1 ? getCode(schedule, member, dates[i - 2]) : 'O';

      if (flags.ndForbidden && prev1 === 'N' && code === 'D') {
        pushIssue({
          type: 'SEQ_ND',
          member,
          date,
          detail: `${member} ${mmdd(date)}: N→D 위반`,
        });
      }
      if (flags.nodForbidden && prev2 === 'N' && prev1 === 'O' && code === 'D') {
        pushIssue({
          type: 'SEQ_NOD',
          member,
          date,
          detail: `${member} ${mmdd(date)}: NOD 위반`,
        });
      }
      if (flags.noNightThenEvening && prev1 === 'N' && code === 'E') {
        pushIssue({
          type: 'SEQ_NE',
          member,
          date,
          detail: `${member} ${mmdd(date)}: N→E 위반`,
        });
      }
      if (flags.noEveningThenDay && prev1 === 'E' && code === 'D') {
        pushIssue({
          type: 'SEQ_ED',
          member,
          date,
          detail: `${member} ${mmdd(date)}: E→D 위반`,
        });
      }
    }

    if (flags.maxConsecutiveWorkDays != null && flags.maxConsecutiveWorkDays > 0) {
      let streak = 0;
      for (let i = 0; i < dates.length; i++) {
        const date = dates[i];
        const code = getCode(schedule, member, date);
        if (isWorkingCode(code)) {
          streak += 1;
          if (streak > flags.maxConsecutiveWorkDays) {
            pushIssue({
              type: 'MAX_CONSEC_WORK',
              member,
              date,
              detail: `${member} ${mmdd(date)}: 연속근무 ${streak}일(제한 ${flags.maxConsecutiveWorkDays})`,
            });
          }
        } else {
          streak = 0;
        }
      }
    }
  }

  return {
    issues,
    byMember,
    byType,
    total: issues.length,
  };
}

function cloneSchedule(base: ScheduleTable): ScheduleTable {
  const next: ScheduleTable = {};
  for (const [member, days] of Object.entries(base)) {
    next[member] = { ...days };
  }
  return next;
}

function buildAssignments(
  schedule: ScheduleTable,
  members: string[],
  dates: string[],
): WorkCell[] {
  const cells: WorkCell[] = [];
  for (const member of members) {
    for (const date of dates) {
      const code = getCode(schedule, member, date);
      if (isWorkingCode(code)) {
        cells.push({ member, date, code });
      }
    }
  }
  return cells;
}

function swapCodes(
  base: ScheduleTable,
  a: WorkCell,
  b: WorkCell,
): ScheduleTable {
  const next = cloneSchedule(base);
  next[a.member] = { ...(next[a.member] ?? {}) };
  next[b.member] = { ...(next[b.member] ?? {}) };

  next[a.member][a.date] = b.code;
  next[b.member][b.date] = a.code;
  return next;
}

function buildCoverageCheck(activeRules: string[] = [], hardRules: string[] = []): {
  covered: string[];
  partial: string[];
} {
  const covered: string[] = [];
  const partial: string[] = [];

  const has = (keyword: string) =>
    activeRules.some((r) => r.includes(keyword)) ||
    hardRules.some((r) => r.includes(keyword));

  if (has('NOD')) covered.push('NOD');
  if (has('N→E')) covered.push('N→E');
  if (has('E→D')) covered.push('E→D');
  if (has('최대 연속 근무')) covered.push('최대 연속 근무일');
  covered.push('멤버 속성(나이트전담/야간제외/데이전용)');

  if (has('최소 인원')) partial.push('근무 유형별 최소 인원(min_staffing)');
  if (has('월 최대 근무')) partial.push('월 최대 근무 횟수(max_monthly_shifts)');
  if (has('월 최대 야간')) partial.push('월 최대 야간 횟수(max_monthly_night_shifts)');
  if (has('주 최소 오프')) partial.push('주 최소 오프(min_weekly_off_days)');
  if (has('커스텀')) partial.push('일부 커스텀 규칙(페어/숙련도/특수조건)');

  return { covered, partial };
}

function generateValidatedCandidates(params: {
  schedule: ScheduleTable;
  members: string[];
  dates: string[];
  attrMap: Record<string, Set<string>>;
  flags: HardRuleFlags;
}): {
  baseline: ViolationSummary;
  candidates: SwapCandidate[];
} {
  const { schedule, members, dates, attrMap, flags } = params;
  const baseline = detectViolations({
    schedule,
    members,
    dates,
    attrMap,
    flags,
  });

  if (dates.length === 0) {
    return { baseline, candidates: [] };
  }

  const assignments = buildAssignments(schedule, members, dates);
  if (assignments.length < 2) {
    return { baseline, candidates: [] };
  }

  const problematicMembers = new Set(baseline.issues.map((i) => i.member));
  const problematicDates = new Set(baseline.issues.map((i) => i.date));

  let sources = assignments.filter(
    (c) => problematicMembers.has(c.member) || problematicDates.has(c.date),
  );
  if (sources.length === 0) {
    sources = assignments;
  }

  const maxSource = Math.min(80, sources.length);
  const maxPartner = Math.min(180, assignments.length);

  const dedupe = new Set<string>();
  const candidates: SwapCandidate[] = [];

  for (let i = 0; i < maxSource; i++) {
    const a = sources[i];

    for (let j = 0; j < maxPartner; j++) {
      const b = assignments[j];

      if (a.member === b.member && a.date === b.date) continue;
      if (a.code === b.code) continue;

      const keyParts = [
        `${a.member}|${a.date}|${a.code}`,
        `${b.member}|${b.date}|${b.code}`,
      ].sort((x, y) => x.localeCompare(y));
      const pairKey = keyParts.join('::');
      if (dedupe.has(pairKey)) continue;
      dedupe.add(pairKey);

      const swapped = swapCodes(schedule, a, b);
      const post = detectViolations({
        schedule: swapped,
        members,
        dates,
        attrMap,
        flags,
      });

      const reduced = baseline.total - post.total;
      if (reduced <= 0) continue;

      const affectedMembers = new Set([a.member, b.member]);
      let memberRegressed = false;
      for (const member of affectedMembers) {
        const before = baseline.byMember[member] ?? 0;
        const after = post.byMember[member] ?? 0;
        if (after > before) {
          memberRegressed = true;
          break;
        }
      }
      if (memberRegressed) continue;

      const note = reduced >= 2
        ? '교환 후 하드 위반 감소 폭이 큼'
        : '교환 후 하드 위반 1건 감소';

      candidates.push({
        aMember: a.member,
        aDate: a.date,
        aCode: a.code,
        bMember: b.member,
        bDate: b.date,
        bCode: b.code,
        reducedViolations: reduced,
        remainingViolations: post.total,
        sameDay: a.date === b.date,
        note,
      });
    }
  }

  candidates.sort((x, y) => {
    if (x.reducedViolations !== y.reducedViolations) {
      return y.reducedViolations - x.reducedViolations;
    }
    if (x.sameDay !== y.sameDay) {
      return x.sameDay ? -1 : 1;
    }
    if (x.remainingViolations !== y.remainingViolations) {
      return x.remainingViolations - y.remainingViolations;
    }
    return (`${x.aMember}${x.aDate}`).localeCompare(`${y.aMember}${y.aDate}`);
  });

  const unique = new Set<string>();
  const top: SwapCandidate[] = [];
  for (const c of candidates) {
    const line = `${c.aMember}|${c.aDate}|${c.bMember}|${c.bDate}`;
    if (unique.has(line)) continue;
    unique.add(line);
    top.push(c);
    if (top.length >= 5) break;
  }

  return { baseline, candidates: top };
}

function buildDeterministicFallback(params: {
  body: AnalyzeRequest;
  wantedPct: number;
  softSummary: string;
  customViolSummaryLines: string[];
  coverage: { covered: string[]; partial: string[] };
  baseline: ViolationSummary;
  candidates: SwapCandidate[];
}): string {
  const {
    body,
    wantedPct,
    softSummary,
    customViolSummaryLines,
    coverage,
    baseline,
    candidates,
  } = params;

  const lines: string[] = [];
  lines.push(
    `종합 평가: 하드 위반 ${body.hardViolations.length}건, 인원 부족 ${body.understaffedCount}건, 원티드 반영 ${wantedPct}%`,
  );

  const keyProblems: string[] = [];
  for (const v of body.hardViolations.slice(0, 3)) keyProblems.push(`- ${v}`);
  if (body.understaffedCount > 0) {
    keyProblems.push(`- 인원 부족 ${body.understaffedCount}건`);
  }
  if (keyProblems.length === 0) keyProblems.push('- 심각한 하드 위반 없음');

  lines.push('심각한 문제:');
  lines.push(...keyProblems);
  lines.push(`기피 패턴: ${softSummary}`);
  if (customViolSummaryLines.length > 0) {
    lines.push('커스텀 룰 위반:');
    lines.push(...customViolSummaryLines.slice(0, 3));
  }

  lines.push('규칙 반영 체크:');
  lines.push(`- 검증 반영: ${coverage.covered.join(', ') || '기본 하드룰'}`);
  if (coverage.partial.length > 0) {
    lines.push(`- 데이터 부족으로 부분 반영: ${coverage.partial.join(', ')}`);
  }
  lines.push(`- 내부 하드룰 재검증 탐지 수: ${baseline.total}건`);

  lines.push('실행 가능한 교체안(하드룰 검증 통과):');
  if (candidates.length === 0) {
    lines.push('- 가능한 교환 방안을 찾지 못했습니다.');
  } else {
    for (const c of candidates.slice(0, 3)) {
      lines.push(
        `- ${c.aMember}의 ${mmdd(c.aDate)} ${c.aCode} ↔ ${c.bMember}의 ${mmdd(c.bDate)} ${c.bCode} (${c.note}, 잔여 하드위반 ${c.remainingViolations}건)`,
      );
    }
  }

  lines.push('즉시 실행 순서:');
  lines.push('1) 위 교체안 1순위 적용');
  lines.push('2) 적용 후 하드 위반/인원 부족 재검증');
  lines.push('3) 필요 시 2순위 교체안 순차 적용');

  return lines.join('\n');
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body: AnalyzeRequest = await req.json();

    const wantedPct =
      body.wantedTotal > 0
        ? Math.round((body.wantedSatisfied / body.wantedTotal) * 100)
        : 100;

    const softViol = body.softViolations ?? {};
    const softLines: string[] = [];
    if (softViol['NOD']) softLines.push(`NOD ${softViol['NOD']}회`);
    if (softViol['NOOD']) softLines.push(`NOOD ${softViol['NOOD']}회`);
    if (softViol['NOE']) softLines.push(`NOE ${softViol['NOE']}회`);
    if (softViol['EOD']) softLines.push(`EOD ${softViol['EOD']}회`);
    const softSummary = softLines.length > 0 ? softLines.join(', ') : '없음';

    const customViol = body.customRuleViolations ?? [];
    const customViolSummaryLines = customViol.map((v) => `- ${v}`);

    const { schedule, members, dates } = buildScheduleTable(body);
    const attrMap = buildAttributeMap(body.members ?? []);
    const flags = parseHardRuleFlags(body.hardRules ?? []);
    const coverage = buildCoverageCheck(body.activeRules ?? [], body.hardRules ?? []);

    const { baseline, candidates } = generateValidatedCandidates({
      schedule,
      members,
      dates,
      attrMap,
      flags,
    });

    const fallbackReport = buildDeterministicFallback({
      body,
      wantedPct,
      softSummary,
      customViolSummaryLines,
      coverage,
      baseline,
      candidates,
    });

    const totalSoftCount = Object.values(softViol).reduce((a, b) => a + b, 0);
    const totalIssues =
      (body.hardViolations?.length ?? 0) +
      (body.understaffedCount ?? 0) +
      totalSoftCount +
      customViol.length;

    if (totalIssues === 0) {
      return new Response(JSON.stringify({ analysis: fallbackReport }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const apiKey = Deno.env.get('OPENAI_API_KEY');
    if (!apiKey) {
      return new Response(JSON.stringify({ analysis: fallbackReport }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const scheduleLines = Object.entries(schedule)
      .map(([name, days]) => {
        const sorted = Object.entries(days)
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([date, code]) => `${date.slice(5)}=${code}`)
          .join(', ');
        return `${name}: ${sorted}`;
      })
      .join('\n');

    const hardRuleSummary = (body.hardRules ?? []).map((r) => `- ${r}`).join('\n') || '- 기본 하드룰';
    const activeRuleSummary = (body.activeRules ?? []).map((r) => `- ${r}`).join('\n') || '- 없음';
    const memberAttrSummary = (body.members ?? [])
      .map((m) => `- ${m.name}: ${(m.attributes ?? []).join(', ')}`)
      .join('\n') || '- 없음';
    const validatedCandidatesSummary = candidates.length > 0
      ? candidates
          .map(
            (c, idx) =>
              `${idx + 1}) ${c.aMember} ${mmdd(c.aDate)} ${c.aCode} ↔ ${c.bMember} ${mmdd(c.bDate)} ${c.bCode} | 위반감소 ${c.reducedViolations}건 | 잔여 ${c.remainingViolations}건 | ${c.note}`,
          )
          .join('\n')
      : '없음';

    const systemPrompt = `당신은 병원 3교대 스케줄 QA 분석가다.
목표: 하드룰을 어기지 않는, 실행 가능한 조치안만 제시한다.
중요 규칙:
- 반드시 아래 "검증 통과 교체 후보" 목록에서만 조치안을 고른다.
- 후보 목록에 없는 교환/변경안을 새로 만들지 않는다.
- OFF 추가/삭제 제안 금지, 1:1 교환만 허용.
- 보고서에는 근거와 실행 순서를 포함한다.
- 출력은 plain text, 마크다운 금지.`;

    const userPrompt = `팀: ${body.teamName}
기간: ${body.periodLabel}

[하드룰]
${hardRuleSummary}

[활성 규칙(엔진 설정)]
${activeRuleSummary}

[멤버 특수속성]
${memberAttrSummary}

[하드 위반 보고]
${(body.hardViolations ?? []).slice(0, 12).map((v) => `- ${v}`).join('\n') || '- 없음'}
인원 부족: ${body.understaffedCount}건
원티드: ${body.wantedSatisfied}/${body.wantedTotal} (${wantedPct}%)
기피 패턴: ${softSummary}
커스텀 위반: ${customViolSummaryLines.slice(0, 8).join('\n') || '- 없음'}

[규칙 반영 체크]
검증 반영: ${coverage.covered.join(', ') || '기본 하드룰'}
부분 반영(데이터 부족): ${coverage.partial.join(', ') || '없음'}
내부 하드룰 재검증 탐지: ${baseline.total}건

[배정표]
${scheduleLines}
ㄹ
[검증 통과 교체 후보(이 목록에서만 선택)]
${validatedCandidatesSummary}

[작성 형식]
1) 종합 평가 (2~3문장)
2) 심각 이슈 상세 (하드 위반 중심, 근거 날짜/멤버 포함)
3) 실행 가능한 조치안 (최대 3개, 반드시 후보 목록에서 선택)
4) 실행 순서 (번호 1~3)

후보가 없으면 "가능한 교환 방안을 찾지 못했습니다"라고 명시.`;

    const model = Deno.env.get('OPENAI_MODEL') ?? 'gpt-4o-mini';

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        max_tokens: 1200,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      return new Response(JSON.stringify({ analysis: fallbackReport }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const data = await response.json();
    const analysis: string =
      data.choices?.[0]?.message?.content?.trim() || fallbackReport;

    return new Response(JSON.stringify({ analysis }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
