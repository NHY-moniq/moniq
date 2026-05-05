// CTA + Social proof + Footer

const ProofStrip = () => (
  <Section paddingY={80}>
    <div style={{ textAlign: 'center', marginBottom: 40 }}>
      <LandingEyebrow>Trusted by nurses at</LandingEyebrow>
    </div>
    <div style={{ display: 'flex', justifyContent: 'center', gap: 48, flexWrap: 'wrap', opacity: .75 }}>
      {['Seoul National', 'Severance', 'Asan Medical', 'Samsung Medical', 'Ajou Univ.', 'Kyung Hee'].map(n => (
        <div key={n} style={{ font: '900 22px/1 var(--font-family)', letterSpacing: -.5, color: '#5F5C4D' }}>{n}</div>
      ))}
    </div>
  </Section>
);

const Testimonials = () => (
  <Section paddingY={120}>
    <div style={{ textAlign: 'center', marginBottom: 56 }}>
      <LandingEyebrow>From the floor</LandingEyebrow>
      <h2 style={{ font: '900 52px/1.05 var(--font-family)', letterSpacing: -1.4, color: '#312F23', marginTop: 14, textWrap: 'balance' }}>
        간호사님들이 직접 남긴 후기.
      </h2>
    </div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 20 }}>
      {[
        { quote: '매달 근무표 짜느라 새벽까지 남았었는데, 이젠 10분이면 끝나요. 요청 반영도 자동이라 팀원들 불만도 줄었어요.', name: '박수진', role: 'Head Nurse · Unit 4 Medical', color: '#FFC107' },
        { quote: '교대 요청할 때 카톡 돌리면서 눈치 보던 게 사라졌어요. 앱 안에서 한 번에 해결되니까 너무 편해요.', name: '김하윤', role: 'RN · 3년차', color: '#FF8C00' },
        { quote: '오늘 무슨 근무인지 색깔만 봐도 알 수 있어서 좋아요. 야간 근무 끝나고 화면이 바뀌면 진짜 쉬는 것 같아요.', name: '이태민', role: 'Charge Nurse', color: '#0061A4' },
      ].map((t, i) => (
        <LandingCard key={i} padding={28} hover>
          <div style={{ display: 'flex', gap: 4, marginBottom: 16 }}>
            {[0,1,2,3,4].map(n => <span key={n} style={{ color: '#FFC107', font: '900 16px/1 var(--font-family)' }}>★</span>)}
          </div>
          <p style={{ font: '600 16px/1.55 var(--font-family)', color: '#312F23', marginBottom: 24, textWrap: 'pretty' }}>"{t.quote}"</p>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            <div style={{ width: 40, height: 40, borderRadius: '50%', background: t.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', font: '900 14px/1 var(--font-family)' }}>{t.name[0]}</div>
            <div>
              <div style={{ font: '800 13px/1.2 var(--font-family)', color: '#312F23' }}>{t.name}</div>
              <div style={{ font: '500 11px/1.2 var(--font-family)', color: '#7A7768', marginTop: 3 }}>{t.role}</div>
            </div>
          </div>
        </LandingCard>
      ))}
    </div>
  </Section>
);

const FAQ = () => {
  const [open, setOpen] = React.useState(0);
  const items = [
    { q: '무료로 쓸 수 있나요?', a: '개인 사용자는 무료로 쓸 수 있게 준비 중이에요. 병동 단위 팀 관리는 출시 시점에 안내드릴게요.' },
    { q: '어떤 교대근무자가 쓸 수 있나요?', a: '지금은 간호사 중심으로 설계되어 있지만, 경찰·소방·공장 근무자로 확장 중이에요.' },
    { q: '내 병원에 도입하려면 어떻게 하나요?', a: '수간호사님이 앱 내에서 Organization Team을 만들면 바로 시작할 수 있어요. 대규모 도입은 문의 주세요.' },
    { q: '기존 엑셀 근무표를 가져올 수 있나요?', a: '네, CSV 업로드로 지난 근무표를 불러올 수 있어요. 팀원 요청이나 규칙도 한 번에 이관돼요.' },
    { q: '야간 근무 규칙 같은 것도 지킬 수 있나요?', a: '연속 야간 제한, 최소 휴식 시간, 주간 최대 근무시간 등 팀 규칙을 세세하게 설정할 수 있어요.' },
  ];
  return (
    <Section paddingY={120} bg="#F7F1DC">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: 80, alignItems: 'flex-start' }}>
        <div>
          <LandingEyebrow>FAQ</LandingEyebrow>
          <h2 style={{ font: '900 52px/1.05 var(--font-family)', letterSpacing: -1.4, color: '#312F23', marginTop: 14, textWrap: 'balance' }}>
            자주 묻는 질문.
          </h2>
          <p style={{ font: '500 16px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 20 }}>
            연락처는 출시 시점에 안내드릴게요. 그때까지 궁금한 점은 잠시만 기다려주세요.
          </p>
        </div>
        <div>
          {items.map((it, i) => {
            const isOpen = open === i;
            return (
              <div key={i} onClick={() => setOpen(isOpen ? -1 : i)} style={{
                background: '#FFFDF7', borderRadius: 24, padding: '22px 28px', marginBottom: 10,
                cursor: 'pointer', border: '1px solid rgba(178,173,156,.25)',
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 20 }}>
                  <div style={{ font: '800 17px/1.3 var(--font-family)', color: '#312F23' }}>{it.q}</div>
                  <span className="material-symbols-outlined" style={{ color: '#5F5C4D', transition: 'transform .3s', transform: isOpen ? 'rotate(45deg)' : 'none' }}>add</span>
                </div>
                {isOpen && <p style={{ font: '500 15px/1.55 var(--font-family)', color: '#5F5C4D', marginTop: 14 }}>{it.a}</p>}
              </div>
            );
          })}
        </div>
      </div>
    </Section>
  );
};

const FinalCTA = () => (
  <Section paddingY={120}>
    <div style={{
      position: 'relative', overflow: 'hidden',
      background: 'linear-gradient(135deg, #FFD700, #FF8C00 60%, #0061A4)',
      borderRadius: 48, padding: '80px 60px',
      boxShadow: '0 40px 80px rgba(49,47,35,.2)',
    }}>
      <img src="assets/yellow.png" style={{ position: 'absolute', left: -60, top: -40, width: 220, height: 220, opacity: .45, transform: 'rotate(-14deg)' }} />
      <img src="assets/blue.png" style={{ position: 'absolute', right: -50, bottom: -60, width: 260, height: 260, opacity: .45, transform: 'rotate(16deg)' }} />
      <div style={{ position: 'relative', maxWidth: 680, margin: '0 auto', textAlign: 'center', color: '#fff' }}>
        <LandingEyebrow color="#fff" style={{ opacity: .85 }}>Ready when you are</LandingEyebrow>
        <h2 style={{ font: '900 68px/1.02 var(--font-family)', letterSpacing: -1.8, marginTop: 18, color: '#fff', textShadow: '0 2px 10px rgba(49,47,35,.12)' }}>
          오늘부터 근무표,<br />가볍게 시작해요.
        </h2>
        <p style={{ font: '600 18px/1.55 var(--font-family)', color: 'rgba(255,255,255,.9)', marginTop: 22, maxWidth: 520, margin: '22px auto 0' }}>
          iOS · Android 곧 출시돼요. 출시 알림을 먼저 받아보세요.
        </p>
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 36 }}>
          <ComingSoonButtons kind="cream" />
        </div>
      </div>
    </div>
  </Section>
);

