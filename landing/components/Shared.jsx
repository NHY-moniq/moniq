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

// Screenshot inside a PhoneFrame — tries the PNG first, falls back to a mock
// widget if the file is missing. Lets the page render before real screenshots
// land in landing/assets/screenshots/.
const ScreenshotImage = ({ src, alt = '', fallback = null, fit = 'cover' }) => {
  const [errored, setErrored] = React.useState(false);
  if (errored || !src) return fallback;
  return (
    <img
      src={src}
      alt={alt}
      onError={() => setErrored(true)}
      style={{
        width: '100%',
        height: '100%',
        objectFit: fit,
        display: 'block',
      }}
    />
  );
};

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

// ─────────────────────────────────────────────
// Layered-mockup primitives (듀팅식 멀티스크린 강조)
// ─────────────────────────────────────────────

// FloatingPanel — 메인 비주얼 위/주변에 독립 UI 패널 목업을 절대 위치로 띄움.
// 듀팅의 "제약 조건 / 근무 형태 설정 패널이 그리드 위에 겹쳐 떠 있는" 표현.
// 부모는 position: relative 여야 함.
const FloatingPanel = ({
  children, width = 280,
  top, left, right, bottom,
  tilt = 0, z = 3, shadow, bg = '#FFFDF7',
}) => (
  <div style={{
    position: 'absolute', width,
    top, left, right, bottom,
    transform: tilt ? `rotate(${tilt}deg)` : undefined,
    zIndex: z,
    background: bg,
    borderRadius: 22,
    border: '1px solid rgba(178,173,156,.3)',
    boxShadow: shadow || '0 28px 56px rgba(49,47,35,.18)',
    overflow: 'hidden',
  }}>
    {children}
  </div>
);

// PhoneStack — 폰 목업 여러 개를 계단식으로 겹쳐 배치.
// items: [{ mock, scale, tilt, z, dim, shadow, step }]
//   - mock: <MiniXScreen/>  - scale/tilt: 크기·기울기  - z: 레이어 순서
//   - dim: true면 살짝 채도↓ (뒤폰)  - step: 폰 하단 단계 라벨
const PhoneStack = ({ items = [], overlap = 0.5, width = 270, height = 540 }) => (
  <div className="phone-stack" style={{
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    position: 'relative',
  }}>
    {items.map((it, i) => (
      <div key={i} className="phone-stack-item" style={{
        marginLeft: i === 0 ? 0 : -Math.round(width * overlap),
        zIndex: it.z ?? (i + 1),
        transform: `scale(${it.scale ?? 1})${it.tilt ? ` rotate(${it.tilt}deg)` : ''}`,
        filter: it.dim ? 'saturate(.9) brightness(.99)' : undefined,
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12,
      }}>
        <PhoneFrame width={width} height={height} shadow={it.shadow}>
          {it.mock}
        </PhoneFrame>
        {it.step && (
          <div style={{
            font: '800 11px/1 var(--font-family)', color: '#5F5C4D',
            background: '#FFFDF7', border: '1px solid rgba(178,173,156,.3)',
            padding: '6px 12px', borderRadius: 9999, whiteSpace: 'nowrap',
            boxShadow: '0 6px 16px rgba(49,47,35,.06)',
          }}>{it.step}</div>
        )}
      </div>
    ))}
  </div>
);

// LegendChips — 색상 범례 칩 행. 듀팅의 "잘못된 근무 / 신청 반영 / 미반영" 범례.
// items: [{ color, label, dotColor }]
const LegendChips = ({ items = [], style }) => (
  <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', justifyContent: 'center', ...style }}>
    {items.map((it, i) => (
      <div key={i} style={{
        display: 'inline-flex', alignItems: 'center', gap: 7,
        background: '#FFFDF7', border: '1px solid rgba(178,173,156,.3)',
        padding: '8px 14px', borderRadius: 12,
        font: '700 12px/1 var(--font-family)', color: '#312F23',
        boxShadow: '0 6px 16px rgba(49,47,35,.06)',
      }}>
        <span style={{
          width: 16, height: 16, borderRadius: 5, background: it.color,
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {it.dotColor && <span style={{ width: 6, height: 6, borderRadius: '50%', background: it.dotColor }} />}
        </span>
        {it.label}
      </div>
    ))}
  </div>
);

Object.assign(window, { LandingEyebrow, LandingChip, LandingButton, LandingCard, PhoneFrame, Section, Mascot, PreLaunchBanner, ComingSoonButtons, ScreenshotImage, FloatingPanel, PhoneStack, LegendChips });
