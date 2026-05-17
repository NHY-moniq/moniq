// Feature sections — Calendar, Team gen, Request, Per-shift theming

// Feature 1: Personal calendar — team shifts auto-sync + personal events
const FeaturePersonalCalendar = () => (
  <Section paddingY={140}>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'center' }}>
      <div>
        <LandingEyebrow style={{ color: '#B8860B' }}>Feature · 07</LandingEyebrow>
        <h2 style={{ font: '900 40px/1.15 var(--font-family)', letterSpacing: -1.2, color: '#312F23', marginTop: 18, textWrap: 'balance', wordBreak: 'keep-all' }}>
          개인 캘린더에서 근무와 개인 일정을<br />한번에 관리할 수 있어요.
        </h2>
        <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 520, wordBreak: 'keep-all' }}>
          팀에 등록된 근무가 내 캘린더에 그대로 흘러들어와요.<br />
          그 위에 개인 일정·메모도 같이 적어두면, 근무와 사생활을 한 화면에서 정리할 수 있어요.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 36 }}>
          {[
            { icon: 'sync', title: '자동 동기화', sub: '팀 근무 등록 → 내 캘린더에 즉시 반영' },
            { icon: 'edit_note', title: '개인 일정·메모', sub: '약속, 휴가 계획, 한 줄 메모까지' },
            { icon: 'palette', title: '근무 컬러', sub: '날짜마다 점 하나로 한눈 구분' },
            { icon: 'lock', title: '내 데이터', sub: '개인 일정은 나만 볼 수 있어요' },
          ].map(f => (
            <div key={f.title} style={{ background: '#FFFDF7', borderRadius: 24, padding: 18, display: 'flex', gap: 12, alignItems: 'flex-start', border: '1px solid rgba(178,173,156,.25)' }}>
              <div style={{ width: 38, height: 38, borderRadius: 14, background: '#FFECB3', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ fontSize: 20, color: '#B8860B', fontVariationSettings: "'FILL' 1" }}>{f.icon}</span>
              </div>
              <div>
                <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>{f.title}</div>
                <div style={{ font: '500 12px/1.4 var(--font-family)', color: '#5F5C4D', marginTop: 4 }}>{f.sub}</div>
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

// Feature 2: Team calendar — free team creation + shared schedule view
const FeatureTeamCalendar = () => (
  <Section bg="#F7F1DC" paddingY={140}>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'center' }}>
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <PhoneFrame width={340} height={660} tilt={-3}>
          <MiniTeamCalendarScreen />
        </PhoneFrame>
      </div>
      <div>
        <LandingEyebrow style={{ color: '#E07800' }}>Feature · 06</LandingEyebrow>
        <h2 style={{ font: '900 54px/1.05 var(--font-family)', letterSpacing: -1.6, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
          팀 캘린더 자동 연동으로<br />근무를 쉽고 빠르게 파악할 수 있어요.
        </h2>
        <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 520 }}>
          병동이든 식당이든, 함께 일하는 사람이라면 팀이 돼요.<br />
          한 화면에서 누가 언제 들어오고 누가 쉬는지 한눈에 확인해요.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 32 }}>
          {[
            { icon: 'group_add', title: '팀 자유 생성', sub: '직군 · 규모 제한 없이 만들어요' },
            { icon: 'visibility', title: '팀원 근무 한눈에', sub: '오늘 누가 들어오는지 바로 확인' },
            { icon: 'palette', title: '팀별 근무 유형', sub: '이름 · 시간 · 색을 자유롭게' },
            { icon: 'qr_code_2', title: '초대 코드', sub: '코드 한 줄로 팀원 합류' },
          ].map(f => (
            <div key={f.title} style={{ background: '#FFFDF7', borderRadius: 24, padding: 18, display: 'flex', gap: 12, alignItems: 'flex-start', border: '1px solid rgba(178,173,156,.25)' }}>
              <div style={{ width: 38, height: 38, borderRadius: 14, background: 'rgba(255,140,0,.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ fontSize: 20, color: '#E07800', fontVariationSettings: "'FILL' 1" }}>{f.icon}</span>
              </div>
              <div>
                <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>{f.title}</div>
                <div style={{ font: '500 12px/1.4 var(--font-family)', color: '#5F5C4D', marginTop: 4 }}>{f.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  </Section>
);

// Feature 4: Swap request
const FeatureSwap = () => (
  <Section paddingY={140}>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'center' }}>
      <div>
        <LandingEyebrow style={{ color: '#0061A4' }}>Feature · 05</LandingEyebrow>
        <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
          교대 · 변경,<br />탭 한 번이면 끝.
        </h2>
        <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 480 }}>
          누구와 바꿀지, 어떤 날로 바꿀지 선택만 하면 돼요.<br />
          수간호사 승인까지 앱 안에서 끝나요.<br />
          카톡방 돌려가며 허락 구할 필요 없이 간단하게.
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

// Feature 2.5: Wanted collection — 자동생성 직전 단계, 팀원 의견 수집
const FeatureWantedCollection = () => {
  const cards = [
    { icon: 'how_to_vote', title: '팀원이 직접 입력', sub: '카톡방 대신 앱 한 곳에서 받아요' },
    { icon: 'star', title: '1·2순위 우선순위', sub: '날짜·시프트별로 우선순위까지' },
    { icon: 'group', title: '응답률 추적', sub: '누가 몇 건 냈는지 한눈에' },
    { icon: 'event_available', title: '마감·재개·재시작', sub: '수집 운영도 한 화면에서' },
  ];
  return (
    <Section bg="#FCF6E3" paddingY={140}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'center' }}>
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <PhoneFrame width={340} height={660} tilt={3}>
            <MiniWantedCollectionScreen />
          </PhoneFrame>
        </div>
        <div>
          <LandingEyebrow style={{ color: '#B8860B' }}>Feature · 04 — Wanted Collection</LandingEyebrow>
          <h2 style={{ font: '900 54px/1.05 var(--font-family)', letterSpacing: -1.6, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
            카톡방 대신 원티드,<br />앱 한 곳에서 정리돼요.
          </h2>
          <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 520 }}>
            "이번 달 원티드 받습니다~" 카톡과 엑셀 정리는 이제 그만.<br />
            팀원이 직접 원하는 날짜·시프트를 1·2순위로 입력하고, 수집이 끝나면 자동생성에 그대로 흘러들어가요.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 32 }}>
            {cards.map(f => (
              <div key={f.title} style={{ background: '#FFFDF7', borderRadius: 24, padding: 18, display: 'flex', gap: 12, alignItems: 'flex-start', border: '1px solid rgba(178,173,156,.25)' }}>
                <div style={{ width: 38, height: 38, borderRadius: 14, background: '#FFECB3', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: 20, color: '#B8860B', fontVariationSettings: "'FILL' 1" }}>{f.icon}</span>
                </div>
                <div>
                  <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>{f.title}</div>
                  <div style={{ font: '500 12px/1.4 var(--font-family)', color: '#5F5C4D', marginTop: 4 }}>{f.sub}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Section>
  );
};

// Feature 3-A: Schedule auto-generation with strict rules — flagship section
const FeatureScheduleAutoGen = () => {
  const rules = [
    { icon: 'block', label: '기피 근무 등록 및 고려', sub: '못 하는 시간대를 미리 알려두면 알아서 빼요' },
    { icon: 'flag', label: '원티드 반영 우선순위 설정', sub: '누구의 요청을 먼저 반영할지 정해요' },
    { icon: 'workspace_premium', label: '숙련도 배치', sub: '신입-베테랑 균형을 자동으로 조정해요' },
  ];
  return (
    <Section paddingY={180}>
      <div style={{ textAlign: 'center', marginBottom: 56 }}>
        <LandingChip icon="auto_awesome" bg="rgba(255,193,7,.18)" color="#6B5300">Feature · 01 — Schedule Generation</LandingChip>
        <h2 style={{
          font: '900 76px/1 var(--font-family)',
          letterSpacing: -2.4, color: '#312F23',
          marginTop: 24, textWrap: 'balance',
          maxWidth: 880, margin: '24px auto 0',
        }}>
          근무표 자동생성, 그런데<br />
          <span style={{
            background: 'linear-gradient(120deg, #FFC107 0%, #FF8C00 60%, #0061A4 110%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
          }}>규칙은 깐깐하게.</span>
        </h2>
        <p style={{
          font: '500 19px/1.6 var(--font-family)',
          color: '#5F5C4D',
          maxWidth: 720, margin: '24px auto 0',
          textWrap: 'balance',
        }}>
          수간호사 혼자 엑셀 붙잡을 일은 없어요.<br />
          <strong style={{ color: '#312F23', fontWeight: 800 }}>연차·연속야간·최소휴식·시프트별 인원</strong> 같은 규칙을 세세하게 설정하면, 공평한 근무표를 몇 초 안에 만들어요.
        </p>
      </div>
      {/* Hero visual: 노트북에 자동 생성된 근무표가 떠 있는 모습 */}
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 40, marginBottom: 64 }}>
        <LaptopFrame width={1040} tilt={-2}>
          <MiniScheduleGenScreen />
        </LaptopFrame>
      </div>
      {/* Rule cards — 3 카드 가로 배열 + 강조 CTA 카드 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginTop: 8 }}>
        {rules.map(r => (
          <div key={r.label} style={{
            background: '#FFFDF7', borderRadius: 24, padding: '24px 26px',
            display: 'flex', gap: 16, alignItems: 'flex-start',
            border: '1px solid rgba(178,173,156,.25)',
            boxShadow: '0 8px 20px rgba(49,47,35,.04)',
          }}>
            <div style={{
              width: 48, height: 48, borderRadius: 14,
              background: '#FFECB3',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: 24, color: '#B8860B', fontVariationSettings: "'FILL' 1" }}>{r.icon}</span>
            </div>
            <div>
              <div style={{ font: '900 16px/1.25 var(--font-family)', color: '#312F23' }}>{r.label}</div>
              <div style={{ font: '500 13px/1.5 var(--font-family)', color: '#5F5C4D', marginTop: 6 }}>{r.sub}</div>
            </div>
          </div>
        ))}
      </div>
      <div style={{
        background: 'linear-gradient(135deg, #FFD700, #FF8C00)',
        borderRadius: 24, padding: '20px 28px',
        display: 'flex', gap: 16, alignItems: 'center',
        boxShadow: '0 16px 32px rgba(255,140,0,.22)',
        color: '#312F23',
        marginTop: 16,
      }}>
        <span className="material-symbols-outlined" style={{ fontSize: 28, fontVariationSettings: "'FILL' 1" }}>bolt</span>
        <div style={{ flex: 1 }}>
          <div style={{ font: '900 15px/1.2 var(--font-family)' }}>몇 초 안에 완성.</div>
          <div style={{ font: '600 13px/1.4 var(--font-family)', marginTop: 4, color: 'rgba(49,47,35,.78)' }}>
            규칙을 바꾸면 즉시 재생성해요.
          </div>
        </div>
      </div>
    </Section>
  );
};

// Feature 3-C: AI fairness report — runs right after schedule generation
const FeatureAIReport = () => {
  const cards = [
    { icon: 'workspace_premium', label: '숙련도 배치', sub: '신입-베테랑이 골고루 섞였는지 한눈에' },
    { icon: 'thumb_down', label: '기피 패턴 처리율', sub: '연속 야간·N→D 같은 기피 패턴이 얼마나 빠졌는지 % 단위로' },
  ];
  return (
    <Section paddingY={180}>
      {/* Subtle orange-tinted blob to echo the AI accent */}
      <div aria-hidden style={{ position: 'absolute', width: 420, height: 420, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,140,0,.18), transparent 70%)', top: -80, right: -120, filter: 'blur(60px)', pointerEvents: 'none' }} />
      <div style={{ textAlign: 'center', marginBottom: 56, position: 'relative' }}>
        <LandingChip icon="auto_awesome" bg="rgba(255,140,0,.16)" color="#B05A00">Feature · 02 — AI 분석 리포트</LandingChip>
        <h2 style={{
          font: '900 68px/1.05 var(--font-family)',
          letterSpacing: -2.0, color: '#312F23',
          marginTop: 24, textWrap: 'balance',
          maxWidth: 980, margin: '24px auto 0',
        }}>
          AI 분석을 통한 스케줄 피드백으로<br />
          <span style={{
            background: 'linear-gradient(120deg, #FFB300 0%, #FF8C00 55%, #E55A00 110%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
          }}>점점 더 똑똑하게.</span>
        </h2>
        <p style={{
          font: '500 19px/1.6 var(--font-family)',
          color: '#5F5C4D',
          maxWidth: 680, margin: '24px auto 0',
          textWrap: 'balance',
        }}>
          생성 직후 숙련도 배치와 기피 패턴 처리율을 한눈에 보여줘요.<br />
          "왜 이렇게 짰어요?" 물어볼 필요 없이, 숫자가 먼저 답해요.
        </p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 60, alignItems: 'center', marginTop: 32, position: 'relative' }}>
        {/* Left: phone */}
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <PhoneFrame width={340} height={660} tilt={-3}>
            <MiniAIReportCard />
          </PhoneFrame>
        </div>
        {/* Right: 3 fairness cards stacked */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {cards.map(c => (
            <div key={c.label} style={{
              background: '#FFFDF7', borderRadius: 28, padding: '26px 30px',
              display: 'flex', gap: 18, alignItems: 'center',
              border: '1px solid rgba(178,173,156,.25)',
              boxShadow: '0 8px 20px rgba(49,47,35,.04)',
            }}>
              <div style={{
                width: 52, height: 52, borderRadius: 16,
                background: 'linear-gradient(135deg, #FFD180, #FF8C00)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0,
                boxShadow: '0 8px 18px rgba(255,140,0,.28)',
              }}>
                <span className="material-symbols-outlined" style={{ fontSize: 26, color: '#FFFDF7', fontVariationSettings: "'FILL' 1" }}>{c.icon}</span>
              </div>
              <div>
                <div style={{ font: '900 17px/1.2 var(--font-family)', color: '#312F23' }}>{c.label}</div>
                <div style={{ font: '500 14px/1.45 var(--font-family)', color: '#5F5C4D', marginTop: 6 }}>{c.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </Section>
  );
};

// Feature 3-B: Natural-language custom rules — flagship section
const FeatureCustomRules = () => {
  const examples = [
    { text: '주말은 베테랑이 들어가게 해줘.', tag: 'soft' },
    { text: '나이트 다음 데이는 금지.', tag: 'hard' },
    { text: '신입은 첫 주 야간 빼주세요.', tag: 'soft' },
    { text: '월요일 오프는 골고루 분배.', tag: 'soft' },
    { text: 'A 간호사와 B 간호사는 같은 시프트로.', tag: 'hard' },
  ];
  const tagStyle = (t) => t === 'hard'
    ? { bg: 'rgba(176,37,0,.12)', fg: '#B02500', label: '하드' }
    : { bg: 'rgba(255,193,7,.18)', fg: '#6B5300', label: '소프트' };
  return (
    <Section bg="#312F23" paddingY={180} style={{ color: '#FCF6E3', position: 'relative' }}>
      {/* decorative blobs */}
      <div aria-hidden style={{ position: 'absolute', width: 480, height: 480, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,215,0,.18), transparent 70%)', top: -120, left: -100, filter: 'blur(60px)', pointerEvents: 'none' }} />
      <div aria-hidden style={{ position: 'absolute', width: 380, height: 380, borderRadius: '50%', background: 'radial-gradient(circle, rgba(0,97,164,.22), transparent 70%)', bottom: -80, right: -80, filter: 'blur(60px)', pointerEvents: 'none' }} />
      <div style={{ textAlign: 'center', marginBottom: 56, position: 'relative' }}>
        <LandingChip icon="psychology" bg="rgba(255,215,0,.15)" color="#FFD700">Feature · 03 — Custom Rules</LandingChip>
        <h2 style={{
          font: '900 68px/1.05 var(--font-family)',
          letterSpacing: -2.2, color: '#FCF6E3',
          marginTop: 24, textWrap: 'balance',
          maxWidth: 940, margin: '24px auto 0',
        }}>
          우리만의 규칙이 있다면<br />
          <span style={{ color: '#FFD700' }}>OnorOff에 규칙으로 등록하세요.</span>
        </h2>
        <p style={{
          font: '500 19px/1.6 var(--font-family)',
          color: 'rgba(252,246,227,.72)',
          maxWidth: 640, margin: '24px auto 0',
          textWrap: 'balance',
        }}>
          정해진 옵션 밖의 규칙도 자연어로 입력해요.<br />
          AI가 의미를 파악해서 근무표에 반영하고, 하드·소프트 우선순위까지 자동 분류해요.
        </p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 60, alignItems: 'center', marginTop: 32, position: 'relative' }}>
        {/* Left: chat-like input mock */}
        <div style={{
          background: 'rgba(252,246,227,.06)',
          backdropFilter: 'blur(12px)',
          borderRadius: 32,
          padding: 28,
          border: '1px solid rgba(252,246,227,.1)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
            <div style={{ width: 10, height: 10, borderRadius: '50%', background: '#38A169' }} />
            <div style={{ font: '700 11px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase', color: 'rgba(252,246,227,.6)' }}>커스텀 규칙 입력</div>
          </div>
          {examples.map((ex, i) => {
            const t = tagStyle(ex.tag);
            return (
              <div key={i} style={{
                background: '#FFFDF7',
                color: '#312F23',
                borderRadius: 18,
                padding: '14px 16px',
                marginBottom: 10,
                display: 'flex',
                alignItems: 'flex-start',
                gap: 12,
                boxShadow: '0 8px 18px rgba(0,0,0,.18)',
              }}>
                <span className="material-symbols-outlined" style={{ fontSize: 18, color: '#7A7768', marginTop: 2 }}>chat_bubble</span>
                <div style={{ flex: 1, font: '600 14px/1.45 var(--font-family)' }}>{ex.text}</div>
                <span style={{
                  background: t.bg, color: t.fg,
                  padding: '4px 10px', borderRadius: 9999,
                  font: '800 10px/1 var(--font-family)', letterSpacing: 1.2,
                  flexShrink: 0,
                }}>{t.label}</span>
              </div>
            );
          })}
          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            <div style={{
              flex: 1,
              background: 'rgba(252,246,227,.08)',
              borderRadius: 18,
              padding: '14px 16px',
              font: '500 14px/1.45 var(--font-family)',
              color: 'rgba(252,246,227,.5)',
            }}>
              어떤 규칙이 필요한가요?
            </div>
            <button style={{
              width: 48, height: 48, borderRadius: '50%',
              background: '#FFD700', border: 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer',
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: 22, color: '#312F23', fontVariationSettings: "'FILL' 1" }}>arrow_upward</span>
            </button>
          </div>
          {/* 소프트/하드 각주 — 입력 mock 바로 아래 */}
          <div style={{
            marginTop: 18,
            paddingTop: 16,
            borderTop: '1px solid rgba(252,246,227,.1)',
            display: 'flex',
            flexDirection: 'column',
            gap: 8,
            font: '500 12px/1.55 var(--font-family)',
            color: 'rgba(252,246,227,.6)',
          }}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
              <span style={{
                background: 'rgba(176,37,0,.18)', color: '#FF8C7A',
                padding: '3px 8px', borderRadius: 9999,
                font: '800 9px/1 var(--font-family)', letterSpacing: 1.2,
                flexShrink: 0, marginTop: 1,
              }}>하드</span>
              <span>반드시 지켜야 하는 규칙. 위반 시 생성이 막혀요.</span>
            </div>
            <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
              <span style={{
                background: 'rgba(255,193,7,.2)', color: '#FFD700',
                padding: '3px 8px', borderRadius: 9999,
                font: '800 9px/1 var(--font-family)', letterSpacing: 1.2,
                flexShrink: 0, marginTop: 1,
              }}>소프트</span>
              <span>가급적 지키도록 노력하는 규칙. 충돌하면 우선순위에 따라 조정해요.</span>
            </div>
          </div>
        </div>
        {/* Right: phone */}
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <PhoneFrame width={340} height={660} tilt={-3} shadow="0 40px 80px rgba(0,0,0,.4)">
            <MiniCustomRulesScreen />
          </PhoneFrame>
        </div>
      </div>
    </Section>
  );
};

Object.assign(window, { FeaturePersonalCalendar, FeatureTeamCalendar, FeatureScheduleAutoGen, FeatureAIReport, FeatureCustomRules, FeatureSwap, FeatureWantedCollection });
