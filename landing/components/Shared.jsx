// Shared primitives for the landing page
const LandingEyebrow = ({ children, color = '#7A7768', style }) => (
  <div style={{
    font: '800 11px/1 var(--font-family)',
    letterSpacing: 1.8,
    textTransform: 'uppercase',
    color,
    ...style,
  }}>{children}</div>
);

const LandingChip = ({ icon, children, bg = 'rgba(255,193,7,.18)', color = '#6B5300' }) => (
  <div style={{
    display: 'inline-flex', alignItems: 'center', gap: 6,
    background: bg, color,
    padding: '6px 12px', borderRadius: 9999,
    font: '700 11px/1 var(--font-family)', letterSpacing: 1.2, textTransform: 'uppercase',
  }}>
    {icon && <span className="material-symbols-outlined" style={{ fontSize: 14, fontVariationSettings: "'FILL' 1" }}>{icon}</span>}
    {children}
  </div>
);

const LandingButton = ({ children, kind = 'primary', icon, onClick, small }) => {
  const kinds = {
    primary:   { background: '#312F23', color: '#FCF6E3', boxShadow: '0 10px 24px rgba(49,47,35,.25)' },
    yellow:    { background: '#FFC107', color: '#453900', boxShadow: '0 10px 24px rgba(255,193,7,.4)' },
    cream:     { background: '#FFFDF7', color: '#312F23', border: '1.5px solid rgba(49,47,35,.1)' },
    ghost:     { background: 'transparent', color: '#312F23', border: '1.5px solid rgba(49,47,35,.15)' },
  };
  return (
    <button onClick={onClick} style={{
      ...kinds[kind],
      height: small ? 44 : 56,
      padding: small ? '0 20px' : '0 28px',
      borderRadius: 9999, border: kinds[kind].border || 'none',
      font: `800 ${small ? 13 : 15}px/1 var(--font-family)`, letterSpacing: .2,
      display: 'inline-flex', alignItems: 'center', gap: 8, cursor: 'pointer',
      transition: 'transform .18s cubic-bezier(0.34, 1.56, 0.64, 1)',
    }}
      onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.03)'}
      onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
    >
      {children}
      {icon && <span className="material-symbols-outlined" style={{ fontSize: small ? 16 : 18, fontVariationSettings: "'FILL' 1" }}>{icon}</span>}
    </button>
  );
};

const LandingCard = ({ children, padding = 32, radius = 32, bg = '#FFFDF7', style, hover }) => (
  <div style={{
    background: bg,
    borderRadius: radius,
    padding,
    border: '1px solid rgba(178,173,156,.3)',
    boxShadow: '0 12px 32px rgba(49,47,35,.06)',
    transition: 'transform .3s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow .3s',
    ...style,
  }}
    onMouseEnter={hover ? e => {
      e.currentTarget.style.transform = 'translateY(-4px)';
      e.currentTarget.style.boxShadow = '0 24px 48px rgba(49,47,35,.10)';
    } : undefined}
    onMouseLeave={hover ? e => {
      e.currentTarget.style.transform = 'translateY(0)';
      e.currentTarget.style.boxShadow = '0 12px 32px rgba(49,47,35,.06)';
    } : undefined}
  >{children}</div>
);

// Phone frame for embedding UI mocks
const PhoneFrame = ({ children, bg = '#FCF6E3', width = 320, height = 640, tilt = 0, shadow = '0 30px 60px rgba(49,47,35,.22)' }) => (
  <div style={{
    width, height, background: bg,
    borderRadius: 44, padding: 8,
    border: '9px solid #1a1a1a',
    boxShadow: shadow,
    overflow: 'hidden', position: 'relative',
    transform: tilt ? `rotate(${tilt}deg)` : 'none',
    flexShrink: 0,
  }}>
    <div style={{
      position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
      width: 96, height: 24, background: '#1a1a1a', borderRadius: 999, zIndex: 2,
    }} />
    <div style={{
      width: '100%', height: '100%',
      background: bg, borderRadius: 36, overflow: 'hidden', position: 'relative',
    }}>
      {children}
    </div>
  </div>
);

// Section wrapper
const Section = ({ children, bg = 'transparent', paddingY = 120, style }) => (
  <section style={{
    background: bg, padding: `${paddingY}px 40px`, position: 'relative', overflow: 'hidden', ...style,
  }}>
    <div style={{ maxWidth: 1280, margin: '0 auto', position: 'relative' }}>{children}</div>
  </section>
);

