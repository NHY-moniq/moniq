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
          <p style={{ font: '500 19px/1.55 var(--font-family)', color: '#5F5C4D', maxWidth: 480, marginBottom: 36 }}>
            Moniq는 교대근무자를 위한 근무표 관리 앱이에요.
            내 스케줄을 깔끔하게 보고, 팀 근무표는 자동으로 만들고,
            교대·변경 요청은 한 번의 탭으로 끝내세요.
          </p>
          <ComingSoonButtons kind="primary" />
          <div style={{ display: 'flex', gap: 28, marginTop: 48, alignItems: 'center' }}>
            <div>
              <div style={{ font: '900 28px/1 var(--font-family)', color: '#312F23', letterSpacing: -.5 }}>4.8<span style={{ color: '#FFC107' }}>★</span></div>
              <div style={{ font: '700 10px/1 var(--font-family)', letterSpacing: 1.6, textTransform: 'uppercase', color: '#7A7768', marginTop: 6 }}>App Store Rating</div>
            </div>
            <div style={{ width: 1, height: 36, background: 'rgba(49,47,35,.12)' }} />
            <div>
              <div style={{ font: '900 28px/1 var(--font-family)', color: '#312F23', letterSpacing: -.5 }}>12,400+</div>
              <div style={{ font: '700 10px/1 var(--font-family)', letterSpacing: 1.6, textTransform: 'uppercase', color: '#7A7768', marginTop: 6 }}>Nurses On-Shift</div>
            </div>
            <div style={{ width: 1, height: 36, background: 'rgba(49,47,35,.12)' }} />
            <div>
              <div style={{ font: '900 28px/1 var(--font-family)', color: '#312F23', letterSpacing: -.5 }}>320+</div>
              <div style={{ font: '700 10px/1 var(--font-family)', letterSpacing: 1.6, textTransform: 'uppercase', color: '#7A7768', marginTop: 6 }}>Hospital Units</div>
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

// Three characters intro strip
const CharactersStrip = () => (
  <Section bg="#312F23" paddingY={100} style={{ color: '#FCF6E3' }}>
    <div style={{ textAlign: 'center', marginBottom: 64 }}>
      <LandingEyebrow color="#FCF6E3" style={{ opacity: .6 }}>Meet the team</LandingEyebrow>
      <h2 style={{ font: '900 56px/1.05 var(--font-family)', letterSpacing: -1.4, marginTop: 14, color: '#FCF6E3', textWrap: 'balance' }}>
        근무는 셋, 캐릭터도 셋.
      </h2>
    </div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 20 }}>
      {[
        { key: 'yellow', name: 'The Yellow One', shift: 'Day Shift', code: 'D', time: '08:00 — 16:00', color: '#FFD700', on: '#453900' },
        { key: 'orange', name: 'The Orange One', shift: 'Evening Shift', code: 'E', time: '16:00 — 00:00', color: '#FF8C00', on: '#ffffff' },
        { key: 'blue', name: 'The Blue One', shift: 'Night Shift', code: 'N', time: '00:00 — 08:00', color: '#0061A4', on: '#ffffff' },
      ].map(c => (
        <div key={c.key} style={{
          position: 'relative', overflow: 'hidden',
          background: `linear-gradient(160deg, ${c.color}, ${c.color}dd)`,
          borderRadius: 36, padding: '36px 32px 32px', color: c.on,
          minHeight: 300,
          boxShadow: `0 18px 40px ${c.color}55`,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <LandingEyebrow color={c.on} style={{ opacity: .75 }}>{c.code} · {c.time}</LandingEyebrow>
            <div style={{ width: 32, height: 32, borderRadius: 9999, background: 'rgba(255,255,255,.3)', backdropFilter: 'blur(10px)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span style={{ font: '900 14px/1 var(--font-family)' }}>{c.code}</span>
            </div>
          </div>
          <div style={{ font: '900 30px/1.05 var(--font-family)', letterSpacing: -.6, marginTop: 10, position: 'relative', zIndex: 2 }}>{c.name}</div>
          <div style={{ font: '600 15px/1.35 var(--font-family)', opacity: .85, marginTop: 6, position: 'relative', zIndex: 2 }}>{c.shift}</div>
          <img src={`assets/${c.key}.png`} style={{ position: 'absolute', right: -30, bottom: -40, width: 220, height: 220, opacity: .9 }} />
        </div>
      ))}
    </div>
  </Section>
);

Object.assign(window, { LandingNav, LandingHero, CharactersStrip });
