// Phone-screen mocks for embedding inside <PhoneFrame>
// Self-contained — don't depend on the app UI kit

const SHIFTS_LANDING = {
  day:     { bg:'#FCF6E3', card:'#FFD700', on:'#453900', accent:'#B8860B', name:'Day Shift',    time:'08:00 — 16:00', mascot:'assets/yellow.png', glow:'0 15px 30px rgba(255,215,0,.35)' },
  evening: { bg:'#FCF6E3', card:'#FF8C00', on:'#ffffff', accent:'#E07800', name:'Evening Shift',time:'16:00 — 00:00', mascot:'assets/orange.png', glow:'0 15px 30px rgba(255,140,0,.3)' },
  night:   { bg:'#F8F9FF', card:'#0061A4', on:'#ffffff', accent:'#0061A4', name:'Night Shift',  time:'00:00 — 08:00', mascot:'assets/blue.png',   glow:'0 15px 30px rgba(0,97,164,.3)' },
  off:     { bg:'#FCF6E3', card:'#A0AEC0', on:'#ffffff', accent:'#718096', name:'OFF',          time:'휴식',          mascot:'assets/off.png',    glow:'0 8px 20px rgba(160,174,192,.25)' },
};

// Brand shift colors used across all mocks — pulled from AppColors
const SHIFT_COLORS = {
  D: '#FFC107', // brandYellow / Day
  E: '#FF8C00', // brandOrange / Evening
  N: '#0061A4', // brandBlue / Night
  O: '#A0AEC0', // off
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

const MiniTopBar = ({ title = '이간호 님의 일정', ring = '#FFC107', eyebrow = 'ONOROFF' }) => (
  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '4px 18px 14px' }}>
    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
      <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#EEE8D3', border: `2px solid ${ring}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <span className="material-symbols-outlined" style={{ fontSize: 18, color: '#5F5C4D' }}>person</span>
      </div>
      <div>
        <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FF8F00' }}>{eyebrow}</div>
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
        <Item id="home" icon="home" /><Item id="calendar" icon="calendar_month" /><Item id="teams" icon="group" /><Item id="settings" icon="settings" />
      </div>
    </div>
  );
};

