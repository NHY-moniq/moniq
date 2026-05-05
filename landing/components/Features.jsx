// Feature sections — Calendar, Team gen, Request, Per-shift theming

// Feature 1: Your calendar
const FeatureCalendar = () => (
  <Section paddingY={140}>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'center' }}>
      <div>
        <LandingEyebrow style={{ color: '#B8860B' }}>Feature · 01</LandingEyebrow>
        <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
          한 달 치 근무를<br />하나의 캘린더로.
        </h2>
        <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 480 }}>
          각 날짜 아래의 점 하나로 <strong style={{ color: '#312F23' }}>Day · Evening · Night · OFF</strong> 구분. 복잡한 표는 이제 그만, 색깔만 봐도 오늘이 어떤 날인지 알 수 있어요.
        </p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 36 }}>
          {[
            { c: '#FFD700', label: 'Day Shift', sub: '08:00 — 16:00' },
            { c: '#FF8C00', label: 'Evening Shift', sub: '16:00 — 00:00' },
            { c: '#0061A4', label: 'Night Shift', sub: '00:00 — 08:00' },
            { c: '#A0AEC0', label: 'Off', sub: '푹 쉬세요!' },
          ].map(r => (
            <div key={r.label} style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              <div style={{ width: 14, height: 14, borderRadius: '50%', background: r.c, flexShrink: 0, boxShadow: `0 4px 10px ${r.c}80` }} />
              <div style={{ flex: 1 }}>
                <div style={{ font: '800 15px/1.2 var(--font-family)', color: '#312F23' }}>{r.label}</div>
                <div style={{ font: '500 13px/1.2 var(--font-family)', color: '#7A7768', marginTop: 3 }}>{r.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <PhoneFrame width={340} height={660} tilt={3}>
          <MiniCalendarScreen />
        </PhoneFrame>
      </div>
    </div>
  </Section>
);

// Feature 2: Team auto-generation
const FeatureTeamGen = () => {
  const colors = { D: '#FFD700', E: '#FF8C00', N: '#0061A4', O: '#E3DDC5' };
  const textCol = { D: '#453900', E: '#fff', N: '#fff', O: '#5F5C4D' };
  // Sample 7-day x 6-person roster
  const nurses = [
    { name: 'Joy', role: 'Head Nurse', roster: ['D','D','E','E','N','N','O'] },
    { name: 'Soojin', role: 'RN', roster: ['N','O','D','D','E','E','N'] },
    { name: 'Min', role: 'RN', roster: ['E','N','N','O','D','D','E'] },
    { name: 'Ha', role: 'RN', roster: ['O','E','N','N','O','D','D'] },
    { name: 'Tae', role: 'Charge', roster: ['D','E','O','D','D','E','N'] },
    { name: 'Yuna', role: 'RN', roster: ['E','N','D','O','E','N','D'] },
  ];
  const days = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
  return (
    <Section bg="#F7F1DC" paddingY={140}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.2fr', gap: 80, alignItems: 'center' }}>
        {/* Left: roster visualization */}
        <div style={{ background: '#FFFDF7', borderRadius: 36, padding: 28, boxShadow: '0 24px 48px rgba(49,47,35,.08)', border: '1px solid rgba(178,173,156,.25)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
            <div>
              <LandingEyebrow>Unit 4 Medical · Week of Oct 13</LandingEyebrow>
              <div style={{ font: '900 20px/1 var(--font-family)', color: '#312F23', marginTop: 6 }}>Auto-generated</div>
            </div>
            <LandingChip icon="auto_awesome" bg="rgba(255,193,7,.2)" color="#6B5300">Generated in 8s</LandingChip>
          </div>
          {/* Header */}
          <div style={{ display: 'grid', gridTemplateColumns: '110px repeat(7, 1fr)', gap: 4, marginBottom: 8 }}>
            <div></div>
            {days.map(d => <div key={d} style={{ textAlign: 'center', font: '800 9px/1 var(--font-family)', letterSpacing: 1.2, color: '#7A7768' }}>{d}</div>)}
          </div>
          {nurses.map((n, i) => (
            <div key={n.name} style={{ display: 'grid', gridTemplateColumns: '110px repeat(7, 1fr)', gap: 4, marginBottom: 4, alignItems: 'center' }}>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <div style={{ width: 28, height: 28, borderRadius: '50%', background: ['#FFC107','#FF8F00','#2196F3','#38A169','#FF8C00','#FFD700'][i], display: 'flex', alignItems: 'center', justifyContent: 'center', font: '900 10px/1 var(--font-family)', color: '#fff' }}>
                  {n.name[0]}
                </div>
                <div>
                  <div style={{ font: '800 12px/1 var(--font-family)', color: '#312F23' }}>{n.name}</div>
                  <div style={{ font: '500 9px/1 var(--font-family)', color: '#7A7768', marginTop: 2 }}>{n.role}</div>
                </div>
              </div>
              {n.roster.map((code, j) => (
                <div key={j} style={{
                  aspectRatio: '1', borderRadius: 10, background: colors[code], color: textCol[code],
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  font: '900 13px/1 var(--font-family)',
                }}>{code === 'O' ? '' : code}</div>
              ))}
            </div>
          ))}
        </div>
        {/* Right: copy */}
        <div>
          <LandingEyebrow style={{ color: '#E07800' }}>Feature · 02</LandingEyebrow>
          <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
            팀 근무표는<br />자동으로 짜드려요.
          </h2>
          <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 520 }}>
            수간호사 혼자 엑셀 붙잡고 씨름할 일 없어요. 팀 규칙과 팀원의 요청을 입력하면, Moniq가 공평한 근무표를 몇 초 안에 만들어요. 근무 밸런스 · 연차 · 야간 제한 · 개인 요청 전부 자동 반영.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 32 }}>
            {[
              { icon: 'balance', title: '근무 밸런스', sub: 'Day/Evening/Night 고르게' },
              { icon: 'rule', title: '팀 규칙', sub: '연속 야간, 최소 휴식 시간' },
              { icon: 'event_available', title: '개인 요청', sub: '휴무 · 근무 선호 반영' },
              { icon: 'sync', title: '즉시 재생성', sub: '규칙 바꾸면 바로 재배포' },
            ].map(f => (
              <div key={f.title} style={{ background: '#FFFDF7', borderRadius: 24, padding: 18, display: 'flex', gap: 12, alignItems: 'flex-start', border: '1px solid rgba(178,173,156,.25)' }}>
                <div style={{ width: 38, height: 38, borderRadius: 14, background: '#FFECB3', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: 20, color: '#B8860B', fontVariationSettings: "'FILL' 1" }}>{f.icon}</span>
                </div>
                <div>
                  <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>{f.title}</div>
                  <div style={{ font: '500 12px/1.35 var(--font-family)', color: '#5F5C4D', marginTop: 4 }}>{f.sub}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Section>
  );
};

// Feature 3: Swap request
const FeatureSwap = () => (
  <Section paddingY={140}>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'center' }}>
      <div>
        <LandingEyebrow style={{ color: '#0061A4' }}>Feature · 03</LandingEyebrow>
        <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
          교대 · 변경,<br />탭 한 번이면 끝.
        </h2>
        <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 480 }}>
          누구와 바꿀지, 어떤 날로 바꿀지 선택만 하면 돼요. 수간호사 승인까지 앱 안에서. 카톡방 돌려가며 허락 구할 필요 없이 간단하게.
        </p>
        <div style={{ display: 'flex', gap: 12, marginTop: 36, flexWrap: 'wrap' }}>
          <LandingChip icon="touch_app" bg="rgba(0,97,164,.12)" color="#0061A4">한 번의 탭</LandingChip>
          <LandingChip icon="verified" bg="rgba(56,161,105,.15)" color="#2F7A52">자동 승인 플로우</LandingChip>
          <LandingChip icon="history" bg="rgba(160,174,192,.2)" color="#5F5C4D">기록 보관</LandingChip>
        </div>
        <div style={{ marginTop: 44, padding: 24, background: '#FFFDF7', borderRadius: 24, border: '1px solid rgba(178,173,156,.25)' }}>
          <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
            <div style={{ width: 44, height: 44, borderRadius: '50%', background: '#0061A4', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, color: '#fff', font: '900 14px/1 var(--font-family)' }}>JS</div>
            <div style={{ flex: 1 }}>
              <div style={{ font: '700 13px/1.4 var(--font-family)', color: '#5F5C4D' }}><strong style={{ color: '#312F23' }}>Joy 간호사님</strong>이 교대를 요청했어요.</div>
              <div style={{ font: '500 12px/1.4 var(--font-family)', color: '#7A7768', marginTop: 6 }}>10월 15일 Day → 10월 17일 OFF (Soojin과 교대)</div>
              <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
                <button style={{ border: 'none', background: '#FFC107', color: '#453900', padding: '8px 16px', borderRadius: 9999, font: '800 12px/1 var(--font-family)' }}>승인</button>
                <button style={{ border: '1.5px solid rgba(49,47,35,.15)', background: 'transparent', color: '#312F23', padding: '8px 16px', borderRadius: 9999, font: '800 12px/1 var(--font-family)' }}>확인 중</button>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <PhoneFrame width={340} height={660} tilt={-3}>
          <MiniRequestScreen />
        </PhoneFrame>
      </div>
    </div>
  </Section>
);

