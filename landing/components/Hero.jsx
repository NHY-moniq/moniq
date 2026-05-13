// Nav — floating pill at top
const LandingNav = () => (
  <div style={{
    position: 'fixed', top: 64, left: 0, right: 0, zIndex: 50,
    display: 'flex', justifyContent: 'center', pointerEvents: 'none',
  }}>
    <div style={{
      display: 'flex', alignItems: 'center', gap: 8,
      background: 'rgba(255,253,247,.88)', backdropFilter: 'blur(16px)',
      border: '1px solid rgba(178,173,156,.3)',
      borderRadius: 9999, padding: '8px 8px 8px 22px',
      boxShadow: '0 12px 32px rgba(49,47,35,.08)',
      pointerEvents: 'auto',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginRight: 24 }}>
        <div style={{ display: 'flex', gap: -4 }}>
          {['#FFD700','#FF8C00','#0061A4'].map((c,i)=>(
            <div key={i} style={{ width: 14, height: 14, borderRadius: '50%', background: c, marginLeft: i === 0 ? 0 : -4, border: '2px solid #FFFDF7' }} />
          ))}
        </div>
        <div style={{ font: '900 14px/1 var(--font-family)', letterSpacing: -.3 }}>
          <span style={{ color: '#FFC107' }}>ON</span>
          <span style={{ color: '#312F23' }}>OR</span>
          <span style={{ color: '#0061A4' }}>OFF</span>
        </div>
      </div>
      {['기능', '팀 스케줄', '요청하기', 'FAQ'].map(l => (
        <a key={l} href="#" style={{ font: '700 13px/1 var(--font-family)', color: '#5F5C4D', textDecoration: 'none', padding: '10px 14px', borderRadius: 9999 }}>{l}</a>
      ))}
      <LandingButton kind="primary" small>준비 중</LandingButton>
    </div>
  </div>
);

// HERO — left copy, right layered phone mockup with floating mascots
const LandingHero = ({ tweaks }) => {
  const showMascots = tweaks.showMascots;
  const accent = tweaks.accent;
  const accentColor = { day: '#FFD700', evening: '#FF8C00', night: '#0061A4' }[accent];

  return (
    <Section paddingY={160} style={{ paddingTop: 180 }}>
      {/* Background decorative blobs */}
      <div aria-hidden style={{ position: 'absolute', width: 420, height: 420, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,215,0,.35), transparent 70%)', top: -120, left: -140, filter: 'blur(40px)', pointerEvents: 'none' }} />
      <div aria-hidden style={{ position: 'absolute', width: 340, height: 340, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,140,0,.28), transparent 70%)', bottom: -60, right: '40%', filter: 'blur(40px)', pointerEvents: 'none' }} />

      <div className="hero-grid">
        {/* LEFT: copy */}
        <div style={{ position: 'relative' }}>
          <LandingChip icon="medical_services" bg={`${accentColor}30`} color="#6B5300">FOR NURSES · 간호사 전용</LandingChip>
          <h1 className="hero-headline" style={{
            font: '900 88px/0.98 var(--font-family)',
            letterSpacing: -2.4, color: '#312F23',
            marginTop: 28, marginBottom: 28, textWrap: 'balance',
          }}>
            근무표,<br />
            <span style={{ color: '#FFC107' }}>낮</span>도 <span style={{ color: '#FF8C00' }}>저녁</span>도<br />
            <span style={{ color: '#0061A4' }}>밤</span>도 한눈에.
          </h1>
          <p style={{ font: '500 19px/1.6 var(--font-family)', color: '#5F5C4D', maxWidth: 480, marginBottom: 36 }}>
            OnorOff는 교대근무자를 위한 근무표 관리 앱이에요.<br />
            내 스케줄을 깔끔하게 보고,<br />
            팀 근무표는 규칙 기반으로 자동 생성,<br />
            교대·변경 요청은 한 번의 탭으로 끝내세요.
          </p>
          <ComingSoonButtons kind="primary" />
          <div style={{ display: 'flex', gap: 16, marginTop: 36, alignItems: 'center', flexWrap: 'wrap' }}>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: 8,
              background: 'rgba(255,193,7,.18)', color: '#6B5300',
              padding: '10px 16px', borderRadius: 9999,
              font: '800 12px/1 var(--font-family)', letterSpacing: 1.2, textTransform: 'uppercase',
            }}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#FFC107', boxShadow: '0 0 0 4px rgba(255,193,7,.25)' }} />
              사전 신청 열려있어요
            </div>
            <div style={{ font: '600 13px/1.5 var(--font-family)', color: '#5F5C4D' }}>
              규칙 기반 자동 생성 · 자연어 커스텀 룰 · AI 공평성 리포트
            </div>
          </div>
        </div>

        {/* RIGHT: phone + floating mascots */}
        <div className="hero-phone-col" style={{ position: 'relative', display: 'flex', justifyContent: 'center', alignItems: 'center', height: 640 }}>
          {showMascots && <>
            <Mascot color="yellow" size={150} style={{ position: 'absolute', top: 20, left: -10, filter: 'drop-shadow(0 20px 28px rgba(255,215,0,.35))', animation: 'float1 6s ease-in-out infinite' }} />
            <Mascot color="orange" size={110} style={{ position: 'absolute', bottom: 60, left: 10, filter: 'drop-shadow(0 16px 24px rgba(255,140,0,.3))', animation: 'float2 7s ease-in-out infinite' }} />
            <Mascot color="blue" size={130} style={{ position: 'absolute', top: 80, right: -20, filter: 'drop-shadow(0 18px 26px rgba(0,97,164,.3))', animation: 'float3 8s ease-in-out infinite' }} />
          </>}
          <PhoneFrame width={320} height={620} tilt={-3} shadow="0 40px 80px rgba(49,47,35,.2)">
            <MiniHomeScreen shift={accent} />
          </PhoneFrame>
        </div>
      </div>

      <style>{`
        @keyframes float1 { 0%,100%{transform:translateY(0) rotate(-6deg)} 50%{transform:translateY(-18px) rotate(4deg)} }
        @keyframes float2 { 0%,100%{transform:translateY(0) rotate(6deg)} 50%{transform:translateY(-14px) rotate(-4deg)} }
        @keyframes float3 { 0%,100%{transform:translateY(0) rotate(4deg)} 50%{transform:translateY(-22px) rotate(-6deg)} }
      `}</style>
    </Section>
  );
};

Object.assign(window, { LandingNav, LandingHero });