// Mascot image
const Mascot = ({ color = 'yellow', size = 80, style }) => (
  <img src={`assets/${color}.png`} alt="" style={{
    width: size, height: size, objectFit: 'contain', ...style,
  }} />
);

// Pre-launch banner — shows once at top, dismissable
const PreLaunchBanner = () => {
  const [show, setShow] = React.useState(true);
  if (!show) return null;
  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, right: 0, zIndex: 60,
      background: '#312F23', color: '#FCF6E3',
      padding: '10px 20px', display: 'flex', alignItems: 'center',
      justifyContent: 'center', gap: 12, flexWrap: 'wrap',
      font: '600 12px/1.4 var(--font-family)',
    }}>
      <span style={{
        display: 'inline-flex', alignItems: 'center', gap: 6,
        background: 'rgba(255,215,0,.18)', color: '#FFD700',
        padding: '3px 10px', borderRadius: 9999,
        font: '800 10px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase',
      }}>
        <span className="material-symbols-outlined" style={{ fontSize: 12, fontVariationSettings: "'FILL' 1" }}>info</span>
        Pre-launch preview
      </span>
      <span style={{ color: 'rgba(252,246,227,.85)' }}>
        모든 별점·후기·통계·병원 로고는 디자인 시안용 예시예요. 출시 후 실데이터로 교체될 예정.
      </span>
      <button onClick={() => setShow(false)} aria-label="배너 닫기" style={{
        marginLeft: 8, background: 'transparent', border: 'none', cursor: 'pointer',
        color: 'rgba(252,246,227,.6)', padding: 4, display: 'flex', alignItems: 'center',
      }}>
        <span className="material-symbols-outlined" style={{ fontSize: 16 }}>close</span>
      </button>
    </div>
  );
};

// Coming-soon download CTA — replaces App Store / Play Store buttons until launch
const ComingSoonButtons = ({ kind = 'cream' }) => {
  const [tip, setTip] = React.useState(null); // 'ios' | 'android' | null
  const onTap = (which) => {
    setTip(which);
    setTimeout(() => setTip(null), 1800);
  };
  const wrap = { display: 'inline-flex', flexDirection: 'column', alignItems: 'flex-start', gap: 8 };
  const tipBubble = (label) => (
    <div style={{
      background: '#312F23', color: '#FCF6E3',
      padding: '8px 14px', borderRadius: 9999,
      font: '700 12px/1 var(--font-family)',
      boxShadow: '0 8px 20px rgba(49,47,35,.25)',
      animation: 'fadeIn .18s ease-out',
    }}>
      <span className="material-symbols-outlined" style={{ fontSize: 14, fontVariationSettings: "'FILL' 1", marginRight: 6, verticalAlign: -2 }}>schedule</span>
      {label}
    </div>
  );
  const btnBase = (k) => ({
    primary: { background: '#312F23', color: '#FCF6E3', boxShadow: '0 10px 24px rgba(49,47,35,.25)' },
    cream:   { background: '#FFFDF7', color: '#312F23', border: '1.5px solid rgba(49,47,35,.1)' },
  }[k]);
  const renderBtn = (which, label, icon) => (
    <div style={wrap}>
      <button onClick={() => onTap(which)} style={{
        ...btnBase(kind === 'primary' && which === 'ios' ? 'primary' : 'cream'),
        height: 56, padding: '0 24px', borderRadius: 9999,
        border: btnBase(kind === 'primary' && which === 'ios' ? 'primary' : 'cream').border || 'none',
        font: '800 15px/1 var(--font-family)', letterSpacing: .2,
        display: 'inline-flex', alignItems: 'center', gap: 10, cursor: 'pointer',
        position: 'relative',
      }}>
        <span className="material-symbols-outlined" style={{ fontSize: 18, fontVariationSettings: "'FILL' 1" }}>{icon}</span>
        <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 2 }}>
          <span style={{ font: '700 9px/1 var(--font-family)', letterSpacing: 1.2, opacity: .65 }}>COMING SOON</span>
          <span>{label}</span>
        </span>
      </button>
      {tip === which && tipBubble('곧 출시돼요 · 잠시만 기다려주세요')}
    </div>
  );
  return (
    <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', flexWrap: 'wrap' }}>
      {renderBtn('ios', 'App Store', 'apple')}
      {renderBtn('android', 'Google Play', 'android')}
      <style>{`@keyframes fadeIn { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }`}</style>
    </div>
  );
};

Object.assign(window, { LandingEyebrow, LandingChip, LandingButton, LandingCard, PhoneFrame, Section, Mascot, PreLaunchBanner, ComingSoonButtons });
