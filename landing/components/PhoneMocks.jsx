// Phone-screen mocks for embedding inside <PhoneFrame>
// Self-contained — don't depend on the app UI kit

const SHIFTS_LANDING = {
  day:     { bg:'#FCF6E3', card:'#FFD700', on:'#453900', accent:'#B8860B', name:'Day Shift',    time:'08:00 — 16:00', mascot:'assets/yellow.png', glow:'0 15px 30px rgba(255,215,0,.35)' },
  evening: { bg:'#FCF6E3', card:'#FF8C00', on:'#ffffff', accent:'#E07800', name:'Evening Shift',time:'16:00 — 00:00', mascot:'assets/orange.png', glow:'0 15px 30px rgba(255,140,0,.3)' },
  night:   { bg:'#F8F9FF', card:'#0061A4', on:'#ffffff', accent:'#0061A4', name:'Night Shift',  time:'00:00 — 08:00', mascot:'assets/blue.png',   glow:'0 15px 30px rgba(0,97,164,.3)' },
  off:     { bg:'#FCF6E3', card:'#A0AEC0', on:'#ffffff', accent:'#718096', name:'OFF',          time:'휴식',          mascot:'assets/off.png',    glow:'0 8px 20px rgba(160,174,192,.25)' },
};

const MiniStatusBar = ({ dark }) => (
  <div style={{ height: 34, display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 20px', font: '700 12px/1 var(--font-family)', color: dark ? '#fff' : '#312F23' }}>
    <span>9:41</span>
    <span style={{ display: 'inline-flex', gap: 3 }}>
      <span className="material-symbols-outlined" style={{ fontSize: 13 }}>signal_cellular_alt</span>
      <span className="material-symbols-outlined" style={{ fontSize: 13 }}>wifi</span>
      <span className="material-symbols-outlined" style={{ fontSize: 13 }}>battery_full</span>
    </span>
  </div>
);

const MiniTopBar = ({ title = 'Joy 님의 일정', ring = '#FFC107' }) => (
  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '4px 18px 14px' }}>
    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
      <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#EEE8D3', border: `2px solid ${ring}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <span className="material-symbols-outlined" style={{ fontSize: 18, color: '#5F5C4D' }}>person</span>
      </div>
      <div>
        <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FF8F00' }}>ONOROFF</div>
        <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>{title}</div>
      </div>
    </div>
    <span className="material-symbols-outlined" style={{ color: '#5F5C4D', fontSize: 20 }}>notifications</span>
  </div>
);

const MiniGlassBadge = ({ label, on }) => (
  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: 'rgba(255,255,255,.35)', backdropFilter: 'blur(10px)', padding: '4px 11px', borderRadius: 9999, font: '800 8px/1 var(--font-family)', letterSpacing: 1.3, textTransform: 'uppercase', color: on }}>
    <span style={{ width: 5, height: 5, borderRadius: '50%', background: on }} />{label}
  </div>
);

const MiniGlassChip = ({ icon, label, on }) => (
  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, background: 'rgba(255,255,255,.28)', backdropFilter: 'blur(8px)', padding: '5px 12px', borderRadius: 9999, border: '1px solid rgba(255,255,255,.22)', font: '700 10px/1 var(--font-family)', color: on }}>
    <span className="material-symbols-outlined" style={{ fontSize: 11, fontVariationSettings: "'FILL' 1" }}>{icon}</span>{label}
  </div>
);