const LandingFooter = () => (
  <footer style={{ padding: '64px 40px 48px', background: '#312F23', color: '#FCF6E3' }}>
    <div style={{ maxWidth: 1280, margin: '0 auto', display: 'grid', gridTemplateColumns: '1.5fr 1fr 1fr 1fr', gap: 40 }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <div style={{ display: 'flex' }}>
            {['#FFD700','#FF8C00','#0061A4'].map((c,i)=>(
              <div key={i} style={{ width: 18, height: 18, borderRadius: '50%', background: c, marginLeft: i === 0 ? 0 : -5, border: '2px solid #312F23' }} />
            ))}
          </div>
          <div style={{ font: '900 18px/1 var(--font-family)', letterSpacing: -.3 }}>
            <span style={{ color: '#FFD700' }}>ON</span>
            <span style={{ color: '#FCF6E3' }}>OR</span>
            <span style={{ color: '#0061A4' }}>OFF</span>
          </div>
        </div>
        <p style={{ font: '500 14px/1.55 var(--font-family)', color: 'rgba(252,246,227,.7)', maxWidth: 320 }}>
          간호사를 위한 근무표 관리 앱. 교대근무자의 하루가 조금 더 가벼워지도록.
        </p>
      </div>
      {[
        { title: 'Product', links: ['기능', '팀 스케줄', '요청하기', '가격'] },
        { title: 'Company', links: ['About', 'Blog', 'Careers', 'Press'] },
        { title: 'Support', links: ['Help', 'Contact', 'Privacy', 'Terms'] },
      ].map(col => (
        <div key={col.title}>
          <div style={{ font: '800 11px/1 var(--font-family)', letterSpacing: 1.8, textTransform: 'uppercase', color: 'rgba(252,246,227,.5)', marginBottom: 18 }}>{col.title}</div>
          {col.links.map(l => <div key={l} style={{ font: '600 14px/1 var(--font-family)', color: '#FCF6E3', marginBottom: 12, cursor: 'pointer' }}>{l}</div>)}
        </div>
      ))}
    </div>
    <div style={{ maxWidth: 1280, margin: '48px auto 0', paddingTop: 28, borderTop: '1px solid rgba(252,246,227,.12)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 16 }}>
      <div style={{ font: '500 13px/1 var(--font-family)', color: 'rgba(252,246,227,.5)' }}>© 2026 OnorOff · Moniq. Built for the ones who work when we sleep.</div>
      <div style={{ display: 'flex', gap: 14 }}>
        {['mail','language','forum'].map(i => (
          <div key={i} style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(252,246,227,.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <span className="material-symbols-outlined" style={{ fontSize: 18, color: '#FCF6E3' }}>{i}</span>
          </div>
        ))}
      </div>
    </div>
  </footer>
);

Object.assign(window, { ProofStrip, Testimonials, FAQ, FinalCTA, LandingFooter });