// Per-shift theming section — three phones on a gradient
const FeatureShiftTheming = () => (
  <Section bg="#312F23" paddingY={140} style={{ color: '#FCF6E3' }}>
    <div style={{ textAlign: 'center', marginBottom: 72 }}>
      <LandingEyebrow color="#FCF6E3" style={{ opacity: .6 }}>Per-shift theming</LandingEyebrow>
      <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, marginTop: 18, color: '#FCF6E3', textWrap: 'balance', maxWidth: 760, margin: '18px auto 20px' }}>
        오늘의 근무에 맞춰<br />앱도 옷을 갈아입어요.
      </h2>
      <p style={{ font: '500 17px/1.55 var(--font-family)', color: 'rgba(252,246,227,.75)', maxWidth: 560, margin: '0 auto' }}>
        Day는 따뜻한 크림, Night는 차분한 쿨톤. 화면 색이 바뀌면 마음의 준비도 함께 돼요.
      </p>
    </div>
    <div style={{ display: 'flex', justifyContent: 'center', gap: 24, flexWrap: 'wrap' }}>
      {[
        { shift: 'day', label: 'Day' },
        { shift: 'evening', label: 'Evening' },
        { shift: 'night', label: 'Night' },
      ].map((t, i) => (
        <div key={t.shift} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20 }}>
          <PhoneFrame width={280} height={560} tilt={[-4, 0, 4][i]} shadow="0 40px 80px rgba(0,0,0,.4)">
            <MiniHomeScreen shift={t.shift} />
          </PhoneFrame>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 10, height: 10, borderRadius: '50%', background: SHIFTS_LANDING[t.shift].card }} />
            <div style={{ font: '800 11px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FCF6E3' }}>{t.label} Shift</div>
          </div>
        </div>
      ))}
    </div>
  </Section>
);

Object.assign(window, { FeatureCalendar, FeatureTeamGen, FeatureSwap, FeatureShiftTheming });