const MiniBottomNav = ({ active = 'home', dark }) => {
  const bg = dark ? 'rgba(30,30,30,.95)' : 'rgba(255,255,255,.95)';
  const muted = dark ? '#B0B0B0' : '#5F5C4D';
  const Item = ({ id, icon }) => {
    const on = id === active;
    return (
      <div style={{ padding: on ? '7px 14px' : '5px 10px', borderRadius: 9999, background: on ? '#FFC107' : 'transparent', color: on ? '#453900' : muted, transform: on ? 'scale(1.08)' : 'none' }}>
        <span className="material-symbols-outlined" style={{ fontSize: 17, fontVariationSettings: on ? "'FILL' 1" : "'FILL' 0" }}>{icon}</span>
      </div>
    );
  };
  return (
    <div style={{ position: 'absolute', bottom: 14, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
      <div style={{ display: 'flex', gap: 3, background: bg, backdropFilter: 'blur(20px)', padding: 5, borderRadius: 9999, boxShadow: '0 10px 24px rgba(49,47,35,.18)' }}>
        <Item id="home" icon="home" /><Item id="teams" icon="group" /><Item id="settings" icon="settings" />
      </div>
    </div>
  );
};

// Home screen in a phone — exact recreation, scaled for landing preview
const MiniHomeScreen = ({ shift = 'day' }) => {
  const s = SHIFTS_LANDING[shift];
  const dark = shift === 'night';
  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: s.bg }}>
      <MiniStatusBar dark={dark} />
      <MiniTopBar ring={s.card} />
      <div style={{ padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ font: '500 10px/1 var(--font-family)', color: dark ? '#B0B0B0' : '#5F5C4D' }}>
          {shift === 'night' ? '오늘은 Night Shift · 천천히 준비하세요' : shift === 'off' ? '오늘은 쉬는 날이에요' : '오늘도 파이팅!'}
        </div>
        <div style={{ position: 'relative', overflow: 'hidden', borderRadius: 24, padding: 16, minHeight: 150, background: `linear-gradient(135deg, ${s.card}, ${s.card}e0)`, color: s.on, boxShadow: s.glow }}>
          <img src={s.mascot} style={{ position: 'absolute', right: -14, bottom: -14, width: 130, height: 130, opacity: .28, transform: 'rotate(12deg)' }} />
          <div style={{ position: 'relative' }}>
            <MiniGlassBadge label="Active Shift" on={s.on} />
            <div style={{ font: '900 22px/1.1 var(--font-family)', letterSpacing: -.4, marginTop: 10 }}>{s.name}</div>
            <div style={{ font: '600 12px/1.2 var(--font-family)', opacity: .85, marginTop: 2 }}>{s.time}</div>
            <div style={{ display: 'flex', gap: 4, marginTop: 10, flexWrap: 'wrap' }}>
              <MiniGlassChip icon="medical_services" label="Unit 4" on={s.on} />
              <MiniGlassChip icon="assignment_ind" label="Head" on={s.on} />
            </div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <div style={{ flex: 1, background: dark ? '#1E1E1E' : '#FFFDF7', borderRadius: 18, padding: 12 }}>
            <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase', color: dark ? '#B0B0B0' : '#7A7768' }}>Weekly</div>
            <div style={{ font: '900 20px/1 var(--font-family)', color: '#FF8F00', marginTop: 6 }}>32.5<span style={{ font: '500 9px/1 var(--font-family)', marginLeft: 3, color: dark ? '#B0B0B0' : '#5F5C4D' }}>hrs</span></div>
          </div>
          <div style={{ flex: 1, background: dark ? '#1E1E1E' : '#FFFDF7', borderRadius: 18, padding: 12 }}>
            <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase', color: dark ? '#B0B0B0' : '#7A7768' }}>Team</div>
            <div style={{ display: 'flex', marginTop: 6 }}>
              {['#FFC107','#FF8F00','#2196F3'].map((c,i)=>(<div key={i} style={{ width: 22, height: 22, borderRadius: '50%', background: c, border: `2px solid ${dark ? '#1E1E1E' : '#FFFDF7'}`, marginLeft: i === 0 ? 0 : -6 }} />))}
              <div style={{ width: 22, height: 22, borderRadius: '50%', background: dark ? '#282828' : '#F7F1DC', border: `2px solid ${dark ? '#1E1E1E' : '#FFFDF7'}`, marginLeft: -6, display: 'flex', alignItems: 'center', justifyContent: 'center', font: '800 8px/1 var(--font-family)', color: dark ? '#B0B0B0' : '#5F5C4D' }}>+4</div>
            </div>
          </div>
        </div>
      </div>
      <MiniBottomNav active="home" dark={dark} />
    </div>
  );
};

