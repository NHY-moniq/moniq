// Feature sections — Calendar, Team gen, Request, Per-shift theming

// Feature 1: Personal calendar — team shifts auto-sync + personal events
const FeaturePersonalCalendar = () => (
  <Section paddingY={140}>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'center' }}>
      <div>
        <LandingEyebrow style={{ color: '#B8860B' }}>Feature · 01</LandingEyebrow>
        <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
          팀 근무는 자동으로,<br />내 일정은 함께.
        </h2>
        <p style={{ font: '500 18px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 22, maxWidth: 480 }}>
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
          <ScreenshotImage
            src="assets/screenshots/personal_calendar.png"
            alt="개인 캘린더 화면"
            fallback={<MiniCalendarScreen />}
          />
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
          <ScreenshotImage
            src="assets/screenshots/team_calendar.png"
            alt="팀 캘린더 화면"
            fallback={<MiniHomeScreen shift="day" />}
          />
        </PhoneFrame>
      </div>
      <div>
        <LandingEyebrow style={{ color: '#E07800' }}>Feature · 02</LandingEyebrow>
        <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, color: '#312F23', marginTop: 18, textWrap: 'balance' }}>
          팀은 내가 만들고,<br />근무는 같이 봐요.
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
        <LandingEyebrow style={{ color: '#0061A4' }}>Feature · 04</LandingEyebrow>
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

// Feature 3-A: Schedule auto-generation with strict rules — flagship section
const FeatureScheduleAutoGen = () => {
  const rules = [
    { icon: 'event_busy', label: '연차 · 휴가', sub: '신청한 휴가는 자동 보호' },
    { icon: 'dark_mode', label: '연속 야간 제한', sub: '최대 N일 이상 연속 금지' },
    { icon: 'bedtime', label: '최소 휴식', sub: '근무 사이 시간 보장' },
    { icon: 'groups', label: '시프트별 인원', sub: 'Day 4명 / Night 2명 같은 룰' },
    { icon: 'workspace_premium', label: '숙련도 배치', sub: '신입과 베테랑 균형' },
    { icon: 'block', label: '금기 패턴', sub: 'ND·NE·EOD 같은 패턴 차단' },
  ];
  return (
    <Section paddingY={180}>
      <div style={{ textAlign: 'center', marginBottom: 56 }}>
        <LandingChip icon="auto_awesome" bg="rgba(255,193,7,.18)" color="#6B5300">Feature · 03 — Schedule Generation</LandingChip>
        <h2 style={{
          font: '900 76px/1 var(--font-family)',
          letterSpacing: -2.4, color: '#312F23',
          marginTop: 24, textWrap: 'balance',
          maxWidth: 880, margin: '24px auto 0',
        }}>
          자동 생성, 그런데<br />
          <span style={{
            background: 'linear-gradient(120deg, #FFC107 0%, #FF8C00 60%, #0061A4 110%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
          }}>규칙은 깐깐하게.</span>
        </h2>
        <p style={{
          font: '500 19px/1.6 var(--font-family)',
          color: '#5F5C4D',
          maxWidth: 640, margin: '24px auto 0',
          textWrap: 'balance',
        }}>
          수간호사 혼자 엑셀 붙잡을 일은 없어요.<br />
          연차·연속야간·최소휴식·시프트별 인원 같은 규칙을 세세하게 설정하면, 공평한 근무표를 몇 초 안에 만들어요.
        </p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 60, alignItems: 'center', marginTop: 32 }}>
        {/* Left: rule chips grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          {rules.map(r => (
            <div key={r.label} style={{
              background: '#FFFDF7', borderRadius: 24, padding: 22,
              display: 'flex', gap: 14, alignItems: 'flex-start',
              border: '1px solid rgba(178,173,156,.25)',
              boxShadow: '0 8px 20px rgba(49,47,35,.04)',
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: 16,
                background: '#FFECB3',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0,
              }}>
                <span className="material-symbols-outlined" style={{ fontSize: 22, color: '#B8860B', fontVariationSettings: "'FILL' 1" }}>{r.icon}</span>
              </div>
              <div>
                <div style={{ font: '900 15px/1.2 var(--font-family)', color: '#312F23' }}>{r.label}</div>
                <div style={{ font: '500 13px/1.4 var(--font-family)', color: '#5F5C4D', marginTop: 4 }}>{r.sub}</div>
              </div>
            </div>
          ))}
          <div style={{
            gridColumn: 'span 2',
            background: 'linear-gradient(135deg, #FFD700, #FF8C00)',
            borderRadius: 24, padding: '20px 24px',
            display: 'flex', gap: 14, alignItems: 'center',
            boxShadow: '0 16px 32px rgba(255,140,0,.25)',
            color: '#312F23',
          }}>
            <span className="material-symbols-outlined" style={{ fontSize: 28, fontVariationSettings: "'FILL' 1" }}>bolt</span>
            <div style={{ flex: 1 }}>
              <div style={{ font: '900 15px/1.2 var(--font-family)' }}>몇 초 안에 완성.</div>
              <div style={{ font: '600 13px/1.4 var(--font-family)', marginTop: 4, color: 'rgba(49,47,35,.78)' }}>
                규칙을 바꾸면 즉시 재생성해요.
              </div>
            </div>
          </div>
        </div>
        {/* Right: phone */}
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <PhoneFrame width={340} height={660} tilt={3}>
            <ScreenshotImage
              src="assets/screenshots/schedule_rules.png"
              alt="근무표 생성 규칙 설정 화면"
              fallback={<MiniHomeScreen shift="day" />}
            />
          </PhoneFrame>
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
          font: '900 76px/1 var(--font-family)',
          letterSpacing: -2.4, color: '#FCF6E3',
          marginTop: 24, textWrap: 'balance',
          maxWidth: 880, margin: '24px auto 0',
        }}>
          규칙을 글로 쓰면<br />
          <span style={{ color: '#FFD700' }}>Moniq가 알아들어요.</span>
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
        </div>
        {/* Right: phone */}
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <PhoneFrame width={340} height={660} tilt={-3} shadow="0 40px 80px rgba(0,0,0,.4)">
            <ScreenshotImage
              src="assets/screenshots/custom_rules.png"
              alt="자연어 커스텀 규칙 화면"
              fallback={<MiniHomeScreen shift="night" />}
            />
          </PhoneFrame>
        </div>
      </div>
    </Section>
  );
};