// Home screen in a phone — mirrors lib/presentation/screens/home/home_body.dart
// ActiveShift 카드 → 좌(Next Off + 인수인계) / 우(On-Shift Now) → 팀 소식
const MiniHomeScreen = ({ shift = 'day' }) => {
  const s = SHIFTS_LANDING[shift];
  const ink = '#312F23';
  const muted = '#7A7768';
  const tintBg = s.card + '14';      // shift 색 8% 틴트 — 실제 앱 카드 톤
  const tintBorder = s.card + '24';
  const iconTile = s.card + '2E';
  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: s.bg }}>
      <MiniStatusBar />
      <MiniTopBar ring={s.card} />
      <div style={{ padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 9 }}>
        {/* Active Shift card */}
        <div style={{ position: 'relative', overflow: 'hidden', borderRadius: 22, padding: 15, minHeight: 130, background: `linear-gradient(135deg, ${s.card}, ${s.card}e0)`, color: s.on, boxShadow: s.glow }}>
          <img src={s.mascot} style={{ position: 'absolute', right: -14, bottom: -14, width: 116, height: 116, opacity: .26, transform: 'rotate(12deg)' }} />
          <div style={{ position: 'relative' }}>
            <MiniGlassBadge label={shift === 'off' ? 'No Shift' : 'Active Shift'} on={s.on} />
            <div style={{ font: '900 24px/1.1 var(--font-family)', letterSpacing: -.5, marginTop: 9 }}>{s.name}</div>
            {shift !== 'off' && <div style={{ font: '600 13px/1.2 var(--font-family)', opacity: .85, marginTop: 3 }}>{s.time}</div>}
            <div style={{ display: 'flex', gap: 4, marginTop: 10 }}>
              <MiniGlassChip icon="group" label="3 East 병동" on={s.on} />
            </div>
          </div>
        </div>
        {/* Row: 좌(Next Off + 인수인계) / 우(On-Shift Now) */}
        <div style={{ display: 'flex', gap: 8 }}>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {/* NEXT OFF */}
            <div style={{ background: tintBg, border: `1px solid ${tintBorder}`, borderRadius: 16, padding: 10, display: 'flex', gap: 7, alignItems: 'center' }}>
              <div style={{ width: 24, height: 24, borderRadius: 7, background: iconTile, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ fontSize: 14, color: s.accent, fontVariationSettings: "'FILL' 1" }}>beach_access</span>
              </div>
              <div style={{ minWidth: 0 }}>
                <div style={{ font: '800 7px/1 var(--font-family)', letterSpacing: 1, textTransform: 'uppercase', color: muted }}>Next Off</div>
                <div style={{ font: '900 12px/1.1 var(--font-family)', color: s.accent, marginTop: 3 }}>D-3 <span style={{ font: '600 8px/1 var(--font-family)', color: muted }}>6.14(토)</span></div>
              </div>
            </div>
            {/* 인수인계 */}
            <div style={{ background: tintBg, border: `1px solid ${tintBorder}`, borderRadius: 16, padding: 10, display: 'flex', gap: 7, alignItems: 'center' }}>
              <div style={{ width: 24, height: 24, borderRadius: 7, background: iconTile, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ fontSize: 14, color: s.accent, fontVariationSettings: "'FILL' 1" }}>sticky_note_2</span>
              </div>
              <div style={{ minWidth: 0 }}>
                <div style={{ font: '800 9px/1 var(--font-family)', color: ink }}>인수인계 <span style={{ color: s.accent }}>2</span></div>
                <div style={{ font: '500 8px/1.2 var(--font-family)', color: muted, marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>제세동기 점검 완료</div>
              </div>
            </div>
          </div>
          {/* ON-SHIFT NOW */}
          <div style={{ flex: 1, background: tintBg, border: `1px solid ${tintBorder}`, borderRadius: 16, padding: 11 }}>
            <div style={{ font: '800 7px/1 var(--font-family)', letterSpacing: 1, textTransform: 'uppercase', color: muted }}>On-Shift Now</div>
            <div style={{ display: 'inline-block', marginTop: 6, background: iconTile, borderRadius: 9999, padding: '3px 8px', font: '800 8px/1 var(--font-family)', color: s.accent }}>이브닝 16-24</div>
            <div style={{ display: 'flex', marginTop: 9 }}>
              {['#FFC107','#FF8F00','#0061A4'].map((c,i)=>(<div key={i} style={{ width: 21, height: 21, borderRadius: '50%', background: c, border: `2px solid ${s.bg}`, marginLeft: i === 0 ? 0 : -6 }} />))}
              <div style={{ width: 21, height: 21, borderRadius: '50%', background: '#F7F1DC', border: `2px solid ${s.bg}`, marginLeft: -6, display: 'flex', alignItems: 'center', justifyContent: 'center', font: '800 7px/1 var(--font-family)', color: muted }}>+2</div>
            </div>
          </div>
        </div>
        {/* 팀 소식 */}
        <div style={{ font: '900 13px/1 var(--font-family)', color: s.accent, marginTop: 1 }}>팀 소식</div>
        <div style={{ background: tintBg, border: `1px solid ${tintBorder}`, borderRadius: 16, padding: 10, display: 'flex', gap: 8, alignItems: 'center' }}>
          <div style={{ width: 26, height: 26, borderRadius: 8, background: iconTile, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <span className="material-symbols-outlined" style={{ fontSize: 15, color: s.accent }}>campaign</span>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <span style={{ font: '800 9px/1 var(--font-family)', color: ink }}>팀 공지사항</span>
              <span style={{ font: '700 7px/1 var(--font-family)', color: s.accent }}>[3 East]</span>
            </div>
            <div style={{ font: '500 9px/1.2 var(--font-family)', color: '#5F5C4D', marginTop: 3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>이번 주 컨퍼런스 일정 안내</div>
          </div>
          <span className="material-symbols-outlined" style={{ fontSize: 16, color: muted }}>chevron_right</span>
        </div>
      </div>
      <MiniBottomNav active="home" />
    </div>
  );
};

// ─────────────────────────────────────────────
// Shared helpers for calendar-style mocks
// ─────────────────────────────────────────────

// Build a 6-week × 7-day calendar grid for a given (year, monthIdx0, startWeekday: 0=Sun)
// Returns array of {day, inMonth, weekday}
function buildMonthGrid(year, monthIdx0, startWeekdaySunday = false) {
  const first = new Date(year, monthIdx0, 1);
  const firstDow = first.getDay(); // 0=Sun..6=Sat
  const prevMonthLast = new Date(year, monthIdx0, 0).getDate();
  const thisMonthLast = new Date(year, monthIdx0 + 1, 0).getDate();
  const leading = startWeekdaySunday ? firstDow : (firstDow + 6) % 7; // mon-first
  const cells = [];
  for (let i = 0; i < 42; i++) {
    const idx = i - leading + 1;
    if (idx < 1) {
      cells.push({ day: prevMonthLast + idx, inMonth: false, weekday: i % 7 });
    } else if (idx > thisMonthLast) {
      cells.push({ day: idx - thisMonthLast, inMonth: false, weekday: i % 7 });
    } else {
      cells.push({ day: idx, inMonth: true, weekday: i % 7 });
    }
  }
  return cells;
}

// Deterministic shift assignment for a "real-looking" month
function shiftForDay(day) {
  // Repeating D-D-E-E-N-N-O cycle with a tiny offset — looks like a real schedule
  const pat = ['d', 'd', 'e', 'e', 'n', 'n', 'o'];
  return pat[(day + 2) % 7];
}

// ─────────────────────────────────────────────
// MiniCalendarScreen — Personal calendar (renewed)
// Mirrors lib/presentation/screens/calendar/calendar_screen.dart
// + date_items_panel.dart 의 헤더/근무 일정/개인 일정 카드
// ─────────────────────────────────────────────
const MiniCalendarScreen = () => {
  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  // Month: 2026년 5월 (May 2026). May 1 2026 = Friday.
  const cells = buildMonthGrid(2026, 4, false);
  const selectedDay = 14;
  const todayDay = 14;
  const legend = [
    { code: 'D', color: SHIFT_COLORS.D },
    { code: 'E', color: SHIFT_COLORS.E },
    { code: 'N', color: SHIFT_COLORS.N },
    { code: 'OFF', color: SHIFT_COLORS.O },
  ];

  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: '#FCF6E3' }}>
      <MiniStatusBar />
      <MiniTopBar title="이간호 님의 일정" />

      {/* External calendar header — matches MoniqCalendar _buildExternalHeader */}
      <div style={{ padding: '0 18px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ font: '900 18px/1.1 var(--font-family)', color: '#312F23', letterSpacing: -0.4 }}>
            2026년 5월
          </div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2, marginLeft: 4 }}>
            <div style={{ width: 22, height: 22, borderRadius: '50%', background: '#FFFDF7', boxShadow: '0 1px 3px rgba(49,47,35,.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: 14, color: '#5F5C4D' }}>chevron_left</span>
            </div>
            <div style={{ width: 22, height: 22, borderRadius: '50%', background: '#FFFDF7', boxShadow: '0 1px 3px rgba(49,47,35,.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: 14, color: '#5F5C4D' }}>chevron_right</span>
            </div>
          </div>
        </div>
        <div style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}>
          {legend.map(l => (
            <div key={l.code} style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
              <span style={{ width: 6, height: 6, borderRadius: '50%', background: l.color }} />
              <span style={{ font: '800 7px/1 var(--font-family)', letterSpacing: 1, textTransform: 'uppercase', color: '#7A7768' }}>{l.code}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Calendar card */}
      <div style={{ padding: '0 14px' }}>
        <div style={{ background: '#FFFDF7', borderRadius: 18, padding: '10px 10px 8px', boxShadow: '0 10px 24px rgba(49,47,35,.05)' }}>
          {/* DOW row */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', marginBottom: 4 }}>
            {days.map((d, i) => (
              <div key={i} style={{ textAlign: 'center', font: '800 8px/1 var(--font-family)', letterSpacing: 1.2, color: i === 5 || i === 6 ? '#C24B4B' : '#7A7768', padding: '4px 0' }}>{d}</div>
            ))}
          </div>
          {/* Day cells */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 2 }}>
            {cells.map((c, i) => {
              const code = c.inMonth ? shiftForDay(c.day) : null;
              const isSelected = c.inMonth && c.day === selectedDay;
              const isToday = c.inMonth && c.day === todayDay;
              const isWeekend = c.weekday === 5 || c.weekday === 6;
              return (
                <div key={i} style={{
                  aspectRatio: '0.95',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-start',
                  gap: 3, paddingTop: 4,
                  background: isSelected ? '#FFC107' : 'transparent',
                  borderRadius: 8,
                  boxShadow: isSelected ? '0 6px 14px rgba(255,193,7,.35)' : 'none',
                  opacity: c.inMonth ? 1 : 0.35,
                }}>
                  <div style={{
                    font: `${isSelected ? 900 : isToday ? 800 : 600} 10px/1 var(--font-family)`,
                    color: isSelected ? '#453900' : (isWeekend ? '#C24B4B' : '#312F23'),
                  }}>{c.day}</div>
                  {c.inMonth && code && (
                    <span style={{ width: 5, height: 5, borderRadius: '50%', background: SHIFT_COLORS[code.toUpperCase()] || SHIFT_COLORS.O }} />
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Selected date — header + section list (from date_items_panel.dart) */}
      <div style={{ padding: '12px 14px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {/* Date header pill */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '8px 12px', borderRadius: 14,
          background: 'linear-gradient(90deg, rgba(255,193,7,.18), rgba(255,140,0,.12), rgba(0,97,164,.08))',
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: '50%',
            background: 'linear-gradient(135deg, #FF8C00, #FFC107)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', font: '900 14px/1 var(--font-family)',
            boxShadow: '0 4px 10px rgba(255,140,0,.3)',
          }}>14</div>
          <div style={{ flex: 1 }}>
            <div style={{ font: '800 11px/1.2 var(--font-family)', color: '#312F23' }}>5월 14일 목요일</div>
            <div style={{ font: '500 9px/1.2 var(--font-family)', color: '#7A7768', marginTop: 1 }}>근무 1건 · 일정 1건</div>
          </div>
          <span className="material-symbols-outlined" style={{ fontSize: 16, color: '#7A7768' }}>keyboard_arrow_up</span>
        </div>

        {/* 근무 일정 section header */}
        <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.2, color: '#7A7768', marginTop: 2 }}>근무 일정</div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '8px 10px', borderRadius: 12,
          background: 'linear-gradient(90deg, rgba(255,140,0,.16), rgba(255,140,0,.05))',
          border: '1px solid rgba(255,140,0,.22)',
        }}>
          <div style={{ width: 26, height: 26, borderRadius: 6, background: SHIFT_COLORS.E, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', font: '900 10px/1 var(--font-family)' }}>E</div>
          <div style={{ flex: 1, font: '700 11px/1.2 var(--font-family)', color: '#312F23' }}>이브닝</div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 3, padding: '2px 6px', borderRadius: 6, background: 'rgba(255,140,0,.14)', color: '#E07800' }}>
            <span className="material-symbols-outlined" style={{ fontSize: 10 }}>access_time</span>
            <span style={{ font: '600 9px/1 var(--font-family)' }}>14:00 ~ 22:00</span>
          </div>
        </div>

        {/* 개인 일정 section header */}
        <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.2, color: '#7A7768', marginTop: 2 }}>개인 일정</div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '8px 10px', borderRadius: 12,
          background: 'rgba(56,161,105,.06)',
          border: '1px solid rgba(56,161,105,.18)',
        }}>
          <div style={{ width: 26, height: 26, borderRadius: 6, background: 'rgba(56,161,105,.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#2F7A52' }}>
            <span className="material-symbols-outlined" style={{ fontSize: 14 }}>event</span>
          </div>
          <div style={{ flex: 1, font: '600 11px/1.2 var(--font-family)', color: '#312F23' }}>요가 클래스</div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 3, padding: '2px 6px', borderRadius: 6, background: 'rgba(56,161,105,.14)', color: '#2F7A52' }}>
            <span className="material-symbols-outlined" style={{ fontSize: 10 }}>access_time</span>
            <span style={{ font: '600 9px/1 var(--font-family)' }}>10:00 ~ 11:30</span>
          </div>
        </div>
      </div>

      <MiniBottomNav active="home" />
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniTeamCalendarScreen — Team tab calendar
// Mirrors lib/presentation/screens/team/team_screen.dart
// + widgets/calendar/roster_panel.dart
// 캘린더 셀에는 시프트별 인원 수가 표시된 12px 원형 마커,
// 하단 RosterPanel에는 시프트 그룹 카드 + 멤버 칩 wrap.
// ─────────────────────────────────────────────
const MiniTeamCalendarScreen = () => {
  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const cells = buildMonthGrid(2026, 4, false);
  const selectedDay = 14;

  // 셀별 시프트 카운트 — 같은 날짜의 D/E/N 인원수
  const countsFor = (day) => {
    // 살짝 변동을 줘서 자연스럽게 보이도록
    const base = (day * 3) % 7;
    return {
      D: 3 + (base % 3),
      E: 2 + ((base + 1) % 3),
      N: 2 + ((base + 2) % 3),
    };
  };

  // 선택 날짜의 RosterPanel — 시프트별 그룹
  const roster = [
    {
      code: 'D', name: '데이', color: SHIFT_COLORS.D,
      members: [{ name: '이간호', me: true }, { name: '김간호' }, { name: '박간호' }, { name: '한간호' }],
    },
    {
      code: 'E', name: '이브닝', color: SHIFT_COLORS.E,
      members: [{ name: '최간호' }, { name: '정간호' }, { name: '윤간호' }],
    },
    {
      code: 'N', name: '나이트', color: SHIFT_COLORS.N,
      members: [{ name: '강간호' }, { name: '신간호' }],
    },
  ];

  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: '#FCF6E3' }}>
      <MiniStatusBar />
      {/* Top bar — team name + TEAM eyebrow (실제 TeamScreen 패턴) */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '4px 18px 12px' }}>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <div style={{
            width: 34, height: 34, borderRadius: 10,
            background: 'linear-gradient(135deg, #FFD700, #FF8C00)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 4px 10px rgba(255,140,0,.28)',
          }}>
            <span className="material-symbols-outlined" style={{ fontSize: 18, color: '#fff', fontVariationSettings: "'FILL' 1" }}>local_hospital</span>
          </div>
          <div>
            <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FF8F00' }}>TEAM</div>
            <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>3 East 병동</div>
          </div>
        </div>
        <span className="material-symbols-outlined" style={{ color: '#5F5C4D', fontSize: 20 }}>menu</span>
      </div>

      {/* View mode toggle pill */}
      <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 8 }}>
        <div style={{ display: 'inline-flex', background: '#FFFDF7', borderRadius: 9999, padding: 3, boxShadow: '0 2px 6px rgba(49,47,35,.06)' }}>
          {['월', '주', '일'].map((v, i) => (
            <div key={v} style={{
              padding: '4px 14px', borderRadius: 9999,
              font: '800 10px/1 var(--font-family)',
              background: i === 0 ? '#FFC107' : 'transparent',
              color: i === 0 ? '#453900' : '#7A7768',
            }}>{v}</div>
          ))}
        </div>
      </div>

      {/* External header */}
      <div style={{ padding: '0 18px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ font: '900 16px/1 var(--font-family)', color: '#312F23' }}>2026년 5월</div>
        <div style={{ display: 'inline-flex', gap: 5, alignItems: 'center' }}>
          {[['D', SHIFT_COLORS.D], ['E', SHIFT_COLORS.E], ['N', SHIFT_COLORS.N]].map(([k, c]) => (
            <div key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
              <span style={{ width: 6, height: 6, borderRadius: '50%', background: c }} />
              <span style={{ font: '800 7px/1 var(--font-family)', letterSpacing: 1, color: '#7A7768' }}>{k}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Calendar card */}
      <div style={{ padding: '0 14px' }}>
        <div style={{ background: '#FFFDF7', borderRadius: 16, padding: '8px 8px 6px', boxShadow: '0 10px 24px rgba(49,47,35,.05)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', marginBottom: 4 }}>
            {days.map((d, i) => (
              <div key={i} style={{ textAlign: 'center', font: '800 7px/1 var(--font-family)', letterSpacing: 1, color: i === 5 || i === 6 ? '#C24B4B' : '#7A7768', padding: '3px 0' }}>{d}</div>
            ))}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 2 }}>
            {cells.map((c, i) => {
              const isSelected = c.inMonth && c.day === selectedDay;
              const counts = c.inMonth ? countsFor(c.day) : null;
              return (
                <div key={i} style={{
                  aspectRatio: '0.85',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-start',
                  gap: 2, paddingTop: 3,
                  background: isSelected ? '#FFC107' : 'transparent',
                  borderRadius: 7,
                  boxShadow: isSelected ? '0 4px 10px rgba(255,193,7,.35)' : 'none',
                  opacity: c.inMonth ? 1 : 0.35,
                }}>
                  <div style={{
                    font: `${isSelected ? 900 : 600} 9px/1 var(--font-family)`,
                    color: isSelected ? '#453900' : '#312F23',
                  }}>{c.day}</div>
                  {counts && (
                    <div style={{ display: 'inline-flex', gap: 1 }}>
                      {['D', 'E', 'N'].map(k => (
                        <div key={k} style={{
                          width: 8, height: 8, borderRadius: '50%',
                          background: SHIFT_COLORS[k],
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          font: '900 5px/1 var(--font-family)', color: '#fff',
                        }}>{counts[k]}</div>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Roster panel — 시프트별 그룹 카드 (mobile에서는 1~2개만 보이는 스크롤 영역) */}
      <div style={{ padding: '10px 14px 0', display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{ font: '800 9px/1 var(--font-family)', letterSpacing: -0.2, color: '#312F23' }}>5월 14일 (목)</div>
        {roster.slice(0, 2).map(grp => (
          <div key={grp.code} style={{
            padding: '8px 10px', borderRadius: 12,
            background: `linear-gradient(135deg, ${grp.color}24, ${grp.color}0a)`,
            border: `1px solid ${grp.color}30`,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 22, height: 22, borderRadius: 5, background: grp.color, display: 'flex', alignItems: 'center', justifyContent: 'center', color: grp.code === 'D' ? '#453900' : '#fff', font: '900 10px/1 var(--font-family)' }}>{grp.code}</div>
              <div style={{ font: '700 11px/1 var(--font-family)', color: '#312F23' }}>{grp.name}</div>
              <div style={{ marginLeft: 'auto', padding: '2px 7px', borderRadius: 9999, background: `${grp.color}26`, color: grp.color === SHIFT_COLORS.D ? '#8A6500' : grp.color, font: '800 9px/1 var(--font-family)' }}>{grp.members.length}명</div>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 6 }}>
              {grp.members.map((m, i) => (
                <div key={i} style={{
                  padding: '2px 8px', borderRadius: 9999,
                  background: m.me ? `${grp.color}2E` : '#FFFDF7',
                  border: `1px solid ${m.me ? `${grp.color}59` : 'rgba(178,173,156,.4)'}`,
                  font: `${m.me ? 700 : 500} 9px/1.2 var(--font-family)`,
                  color: m.me ? (grp.color === SHIFT_COLORS.D ? '#8A6500' : grp.color) : '#312F23',
                }}>
                  {m.me ? `${m.name} (나)` : m.name}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <MiniBottomNav active="teams" />
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniCustomRulesScreen — Natural-language rules list
// Mirrors lib/presentation/screens/team/custom_rules_screen.dart
// + custom_rules_widgets.dart (CustomRuleCard + tag/priority badges)
// ─────────────────────────────────────────────
const MiniCustomRulesScreen = () => {
  // 실제 CustomRuleModel 모양 — originalText + ruleType label + priority(soft/hard)
  const rules = [
    { icon: 'block', text: '신규는 첫 주 야간 빼주세요', type: '근무 금지', priority: 'soft', active: true },
    { icon: 'bedtime', text: '나이트 3연속이면 2일 쉬어야 해요', type: '나이트 후 오프', priority: 'hard', active: true },
    { icon: 'group', text: 'A 간호사와 B 간호사는 같은 나이트를 서지 않게', type: '동시 배정 금지', priority: 'hard', active: true },
    { icon: 'workspace_premium', text: '신규가 있는 근무에는 베테랑 한 명은 꼭', type: '숙련도 조건', priority: 'soft', active: true },
    { icon: 'event_busy', text: '월요일 오프는 골고루 분배해주세요', type: '날짜 오프', priority: 'soft', active: false },
  ];

  const PriorityToggle = ({ priority, dim = false }) => {
    const isSoft = priority === 'soft';
    const softColor = '#B8860B';
    const hardColor = '#B02500';
    const borderColor = dim ? 'rgba(178,173,156,.4)' : (isSoft ? softColor : hardColor);
    return (
      <div style={{ display: 'inline-flex', height: 18, borderRadius: 5, border: `1.2px solid ${borderColor}`, overflow: 'hidden', opacity: dim ? 0.45 : 1 }}>
        <div style={{ padding: '0 6px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: isSoft ? softColor : 'transparent', color: isSoft ? '#fff' : '#7A7768', font: '800 8px/1 var(--font-family)' }}>소프트</div>
        <div style={{ width: 1, background: borderColor }} />
        <div style={{ padding: '0 6px', display: 'flex', alignItems: 'center', justifyContent: 'center', background: !isSoft ? hardColor : 'transparent', color: !isSoft ? '#fff' : '#7A7768', font: '800 8px/1 var(--font-family)' }}>하드</div>
      </div>
    );
  };

  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: '#FCF6E3' }}>
      <MiniStatusBar />
      {/* App bar — '커스텀 규칙' (MoniqAppBar 패턴) */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 18px 14px' }}>
        <span className="material-symbols-outlined" style={{ color: '#5F5C4D', fontSize: 20 }}>arrow_back</span>
        <div>
          <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FF8F00' }}>TEAM</div>
          <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>커스텀 규칙</div>
        </div>
        <span className="material-symbols-outlined" style={{ marginLeft: 'auto', color: '#5F5C4D', fontSize: 20 }}>more_horiz</span>
      </div>

      {/* Rule list */}
      <div style={{ padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {rules.map((r, i) => {
          const isHard = r.priority === 'hard';
          return (
            <div key={i} style={{
              background: r.active ? '#FFFDF7' : 'rgba(178,173,156,.18)',
              border: `1px solid ${isHard && r.active ? 'rgba(176,37,0,.5)' : 'rgba(178,173,156,.35)'}`,
              borderRadius: 12, padding: '10px 12px',
              display: 'flex', alignItems: 'flex-start', gap: 10,
              opacity: r.active ? 1 : 0.78,
            }}>
              <div style={{ paddingTop: 1 }}>
                <span className="material-symbols-outlined" style={{
                  fontSize: 18,
                  color: !r.active ? '#A89F84' : isHard ? '#B02500' : '#E07800',
                }}>{r.icon}</span>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  font: '600 11px/1.4 var(--font-family)',
                  color: r.active ? '#312F23' : '#A89F84',
                  textDecoration: r.active ? 'none' : 'line-through',
                }}>{r.text}</div>
                <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginTop: 6 }}>
                  <div style={{ padding: '2px 6px', borderRadius: 4, border: '1px solid rgba(178,173,156,.4)', background: '#FCF6E3', font: '600 8px/1 var(--font-family)', color: '#7A7768' }}>{r.type}</div>
                  <PriorityToggle priority={r.priority} dim={!r.active} />
                </div>
              </div>
              {/* Switch + delete */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                <div style={{
                  width: 26, height: 14, borderRadius: 9999, padding: 1.5,
                  background: r.active ? '#FFC107' : '#D5CFB7',
                  display: 'flex', justifyContent: r.active ? 'flex-end' : 'flex-start',
                }}>
                  <div style={{ width: 11, height: 11, borderRadius: '50%', background: '#FFFDF7', boxShadow: '0 1px 2px rgba(49,47,35,.2)' }} />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* 하단 입력 영역 — CustomRuleAddSheet placeholder pattern */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 60, padding: '0 14px' }}>
        <div style={{
          background: '#FFFDF7', borderRadius: 14, padding: '8px 10px',
          display: 'flex', alignItems: 'center', gap: 8,
          boxShadow: '0 10px 24px rgba(49,47,35,.12)',
          border: '1px solid rgba(178,173,156,.3)',
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 16, color: '#B8860B', fontVariationSettings: "'FILL' 1" }}>auto_awesome</span>
          <div style={{ flex: 1, font: '500 10px/1.3 var(--font-family)', color: '#A89F84' }}>예: 홍간호는 나이트 서지 않아요</div>
          <div style={{
            width: 26, height: 26, borderRadius: '50%',
            background: '#FFC107', display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 3px 8px rgba(255,193,7,.4)',
          }}>
            <span className="material-symbols-outlined" style={{ fontSize: 14, color: '#453900', fontVariationSettings: "'FILL' 1" }}>arrow_upward</span>
          </div>
        </div>
      </div>

      <MiniBottomNav active="teams" />
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniAIReportCard — phone-sized AI 분석 화면
// Mirrors widgets/schedule_violation_widgets.dart:
//   "위반 리포트" + _SummaryPill + _AiAnalysisCard + SummaryCard
// 근무표 자동생성 직후 AI 분석 카드가 떠 있는 모습.
// ─────────────────────────────────────────────
const MiniAIReportCard = () => {
  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: '#FCF6E3' }}>
      <MiniStatusBar />
      {/* App bar — 근무표 자동생성 결과 */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 18px 12px' }}>
        <span className="material-symbols-outlined" style={{ color: '#5F5C4D', fontSize: 20 }}>arrow_back</span>
        <div>
          <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FF8F00' }}>SCHEDULE</div>
          <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>2026년 6월 근무표</div>
        </div>
        <span className="material-symbols-outlined" style={{ marginLeft: 'auto', color: '#5F5C4D', fontSize: 20 }}>ios_share</span>
      </div>

      {/* 위반 리포트 헤더 — Row(title + AI 분석 버튼) */}
      <div style={{ padding: '0 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ font: '800 14px/1 var(--font-family)', color: '#312F23' }}>위반 리포트</div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            padding: '4px 10px', borderRadius: 9999,
            background: 'linear-gradient(90deg, rgba(255,140,0,.15), rgba(255,193,7,.1))',
            border: '1px solid rgba(255,140,0,.3)',
          }}>
            <span className="material-symbols-outlined" style={{ fontSize: 12, color: '#E07800', fontVariationSettings: "'FILL' 1" }}>auto_awesome</span>
            <span style={{ font: '700 10px/1 var(--font-family)', color: '#E07800' }}>AI 분석</span>
          </div>
        </div>
        {/* _SummaryPill row */}
        <div style={{ display: 'flex', gap: 12, marginTop: 6 }}>
          <span style={{ font: '600 10px/1 var(--font-family)', color: '#38A169' }}>하드 없음</span>
          <span style={{ font: '600 10px/1 var(--font-family)', color: '#38A169' }}>원티드 87%</span>
          <span style={{ font: '600 10px/1 var(--font-family)', color: '#FF8C00' }}>소프트 4건</span>
        </div>
      </div>

      {/* _AiAnalysisCard — gradient orange/yellow card */}
      <div style={{ margin: '10px 16px 8px', padding: 10, borderRadius: 8, background: 'linear-gradient(135deg, rgba(255,140,0,.1), rgba(255,193,7,.06))', border: '1px solid rgba(255,140,0,.25)' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 6 }}>
          <span className="material-symbols-outlined" style={{ fontSize: 13, color: '#E07800', marginTop: 1, fontVariationSettings: "'FILL' 1" }}>auto_awesome</span>
          <div style={{ flex: 1, font: '500 10px/1.45 var(--font-family)', color: '#312F23' }}>
            전체적으로 균형이 좋아요. <strong style={{ fontWeight: 800 }}>강간호</strong> 님의 야간이 평균보다 2회 많고, 14·15일 데이가 1명 부족합니다. 원티드는 87% 반영됐어요.
          </div>
          <span className="material-symbols-outlined" style={{ fontSize: 14, color: '#A89F84' }}>refresh</span>
        </div>
      </div>

      {/* Pill tab bar — 하드 위반 / 소프트 요약 */}
      <div style={{ margin: '4px 16px 8px', height: 30, borderRadius: 9999, background: 'rgba(178,173,156,.18)', display: 'flex', padding: 2.5 }}>
        <div style={{ flex: 1, borderRadius: 9999, background: '#FF8C00', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
          <span style={{ font: '700 10px/1 var(--font-family)', color: '#fff' }}>소프트 요약</span>
          <span style={{ padding: '1px 5px', borderRadius: 9999, background: 'rgba(255,255,255,.25)', font: '800 8px/1 var(--font-family)', color: '#fff' }}>4</span>
        </div>
        <div style={{ flex: 1, borderRadius: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
          <span style={{ font: '600 10px/1 var(--font-family)', color: '#7A7768' }}>하드 위반</span>
          <span style={{ padding: '1px 5px', borderRadius: 9999, background: 'rgba(56,161,105,.18)', font: '800 8px/1 var(--font-family)', color: '#38A169' }}>0</span>
        </div>
      </div>

      {/* SoftSummaryTab — _SectionHeader + SummaryCard들 */}
      <div style={{ padding: '4px 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ font: '700 10px/1 var(--font-family)', letterSpacing: 0.3, color: '#38A169' }}>원티드 반영률</div>
        {/* SummaryCard */}
        <div style={{
          padding: '10px 12px', borderRadius: 8,
          background: 'rgba(56,161,105,.06)', border: '1px solid rgba(56,161,105,.2)',
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 22, color: '#38A169' }}>favorite</span>
          <div style={{ flex: 1 }}>
            <div style={{ font: '600 9px/1.3 var(--font-family)', color: '#7A7768' }}>원티드 반영률</div>
            <div style={{ font: '500 9px/1.3 var(--font-family)', color: '#7A7768', marginTop: 1 }}>13건 반영 / 전체 15건</div>
          </div>
          <div style={{ font: '700 20px/1 var(--font-family)', color: '#38A169' }}>87%</div>
        </div>

        <div style={{ font: '700 10px/1 var(--font-family)', letterSpacing: 0.3, color: '#FF8C00', marginTop: 2 }}>소프트 위반 요약</div>
        {/* SoftSummaryTab — 실제 화면(schedule_violation_widgets)과 동일하게
            SummaryCard 두 개로 위반 패턴 카운트 표시 */}
        <div style={{
          padding: '10px 12px', borderRadius: 8,
          background: 'rgba(255,140,0,.06)', border: '1px solid rgba(255,140,0,.2)',
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 22, color: '#FF8C00' }}>dark_mode</span>
          <div style={{ flex: 1 }}>
            <div style={{ font: '700 10px/1.3 var(--font-family)', color: '#312F23' }}>연속 야간 초과</div>
            <div style={{ font: '500 9px/1.3 var(--font-family)', color: '#7A7768', marginTop: 2 }}>강간호 · 3일 연속</div>
          </div>
          <div style={{ font: '700 18px/1 var(--font-family)', color: '#FF8C00' }}>1</div>
        </div>
        <div style={{
          padding: '10px 12px', borderRadius: 8,
          background: 'rgba(255,140,0,.06)', border: '1px solid rgba(255,140,0,.2)',
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 22, color: '#FF8C00' }}>schedule</span>
          <div style={{ flex: 1 }}>
            <div style={{ font: '700 10px/1.3 var(--font-family)', color: '#312F23' }}>최소 휴식 미준수</div>
            <div style={{ font: '500 9px/1.3 var(--font-family)', color: '#7A7768', marginTop: 2 }}>N → D 직접 전환 2회</div>
          </div>
          <div style={{ font: '700 18px/1 var(--font-family)', color: '#FF8C00' }}>2</div>
        </div>
      </div>

      <MiniBottomNav active="home" />
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniWantedCollectionScreen — 원티드 수집 결과 화면
// 사용자 첨부 캡쳐 기반: 수집 마감 배너 + 원티드/나이트 전담 토글
//   + 멤버별 우선순위 칩 리스트 + 수집 재개/새 수집 액션
// ─────────────────────────────────────────────
const MiniWantedCollectionScreen = () => {
  // 우선순위 칩: code(D/E/N/O/ED), date, rank(1/2)
  const chipStyle = (code, rank) => {
    const palette = {
      D:  { soft: '#FFF1B8', strong: '#FFD45A', text: '#7A5A00' },
      E:  { soft: '#FFE3C2', strong: '#FFB36A', text: '#8B4500' },
      N:  { soft: '#CFE0F4', strong: '#7AAEE8', text: '#0F4F88' },
      O:  { soft: '#E5E1D0', strong: '#C9C2A8', text: '#5F5C4D' },
      ED: { soft: '#E9D8FF', strong: '#C2A4F2', text: '#5A2EB1' },
    };
    const c = palette[code] || palette.O;
    return rank === 1
      ? { bg: c.strong, fg: '#312F23', label: c.text }
      : { bg: c.soft, fg: c.text, label: c.text };
  };

  const members = [
    { name: '강간호', count: 7, picks: [
      { code: 'O', date: '06.01', rank: 1 },
      { code: 'O', date: '06.02', rank: 1 },
      { code: 'ED', date: '06.03', rank: 2 },
      { code: 'ED', date: '06.10', rank: 2 },
      { code: 'O', date: '06.26', rank: 1 },
    ] },
    { name: '김간호', count: 7, picks: [
      { code: 'ED', date: '06.03', rank: 2 },
      { code: 'ED', date: '06.04', rank: 2 },
      { code: 'O', date: '06.23', rank: 1 },
      { code: 'O', date: '06.24', rank: 1 },
    ] },
    { name: '정간호', count: 8, picks: [
      { code: 'O', date: '06.10', rank: 2 },
      { code: 'D', date: '06.18', rank: 1 },
      { code: 'D', date: '06.19', rank: 1 },
      { code: 'E', date: '06.26', rank: 2 },
    ] },
    { name: '백간호', count: 3, picks: [
      { code: 'E', date: '06.11', rank: 1 },
      { code: 'E', date: '06.12', rank: 1 },
      { code: 'E', date: '06.27', rank: 1 },
    ] },
  ];

  const Pill = ({ pick }) => {
    const s = chipStyle(pick.code, pick.rank);
    return (
      <div style={{
        display: 'inline-flex', alignItems: 'center',
        background: '#FFFDF7',
        border: '1px solid rgba(178,173,156,.3)',
        borderRadius: 9999, paddingRight: 8,
        font: '700 8px/1 var(--font-family)', color: '#312F23',
      }}>
        <div style={{
          width: 18, height: 18, borderRadius: '50%',
          background: s.bg, color: s.fg,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          font: '800 7px/1 var(--font-family)',
          marginRight: 5,
        }}>{pick.code}</div>
        <span>{pick.date} · {pick.rank}순위</span>
      </div>
    );
  };

  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: '#FCF6E3', display: 'flex', flexDirection: 'column' }}>
      <MiniStatusBar />
      {/* App bar — 원티드 수집 */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 16px 10px', flexShrink: 0 }}>
        <span className="material-symbols-outlined" style={{ color: '#5F5C4D', fontSize: 20 }}>arrow_back</span>
        <div>
          <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FF8F00' }}>TEAM</div>
          <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>원티드 수집</div>
        </div>
        <span className="material-symbols-outlined" style={{ marginLeft: 'auto', color: '#5F5C4D', fontSize: 20 }}>history</span>
      </div>

      {/* 수집 결과 배너 */}
      <div style={{ margin: '0 14px 8px', padding: '10px 12px', borderRadius: 14, background: '#EFE5CC', flexShrink: 0 }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '2px 7px', background: '#FFFDF7', borderRadius: 9999, font: '700 8px/1 var(--font-family)', color: '#5F5C4D', marginBottom: 6 }}>
          <span className="material-symbols-outlined" style={{ fontSize: 10 }}>check_circle</span>
          수집 마감
        </div>
        <div style={{ font: '900 12px/1.2 var(--font-family)', color: '#312F23' }}>원티드 수집 결과</div>
        <div style={{ font: '600 9px/1.3 var(--font-family)', color: '#5F5C4D', marginTop: 2 }}>06.01 ~ 06.30</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 3, marginTop: 4, font: '600 9px/1 var(--font-family)', color: '#5F5C4D' }}>
          <span className="material-symbols-outlined" style={{ fontSize: 11 }}>group</span>
          5명 응답 · 28건
        </div>
      </div>

      {/* 토글: 원티드 / 나이트 전담 */}
      <div style={{ display: 'flex', justifyContent: 'center', gap: 6, padding: '0 14px 8px', flexShrink: 0 }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '5px 10px', borderRadius: 9999, background: '#FFD45A', font: '800 9px/1 var(--font-family)', color: '#7A5A00' }}>
          <span className="material-symbols-outlined" style={{ fontSize: 11 }}>check</span>
          원티드
        </div>
        <div style={{ padding: '5px 10px', borderRadius: 9999, background: '#FFFDF7', border: '1px solid rgba(178,173,156,.4)', font: '700 9px/1 var(--font-family)', color: '#5F5C4D' }}>
          나이트 전담
        </div>
      </div>

      {/* 멤버별 응답 카드 — 남은 공간만 차지, 넘치면 잘림 */}
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden', padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 6 }}>
        {members.map((m, i) => (
          <div key={i} style={{
            background: '#FFFDF7', border: '1px solid rgba(178,173,156,.3)',
            borderRadius: 14, padding: '8px 10px', flexShrink: 0,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 5 }}>
              <div style={{ width: 18, height: 18, borderRadius: '50%', background: '#EEE8D3', display: 'flex', alignItems: 'center', justifyContent: 'center', font: '800 8px/1 var(--font-family)', color: '#5F5C4D' }}>
                {m.name[0]}
              </div>
              <div style={{ font: '800 10px/1 var(--font-family)', color: '#312F23' }}>{m.name}</div>
              <div style={{ marginLeft: 'auto', font: '700 9px/1 var(--font-family)', color: '#7A7768' }}>{m.count}건</div>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
              {m.picks.map((p, j) => <Pill key={j} pick={p} />)}
            </div>
          </div>
        ))}
      </div>

      {/* 액션 — 수집 재개 + 새 수집 시작 (하단 고정, flow) */}
      <div style={{ flexShrink: 0, padding: '8px 14px 0', display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{
          padding: '8px 12px', borderRadius: 9999,
          border: '1px solid rgba(178,173,156,.5)',
          background: '#FCF6E3',
          textAlign: 'center',
          font: '700 10px/1 var(--font-family)', color: '#5F5C4D',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 12 }}>refresh</span>
          수집 재개
        </div>
        <div style={{
          padding: '9px 12px', borderRadius: 9999,
          background: '#FFC107',
          textAlign: 'center',
          font: '900 11px/1 var(--font-family)', color: '#453900',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
          boxShadow: '0 6px 14px rgba(255,193,7,.32)',
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 13, fontVariationSettings: "'FILL' 1" }}>add</span>
          새 수집 시작
        </div>
      </div>

      {/* 하단 네비게이션 영역 확보 */}
      <div style={{ height: 62, flexShrink: 0 }} />
      <MiniBottomNav active="teams" />
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniRequestScreen — Change request list (renewed)
// Mirrors lib/presentation/screens/request/request_list_screen.dart
//   FilterBar + RequestCard list + StatusBadge
// ─────────────────────────────────────────────
const MiniRequestScreen = () => {
  const filters = [
    { key: 'all', label: '전체' },
    { key: 'pending', label: '대기중', selected: true },
    { key: 'approved', label: '승인' },
    { key: 'rejected', label: '거절' },
  ];

  // status palette — _statusStyle() 매핑
  const STATUS = {
    pending:  { c: '#FF8C00', bg: 'rgba(255,140,0,.1)',  label: '대기중' },
    approved: { c: '#38A169', bg: 'rgba(56,161,105,.12)', label: '승인' },
    rejected: { c: '#C24B4B', bg: 'rgba(194,75,75,.12)',  label: '거절' },
  };

  // 실제 RequestModel — changeType + reason + createdAt(MM.dd) + status
  const requests = [
    { type: '근무 교환', reason: '김간호와 5/14(목) ↔ 5/17(일)', date: '05.10', status: 'pending' },
    { type: '근무 변경', reason: '5/20 데이 → 오프 변경 요청', date: '05.09', status: 'pending' },
    { type: '근무 교환', reason: '박간호와 5/22(금) ↔ 5/25(월)', date: '05.07', status: 'approved' },
    { type: '휴무 요청', reason: '5/28(목) 가족 행사', date: '05.05', status: 'approved' },
    { type: '근무 변경', reason: '5/02 나이트 → 이브닝', date: '05.01', status: 'rejected' },
  ];

  return (
    <div style={{ height: '100%', position: 'relative', overflow: 'hidden', background: '#FCF6E3' }}>
      <MiniStatusBar />
      {/* App bar — '변경 요청' */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 18px 10px' }}>
        <span className="material-symbols-outlined" style={{ color: '#5F5C4D', fontSize: 20 }}>arrow_back</span>
        <div>
          <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: '#FF8F00' }}>TEAM</div>
          <div style={{ font: '800 14px/1.2 var(--font-family)', color: '#312F23' }}>변경 요청</div>
        </div>
        <span className="material-symbols-outlined" style={{ marginLeft: 'auto', color: '#5F5C4D', fontSize: 20 }}>checklist</span>
      </div>

      {/* Filter bar */}
      <div style={{ padding: '0 14px 10px', display: 'flex', gap: 6, overflow: 'hidden' }}>
        {filters.map(f => (
          <div key={f.key} style={{
            padding: '4px 10px', borderRadius: 9999,
            background: f.selected ? 'rgba(255,193,7,.18)' : '#FFFDF7',
            border: `1px solid ${f.selected ? 'rgba(255,193,7,.5)' : 'rgba(178,173,156,.3)'}`,
            font: '700 9px/1 var(--font-family)',
            color: f.selected ? '#8A6500' : '#5F5C4D',
            display: 'inline-flex', alignItems: 'center', gap: 3,
            whiteSpace: 'nowrap',
          }}>
            {f.selected && <span className="material-symbols-outlined" style={{ fontSize: 10, color: '#FFC107' }}>check</span>}
            {f.label}
          </div>
        ))}
      </div>

      {/* Request cards */}
      <div style={{ padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 6 }}>
        {requests.map((r, i) => {
          const st = STATUS[r.status];
          return (
            <div key={i} style={{
              background: '#FFFDF7', borderRadius: 8,
              border: '1px solid rgba(178,173,156,.35)',
              display: 'flex', alignItems: 'stretch',
              overflow: 'hidden',
            }}>
              {/* Left accent bar */}
              <div style={{ width: 3, background: st.c }} />
              <div style={{ flex: 1, padding: '8px 10px', display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ font: '700 11px/1.2 var(--font-family)', color: '#312F23' }}>{r.type}</div>
                  <div style={{ font: '500 9px/1.3 var(--font-family)', color: '#7A7768', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.reason}</div>
                  <div style={{ font: '600 8px/1 var(--font-family)', color: '#A89F84', marginTop: 3 }}>{r.date}</div>
                </div>
                <div style={{
                  padding: '3px 8px', borderRadius: 9999,
                  background: st.bg, color: st.c,
                  font: '800 8px/1 var(--font-family)', letterSpacing: 0.2,
                  flexShrink: 0,
                }}>{st.label}</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* FAB — 요청하기 */}
      <div style={{ position: 'absolute', right: 14, bottom: 72 }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 5,
          padding: '8px 14px', borderRadius: 9999,
          background: '#FFC107', color: '#453900',
          font: '800 11px/1 var(--font-family)',
          boxShadow: '0 8px 18px rgba(255,193,7,.4)',
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 14, fontVariationSettings: "'FILL' 1" }}>add</span>
          요청하기
        </div>
      </div>

      <MiniBottomNav active="teams" />
    </div>
  );
};

// Laptop frame (MacBook 16" style) for embedding wider UI mocks
const LaptopFrame = ({ children, width = 1040, tilt = 0, shadow = '0 40px 80px rgba(49,47,35,.28)' }) => {
  const height = Math.round(width * 0.625); // 16:10 screen area
  const baseHeight = Math.max(14, Math.round(width * 0.018));
  const hingeHeight = Math.max(6, Math.round(width * 0.008));
  return (
    <div style={{
      width,
      transform: tilt ? `perspective(2200px) rotateX(${tilt}deg)` : 'none',
      transformOrigin: 'center bottom',
      filter: `drop-shadow(${shadow})`,
      flexShrink: 0,
    }}>
      {/* Lid */}
      <div style={{
        width: '100%',
        background: '#1a1a1a',
        borderRadius: 18,
        padding: '18px 14px 14px',
        position: 'relative',
        boxShadow: 'inset 0 0 0 1px rgba(255,255,255,.05), inset 0 -1px 0 rgba(0,0,0,.4)',
      }}>
        {/* Notch */}
        <div style={{
          position: 'absolute', top: 0, left: '50%', transform: 'translateX(-50%)',
          width: Math.round(width * 0.13), height: 14,
          background: '#1a1a1a',
          borderRadius: '0 0 10px 10px',
          zIndex: 3,
          boxShadow: 'inset 0 -1px 0 rgba(0,0,0,.5)',
        }}>
          <div style={{
            position: 'absolute', top: 4, left: '50%', transform: 'translateX(-50%)',
            width: 5, height: 5, borderRadius: '50%',
            background: '#0a0a0a',
            boxShadow: 'inset 0 0 0 1px rgba(80,80,80,.4)',
          }} />
        </div>
        {/* Screen */}
        <div style={{
          width: '100%', height,
          background: '#000',
          borderRadius: 6,
          overflow: 'hidden',
          position: 'relative',
          boxShadow: 'inset 0 0 0 1px rgba(255,255,255,.04)',
        }}>
          {children}
        </div>
      </div>
      {/* Hinge */}
      <div style={{
        width: '100%', height: hingeHeight,
        background: 'linear-gradient(180deg, #8E9197 0%, #6B6E73 100%)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,.18), inset 0 -1px 0 rgba(0,0,0,.25)',
      }} />
      {/* Base (aluminum) */}
      <div style={{
        width: `calc(100% + ${Math.round(width * 0.04)}px)`,
        marginLeft: -Math.round(width * 0.02),
        height: baseHeight,
        background: 'linear-gradient(180deg, #D6D8DC 0%, #BEC1C6 55%, #A8ABB0 100%)',
        borderRadius: '4px 4px 14px 14px',
        position: 'relative',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,.45), inset 0 -2px 4px rgba(0,0,0,.18), 0 6px 14px rgba(49,47,35,.18)',
      }}>
        {/* Trackpad notch */}
        <div style={{
          position: 'absolute', top: 0, left: '50%', transform: 'translateX(-50%)',
          width: Math.round(width * 0.16), height: Math.max(3, Math.round(baseHeight * 0.22)),
          background: 'linear-gradient(180deg, #9DA0A6 0%, #BEC1C6 100%)',
          borderRadius: '0 0 8px 8px',
          boxShadow: 'inset 0 1px 0 rgba(0,0,0,.18)',
        }} />
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniScheduleGenScreen — laptop view (refined)
// Mirrors lib/presentation/screens/schedule/schedule_generation_screen.dart
// 좌측 이름 컬럼, 가로 30일 그리드, 작은 D/E/N/O 컬러 칩,
// 하단 D/E/N 인원 합계. 컬러는 크림+노랑/주황/파랑 톤.
// ─────────────────────────────────────────────
const MiniScheduleGenScreen = () => {
  // Soft chip colors — 우리 톤(크림+노랑/주황/파랑)에 맞게 채도 살짝 다운
  const shiftColor = {
    D: { bg: '#FFE9A8', fg: '#6B5300' },
    E: { bg: '#FFD0A1', fg: '#8A4A00' },
    N: { bg: '#C5DCEF', fg: '#0B3F6E' },
    O: { bg: '#ECE8D8', fg: '#7A7768' },
  };
  // 12 rows × 30 cols — 패턴
  const pattern = [
    'DDOEENNDOEENNDOEENOODEENOOEENNOO',
    'EENNOODDEENNOOEENNDDOOEENNDDEENO',
    'NNDDEEOONNDDEEOONNDDEEOONNDDEEOO',
    'OOEENNDDOOEENNDDOOEENNDDOOEENNDD',
    'DDOOEENNDDOOEENNDDOOEENNDDOOEENN',
    'NNDDOOEENNDDOOEENNDDOOEENNDDOOEE',
    'EENNDDOOEENNDDOOEENNDDOOEENNDDOO',
    'DDEENNOODDEENNOODDEENNOODDEENNOO',
    'OOOOEENNDDEENNOODDEENNDDOOEENNDD',
    'NNDDEEOONNDDOOEENNDDEEOONNDDEEOO',
    'EENNDDOOEENNDDOOEENNDDOOEENNDDOO',
    'DDOOEENNDDOOEENNDDOOEENNDDOOEENN',
  ];
  const grid = pattern.map(row => row.slice(0, 30).split(''));
  const names = ['김간호','서간호','박간호','최간호','정간호','강간호','윤간호','임간호','한간호','조간호','신간호','오간호'];
  const days = Array.from({ length: 30 }, (_, i) => i + 1);
  // 1=Mon (June 2026 starts on Monday). Sat=days 6,13,20,27 / Sun=days 7,14,21,28
  const weekendCol = (d) => {
    const wknd = [6, 7, 13, 14, 20, 21, 27, 28];
    return wknd.includes(d);
  };

  // D/E/N daily counts
  const counts = {
    D: [5,6,9,6,4,3,4,5,6,7,8,5,4,3,6,7,8,5,4,6,7,8,5,4,6,7,8,5,4,6],
    E: [6,6,9,5,4,3,5,6,7,5,4,6,7,8,5,4,6,7,5,4,6,7,5,4,6,7,5,4,6,7],
    N: [7,6,9,5,3,3,6,5,4,7,6,5,4,6,7,5,4,6,7,5,4,6,7,5,4,6,7,5,4,6],
  };

  const cellSize = 20;
  const cellGap = 3;
  const nameColW = 100;
  const sumColors = { D: '#FFC107', E: '#FF8C00', N: '#0061A4' };

  // 셀 상태 — 듀팅식 마커. violation(룰 위반)·wanted(원티드 반영)·unmet(미반영)
  const _violations = [[2, 7], [6, 18], [9, 3]];
  const _wanted = [[0, 4], [3, 11], [5, 22], [8, 9], [10, 15], [1, 25]];
  const _unmet = [[1, 14], [7, 26], [4, 19]];
  const cellStatus = (ri, ci) => {
    if (_violations.some(([r, c]) => r === ri && c === ci)) return 'violation';
    if (_wanted.some(([r, c]) => r === ri && c === ci)) return 'wanted';
    if (_unmet.some(([r, c]) => r === ri && c === ci)) return 'unmet';
    return null;
  };

  const Chip = ({ icon, label, bg, color, border }) => (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      background: bg, color,
      padding: '5px 10px', borderRadius: 9999,
      font: '700 10px/1 var(--font-family)', letterSpacing: .2,
      border: border || '1px solid transparent', whiteSpace: 'nowrap',
    }}>
      {icon && <span className="material-symbols-outlined" style={{ fontSize: 12, fontVariationSettings: "'FILL' 1" }}>{icon}</span>}
      {label}
    </div>
  );

  return (
    <div style={{ width: '100%', height: '100%', background: '#FCF6E3', display: 'flex', flexDirection: 'column', overflow: 'hidden', font: '400 11px/1.3 var(--font-family)', color: '#312F23' }}>
      {/* Top app bar */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '10px 16px', borderBottom: '1px solid rgba(178,173,156,.35)',
        background: '#FFFDF7',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 26, height: 26, borderRadius: 8,
            background: 'linear-gradient(135deg,#FFD700,#FF8C00)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff',
          }}>
            <span className="material-symbols-outlined" style={{ fontSize: 14, fontVariationSettings: "'FILL' 1" }}>calendar_month</span>
          </div>
          <div style={{ font: '900 13px/1 var(--font-family)', color: '#312F23' }}>OnorOff</div>
          <div style={{ font: '500 11px/1 var(--font-family)', color: '#7A7768', marginLeft: 6 }}>· 근무표 자동생성</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Chip icon="check_circle" label="저장 중" bg="rgba(56,161,105,.12)" color="#256B45" />
          <Chip icon="groups" label="3 East 병동 ▾" bg="#FFFDF7" color="#312F23" border="1px solid rgba(178,173,156,.4)" />
          <div style={{ width: 26, height: 26, borderRadius: '50%', background: '#FFD700', display: 'flex', alignItems: 'center', justifyContent: 'center', font: '900 11px/1 var(--font-family)', color: '#453900' }}>J</div>
        </div>
      </div>

      {/* Sub toolbar */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '10px 16px', gap: 16,
        background: '#FFFDF7', borderBottom: '1px solid rgba(178,173,156,.25)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0, flexShrink: 1, overflow: 'hidden' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: '#FCF6E3', borderRadius: 9999, padding: '4px 6px', flexShrink: 0 }}>
            <span className="material-symbols-outlined" style={{ fontSize: 16, color: '#5F5C4D', cursor: 'pointer' }}>chevron_left</span>
            <div style={{ font: '800 12px/1 var(--font-family)', color: '#312F23', padding: '0 4px' }}>2026 · 6월</div>
            <span className="material-symbols-outlined" style={{ fontSize: 16, color: '#5F5C4D', cursor: 'pointer' }}>chevron_right</span>
          </div>
          <Chip icon="tune" label="규칙 편집" bg="#FCF6E3" color="#5F5C4D" border="1px solid rgba(178,173,156,.4)" />
          <Chip icon="auto_awesome" label="AI 분석" bg="rgba(255,140,0,.12)" color="#B05A00" border="1px solid rgba(255,140,0,.3)" />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
          <Chip icon="bolt" label="다시 생성" bg="#312F23" color="#FCF6E3" />
          <Chip icon="ios_share" label="게시" bg="#FFC107" color="#453900" />
        </div>
      </div>

      {/* Legend bar */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '8px 16px', background: '#FCF6E3',
      }}>
        <div style={{ font: '800 9px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase', color: '#7A7768' }}>
          간호사 {names.length}명 · 30일 자동 생성 완료
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', background: '#FFFDF7', padding: '5px 10px', borderRadius: 9999, border: '1px solid rgba(178,173,156,.3)' }}>
          <span style={{ font: '800 9px/1 var(--font-family)', letterSpacing: 1.2, color: '#7A7768' }}>근무 유형</span>
          {[
            ['D', shiftColor.D.bg, shiftColor.D.fg],
            ['E', shiftColor.E.bg, shiftColor.E.fg],
            ['N', shiftColor.N.bg, shiftColor.N.fg],
            ['O', shiftColor.O.bg, shiftColor.O.fg],
          ].map(([k, bg, fg]) => (
            <div key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 14, height: 14, borderRadius: 3, background: bg, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', font: '900 9px/1 var(--font-family)', color: fg }}>{k}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Grid area */}
      <div style={{ flex: 1, overflow: 'hidden', padding: '6px 16px 0', background: '#FCF6E3' }}>
        <div style={{
          background: '#FFFDF7', borderRadius: 14,
          border: '1px solid rgba(178,173,156,.3)',
          padding: 12, height: '100%', overflow: 'hidden',
          display: 'flex', flexDirection: 'column', gap: 6,
        }}>
          {/* Header row */}
          <div style={{ display: 'flex', gap: cellGap, alignItems: 'center' }}>
            <div style={{ width: nameColW, font: '800 9px/1 var(--font-family)', letterSpacing: 1.2, textTransform: 'uppercase', color: '#7A7768' }}>이름</div>
            {days.map(d => (
              <div key={d} style={{
                width: cellSize, height: 16,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                font: '800 9px/1 var(--font-family)',
                color: weekendCol(d) ? '#C24B4B' : '#7A7768',
              }}>{d}</div>
            ))}
          </div>

          {/* Nurse rows */}
          {grid.map((row, ri) => (
            <div key={ri} style={{ display: 'flex', gap: cellGap, alignItems: 'center' }}>
              <div style={{ width: nameColW, display: 'flex', alignItems: 'center', gap: 6 }}>
                <div style={{ width: 18, height: 18, borderRadius: '50%', background: ['#FFD700','#FF8C00','#0061A4','#A0AEC0','#FFC107'][ri % 5], display: 'flex', alignItems: 'center', justifyContent: 'center', font: '900 9px/1 var(--font-family)', color: '#fff' }}>
                  {names[ri].slice(1, 2)}
                </div>
                <div style={{ font: '700 10px/1 var(--font-family)', color: '#312F23', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{names[ri]}</div>
              </div>
              {row.map((code, ci) => {
                const sc = shiftColor[code];
                const isToday = ci === 12 && ri === 4;
                const st = cellStatus(ri, ci);
                return (
                  <div key={ci} style={{
                    width: cellSize, height: cellSize, borderRadius: 5,
                    background: sc.bg, color: sc.fg,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    font: '900 10px/1 var(--font-family)',
                    position: 'relative',
                    boxShadow: st === 'violation'
                      ? '0 0 0 2px #D64545'
                      : isToday
                        ? '0 0 0 2px #FFC107, 0 4px 10px rgba(255,193,7,.4)'
                        : 'none',
                  }}>
                    {code === 'O' ? '·' : code}
                    {(st === 'wanted' || st === 'unmet') && (
                      <span style={{
                        position: 'absolute', top: 2, right: 2,
                        width: 5, height: 5, borderRadius: '50%',
                        background: st === 'wanted' ? '#2F9E5E' : '#0061A4',
                        boxShadow: '0 0 0 1.5px #FFFDF7',
                      }} />
                    )}
                  </div>
                );
              })}
            </div>
          ))}

          {/* Spacer */}
          <div style={{ height: 4 }} />

          {/* Summary rows D/E/N */}
          {['D','E','N'].map(k => (
            <div key={k} style={{ display: 'flex', gap: cellGap, alignItems: 'center' }}>
              <div style={{ width: nameColW, display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: sumColors[k] }} />
                <div style={{ font: '800 9px/1 var(--font-family)', letterSpacing: 1.4, textTransform: 'uppercase', color: '#5F5C4D' }}>{k} 인원</div>
              </div>
              {counts[k].map((n, i) => (
                <div key={i} style={{
                  width: cellSize, height: 16,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  font: '800 9px/1 var(--font-family)',
                  color: n === 0 ? '#C0B9A1' : '#312F23',
                }}>{n}</div>
              ))}
            </div>
          ))}
        </div>
      </div>

      {/* Bottom status bar */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '8px 16px',
        background: '#FFFDF7',
        borderTop: '1px solid rgba(178,173,156,.25)',
        font: '600 10px/1 var(--font-family)', color: '#7A7768',
      }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 14 }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#38A169' }} />
            제약 조건 통과 · 공정성 점수 92
          </span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#0061A4' }} />
            원티드 13/15 반영
          </span>
        </div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 14 }}>
          <span>0.8초 만에 생성됨</span>
          <span>마지막 저장 1분 전</span>
        </div>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniRuleSettingPanel — 제약 조건 설정 패널 (FloatingPanel 안에 끼움)
// 듀팅의 "제약 조건 / 근무 형태" 설정 모달을 우리 룰 체계로 재구성
// ─────────────────────────────────────────────
const MiniRuleSettingPanel = () => {
  const rows = [
    { label: '연속 근무일', value: '최대 5일', on: true },
    { label: '연속 야간', value: '최대 3일', on: true },
    { label: '야간 후 휴식', value: '최소 1일', on: true },
    { label: 'N→D 기피 패턴', value: '금지', on: true },
    { label: 'D · E · N 인원', value: '6 / 4 / 3', on: false },
  ];
  const Toggle = ({ on }) => (
    <div style={{
      width: 30, height: 17, borderRadius: 9999, flexShrink: 0,
      background: on ? '#FFC107' : '#E4DDC6', position: 'relative',
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 15 : 2,
        width: 13, height: 13, borderRadius: '50%', background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,.25)',
      }} />
    </div>
  );
  return (
    <div style={{ font: '400 11px/1.3 var(--font-family)', color: '#312F23' }}>
      {/* 헤더 탭 */}
      <div style={{ display: 'flex', alignItems: 'center', padding: '0 14px', borderBottom: '1px solid rgba(178,173,156,.3)' }}>
        <div style={{ padding: '12px 8px', font: '800 11px/1 var(--font-family)', color: '#312F23', borderBottom: '2px solid #FFC107' }}>제약 조건</div>
        <div style={{ padding: '12px 8px', font: '700 11px/1 var(--font-family)', color: '#A89F86' }}>근무 형태</div>
        <span className="material-symbols-outlined" style={{ marginLeft: 'auto', fontSize: 16, color: '#A89F86' }}>close</span>
      </div>
      {/* 행들 */}
      <div style={{ padding: '4px 14px 12px' }}>
        {rows.map((r, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 8, padding: '10px 0',
            borderBottom: i < rows.length - 1 ? '1px solid rgba(178,173,156,.18)' : 'none',
          }}>
            <div style={{ font: '700 11px/1.2 var(--font-family)', color: '#312F23', flex: 1 }}>{r.label}</div>
            <div style={{ font: '800 10px/1 var(--font-family)', color: '#B8860B' }}>{r.value}</div>
            <Toggle on={r.on} />
          </div>
        ))}
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────
// MiniWantedEntryPanel — 팀원이 원티드를 신청하는 화면 (FloatingPanel용)
// 수집 결과 화면(MiniWantedCollectionScreen)의 "신청자 시점" 짝
// ─────────────────────────────────────────────
const MiniWantedEntryPanel = () => {
  const codeColor = {
    D: { bg: '#FFD45A', fg: '#7A5A00' },
    E: { bg: '#FFB36A', fg: '#8B4500' },
    N: { bg: '#7AAEE8', fg: '#0F4F88' },
    O: { bg: '#C9C2A8', fg: '#5F5C4D' },
  };
  const entries = [
    { date: '06.14', day: '토', code: 'O', rank: 1 },
    { date: '06.18', day: '수', code: 'D', rank: 1 },
    { date: '06.26', day: '금', code: 'E', rank: 2 },
  ];
  return (
    <div style={{ font: '400 11px/1.3 var(--font-family)', color: '#312F23' }}>
      {/* 헤더 */}
      <div style={{ padding: '14px 16px 10px', borderBottom: '1px solid rgba(178,173,156,.25)' }}>
        <div style={{ font: '800 8px/1 var(--font-family)', letterSpacing: 1.6, textTransform: 'uppercase', color: '#FF8F00' }}>MY WANTED</div>
        <div style={{ font: '900 14px/1.2 var(--font-family)', color: '#312F23', marginTop: 3 }}>원티드 신청</div>
        <div style={{ font: '600 9px/1 var(--font-family)', color: '#7A7768', marginTop: 4 }}>06.01 ~ 06.30 · 마감 D-2</div>
      </div>
      {/* 신청 항목 */}
      <div style={{ padding: '6px 12px' }}>
        {entries.map((e, i) => {
          const c = codeColor[e.code];
          return (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '8px 4px',
              borderBottom: i < entries.length - 1 ? '1px solid rgba(178,173,156,.15)' : 'none',
            }}>
              <div style={{
                width: 22, height: 22, borderRadius: '50%',
                background: c.bg, color: c.fg,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                font: '900 9px/1 var(--font-family)', flexShrink: 0,
              }}>{e.code}</div>
              <div style={{ flex: 1, font: '800 11px/1 var(--font-family)', color: '#312F23' }}>
                {e.date} <span style={{ color: '#7A7768', font: '600 10px/1 var(--font-family)' }}>({e.day})</span>
              </div>
              <div style={{
                padding: '3px 9px', borderRadius: 9999,
                background: e.rank === 1 ? '#FFC107' : 'rgba(255,193,7,.18)',
                color: e.rank === 1 ? '#453900' : '#6B5300',
                font: '800 9px/1 var(--font-family)',
              }}>{e.rank}순위</div>
            </div>
          );
        })}
      </div>
      {/* 날짜 추가 */}
      <div style={{ padding: '2px 12px 8px' }}>
        <div style={{
          border: '1.5px dashed rgba(178,173,156,.5)', borderRadius: 10,
          padding: '8px 0', textAlign: 'center',
          font: '700 10px/1 var(--font-family)', color: '#7A7768',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 13 }}>add</span>
          날짜 추가
        </div>
      </div>
      {/* 제출 버튼 */}
      <div style={{ padding: '0 12px 13px' }}>
        <div style={{
          background: '#FFC107', borderRadius: 9999,
          padding: '9px 0', textAlign: 'center',
          font: '900 11px/1 var(--font-family)', color: '#453900',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4,
          boxShadow: '0 6px 14px rgba(255,193,7,.32)',
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: 13, fontVariationSettings: "'FILL' 1" }}>send</span>
          신청 완료
        </div>
      </div>
    </div>
  );
};

Object.assign(window, {
  SHIFTS_LANDING, SHIFT_COLORS,
  MiniStatusBar, MiniTopBar, MiniGlassBadge, MiniGlassChip, MiniBottomNav,
  MiniHomeScreen, MiniCalendarScreen, MiniTeamCalendarScreen,
  MiniCustomRulesScreen, MiniAIReportCard, MiniRequestScreen,
  MiniWantedCollectionScreen, MiniWantedEntryPanel,
  LaptopFrame, MiniScheduleGenScreen, MiniRuleSettingPanel,
});