// Mini calendar screen preview
const MiniCalendarScreen = () => {
  const days = ['M','T','W','T','F','S','S'];
  // 6 weeks grid of shift codes. d/e/n/o/null
  const grid = [
    ['d','d','e','e','n','n','o'],
    ['o','d','d','e','e','n','n'],
    ['o','o','d','d','e','e','n'],
    ['n','o','o','d','d','e','e'],
    ['n','n','o','o','d','d','e'],
    ['e','n','n','o','o','d','d'],
  ];
  const color = { d: '#FFD700', e: '#FF8C00', n: '#0061A4', o: '#A0AEC0' };
  return (
    <div style={{ height: '100%', position: 'relative', background: '#FCF6E3' }}>
      <MiniStatusBar />
      <MiniTopBar title="내 캘린더" />
      <div style={{ padding: '0 14px' }}>
        <div style={{ background: '#FFFDF7', borderRadius: 22, padding: 14, boxShadow: '0 10px 24px rgba(49,47,35,.05)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <div style={{ font: '900 16px/1 var(--font-family)', color: '#312F23' }}>2025.10</div>
            <div style={{ display: 'flex', gap: 8 }}>
              {['#FFD700','#FF8C00','#0061A4'].map((c,i)=>(
                <div key={i} style={{ display: 'flex', gap: 3, alignItems: 'center' }}>
                  <span style={{ width: 6, height: 6, borderRadius: '50%', background: c }} />
                  <span style={{ font: '800 7px/1 var(--font-family)', letterSpacing: 1, textTransform: 'uppercase', color: '#7A7768' }}>{['D','E','N'][i]}</span>
                </div>
              ))}
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 4, marginBottom: 6 }}>
            {days.map((d,i)=>(<div key={i} style={{ textAlign: 'center', font: '800 8px/1 var(--font-family)', letterSpacing: 1.2, color: '#7A7768' }}>{d}</div>))}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 4 }}>
            {grid.flatMap((row, ri) => row.map((code, ci) => {
              const day = ri * 7 + ci + 1;
              const isToday = day === 14;
              return (
                <div key={`${ri}-${ci}`} style={{ aspectRatio: '1', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2, background: isToday ? '#FFC107' : 'transparent', borderRadius: 10, boxShadow: isToday ? '0 6px 14px rgba(255,193,7,.3)' : 'none' }}>
                  <div style={{ font: `${isToday ? 900 : 600} 11px/1 var(--font-family)`, color: isToday ? '#453900' : '#312F23' }}>{day}</div>
                  <span style={{ width: 4, height: 4, borderRadius: '50%', background: color[code] }} />
                </div>
              );
            }))}
          </div>
        </div>
      </div>
      <MiniBottomNav active="home" />
    </div>
  );
};

// Mini request / swap screen preview
const MiniRequestScreen = () => (
  <div style={{ height: '100%', position: 'relative', background: '#FCF6E3' }}>
    <MiniStatusBar />
    <MiniTopBar title="근무 변경 요청" />
    <div style={{ padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ background: '#FFFDF7', borderRadius: 20, padding: 14 }}>
        <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase', color: '#7A7768' }}>FROM</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 8 }}>
          <div style={{ width: 40, height: 40, borderRadius: 12, background: '#FFD700', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#453900' }}>
            <div style={{ font: '900 12px/1 var(--font-family)' }}>OCT</div>
            <div style={{ font: '900 14px/1 var(--font-family)' }}>15</div>
          </div>
          <div>
            <div style={{ font: '800 13px/1.2 var(--font-family)', color: '#312F23' }}>Day Shift</div>
            <div style={{ font: '500 10px/1.2 var(--font-family)', color: '#5F5C4D' }}>08:00 — 16:00</div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', color: '#7A7768' }}>
        <span className="material-symbols-outlined" style={{ fontSize: 22 }}>swap_vert</span>
      </div>
      <div style={{ background: '#FFFDF7', borderRadius: 20, padding: 14 }}>
        <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase', color: '#7A7768' }}>TO</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 8 }}>
          <div style={{ width: 40, height: 40, borderRadius: 12, background: '#A0AEC0', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
            <div style={{ font: '900 12px/1 var(--font-family)' }}>OCT</div>
            <div style={{ font: '900 14px/1 var(--font-family)' }}>17</div>
          </div>
          <div>
            <div style={{ font: '800 13px/1.2 var(--font-family)', color: '#312F23' }}>OFF</div>
            <div style={{ font: '500 10px/1.2 var(--font-family)', color: '#5F5C4D' }}>Soojin과 교대</div>
          </div>
        </div>
      </div>
      <div style={{ background: '#FFFDF7', borderRadius: 20, padding: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
        <span className="material-symbols-outlined" style={{ color: '#38A169', fontSize: 18, fontVariationSettings: "'FILL' 1" }}>check_circle</span>
        <div>
          <div style={{ font: '800 11px/1.2 var(--font-family)', color: '#312F23' }}>수간호사 승인됨</div>
          <div style={{ font: '500 9px/1.2 var(--font-family)', color: '#5F5C4D' }}>2분 전</div>
        </div>
      </div>
      <button style={{ marginTop: 4, height: 40, borderRadius: 9999, border: 'none', background: '#FFC107', color: '#453900', font: '800 12px/1 var(--font-family)', letterSpacing: .2, boxShadow: '0 6px 16px rgba(255,193,7,.35)' }}>
        Request change
      </button>
    </div>
    <MiniBottomNav active="home" />
  </div>
);

Object.assign(window, { SHIFTS_LANDING, MiniStatusBar, MiniTopBar, MiniHomeScreen, MiniCalendarScreen, MiniRequestScreen });