// Per-shift theming section — three phones on a gradient
const FeatureShiftTheming = () => (
  <Section bg="#1F1D14" paddingY={140} style={{ color: '#FCF6E3' }}>
    <div style={{ textAlign: 'center', marginBottom: 72 }}>
      <LandingEyebrow color="#FCF6E3" style={{ opacity: .6 }}>Per-shift theming</LandingEyebrow>
      <h2 style={{ font: '900 60px/1.02 var(--font-family)', letterSpacing: -1.8, marginTop: 18, color: '#FCF6E3', textWrap: 'balance', maxWidth: 760, margin: '18px auto 20px' }}>
        오늘의 근무에 맞춰<br />앱도 옷을 갈아입어요.
      </h2>
      <p style={{ font: '500 17px/1.6 var(--font-family)', color: 'rgba(252,246,227,.75)', maxWidth: 560, margin: '0 auto' }}>
        Day는 따뜻한 크림, Night는 차분한 쿨톤.<br />
        화면 색이 바뀌면 마음의 준비도 함께 돼요.
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
            <ScreenshotImage
              src={`assets/screenshots/shift_${t.shift}.png`}
              alt={`${t.label} 시프트 홈 화면`}
              fallback={<MiniHomeScreen shift={t.shift} />}
            />
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

Object.assign(window, { FeaturePersonalCalendar, FeatureTeamCalendar, FeatureScheduleAutoGen, FeatureCustomRules, FeatureSwap, FeatureShiftTheming });
