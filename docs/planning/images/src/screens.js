// 화면 목업. id → { title, back, body, cap, desc, review }
// 버전: ?v=santa (기본) | ?v=fairy  — ⑦ 그룹 홈만 다름
const V = new URLSearchParams(location.search).get('v') || 'santa';
document.documentElement.className = 'v-' + V;
const img = (w, h, extra = '') => `<div class="img" style="width:${w}px;height:${h}px;${extra}"></div>`;
const lines = (...ws) => ws.map(w => `<div class="line" style="width:${w}%"></div>`).join('');
const av = (extra = '') => `<span class="av" style="display:inline-block;${extra}"></span>`;
const tree = (h, deco = '') => `<div style="position:relative;width:${h * 0.8}px;height:${h}px;margin:0 auto">
  <div style="position:absolute;inset:0;background:#dcfce7;border:2px solid #16a34a;clip-path:polygon(50% 0,100% 88%,0 88%)"></div>
  <div style="position:absolute;left:44%;width:12%;bottom:0;height:12%;background:#d1d5db;border:1px solid #6b7280"></div>${deco}</div>`;
const cardDeco = (l, t, glow) => `<div style="position:absolute;left:${l}%;top:${t}%;width:20px;height:16px;background:#fff;border:1.5px solid #374151;border-radius:3px;${glow ? `box-shadow:0 0 ${glow}px ${glow / 2}px #fbbf24;` : ''}"><span class="av" style="position:absolute;width:8px;height:8px;right:-3px;bottom:-3px;border-width:1px"></span></div>`;
const house = (l, t, name, extra = '') => `<div style="position:absolute;left:${l}px;top:${t}px;text-align:center;font-size:8px;${extra}">
  <div style="width:30px;height:22px;margin:0 auto;background:#fff;border:1.5px solid #374151;clip-path:polygon(50% 0,100% 45%,100% 100%,0 100%,0 45%)"></div>${name}</div>`;

const SCREENS = {
  s0: { title: '🎄 공개 트리', cap: '⓪ 홈 = 공개 트리', desc: '카드 50장 무작위 · 좋아요 5+ 반짝임<br>비로그인도 열람', body: `
    <div class="t" style="font-weight:700;color:#111">지금까지 걸린 마음 128개 · D-5</div>
    <div style="height:8px"></div>${tree(250, cardDeco(42, 18, 6) + cardDeco(28, 40) + cardDeco(55, 38, 10) + cardDeco(20, 60) + cardDeco(40, 58) + cardDeco(62, 62, 4) + cardDeco(32, 75) + cardDeco(55, 76))}
    <div class="t9">카드마다 작성자 프로필 아이콘 · 반짝임 = 좋아요 5/20/50</div>
    <div class="btn">카드 걸기</div>
    <div class="row" style="margin-top:6px"><div class="btn2">전체 보기</div><div class="btn2">내 그룹</div></div>
    <div class="pill" style="margin-top:6px">🔔 캐롤 켜기</div>` },

  s0e: { title: '🎄 공개 트리', edge: true, cap: '⓪ 예외: 카드가 적을 때', desc: '첫날 콜드 스타트 · 빈 칸은 장식 자리로<br>팀원·베타 카드 먼저 걸기', body: `
    <div class="t" style="font-weight:700;color:#111">지금까지 걸린 마음 3개 · D-4</div>
    <div style="height:8px"></div>${tree(250, cardDeco(42, 30) + cardDeco(30, 58) + cardDeco(56, 62))}
    <div class="notice" style="text-align:center">첫 카드를 걸어 트리를 채워 주세요</div>
    <div class="btn">카드 걸기</div>` },

  s1: { title: '로그인', cap: '① 로그인', desc: '카카오·구글 OAuth<br>카톡 인앱 → 외부 브라우저', body: `
    <div class="notice" style="text-align:center">카톡 안에서 열렸어요 → [외부 브라우저로 열기]</div>
    <div style="height:30px"></div>${img(90, 90)}${lines(70, 45)}
    <div class="t9" style="margin-top:70px">로그인하고 마음을 남겨요</div>
    <div class="btn2" style="margin-top:6px;background:#fef3c7">카카오로 시작하기</div>
    <div class="btn2" style="margin-top:6px">구글로 시작하기</div>` },

  s1a: { title: '프로필 설정', back: true, cap: '①-a 프로필 설정 (첫 가입)', desc: '닉네임 12자 · 사진 올리기 또는 기본 이미지<br>동의 2개 · 카톡 알림', body: `
    <div style="width:70px;height:70px;border-radius:50%;margin:6px auto;background:#e5e7eb;border:2px solid #6b7280"></div>
    <div class="row" style="gap:4px"><div class="pill">사진 올리기</div><div class="pill">건너뛰기(기본)</div></div>
    <div class="t9">모든 사람에게 보여요</div>
    <div class="input" style="margin-top:8px">닉네임 (12자)</div>
    <div class="t" style="text-align:left;margin-top:10px">☐ 개인정보 수집·이용 (필수)<br>☐ 만 14세 이상 (필수)</div>
    <div class="card" style="font-size:9.5px;justify-content:space-between"><span>12/25 카톡 개봉 알림</span><span class="tag">켜기</span></div>
    <div class="btn" style="margin-top:14px">시작하기</div>
    <div class="t9" style="margin-top:6px">모든 데이터는 2027-01-31에 삭제돼요</div>` },

  s2: { title: '카드 꾸미기', back: true, cap: '② 카드 꾸미기', desc: '앞면 = 기본 카드 or 직접 그리기 + 스티커<br>뒷면 = 편지 300자 · 1인 1장', body: `
    <div class="tabs"><span class="on">앞면</span><span>뒷면(편지)</span></div>
    <div class="tabs" style="margin-top:6px"><span class="on">기본 카드</span><span>직접 그리기</span></div>
    <div style="height:8px"></div>${img(150, 120)}
    <div class="row" style="margin-top:8px;gap:4px">${[1, 2, 3, 4].map(() => img(36, 36, 'margin:0')).join('')}</div>
    <div class="t9" style="margin-top:6px">스티커 ⭐ 🎀 ❄ 🔔 (최대 20)</div>
    <div class="panel" style="padding:6px;margin-top:6px;font-size:9px">직접 그리기: 펜 굵기 3 · 색 8 · 지우개 · 되돌리기</div>
    <div class="row"><div class="btn2" style="margin-top:8px">미리보기</div><div class="btn">트리에 걸기</div></div>` },

  s3: { title: '카드 보기', back: true, cap: '③ 카드 보기', desc: '좌우 화살표로 다음 사람 카드(무작위)<br>♥ 1인 1카드 1회 · 아이콘 → 작성자 프로필', body: `
    <div class="row" style="align-items:center;gap:4px"><span style="flex:0;font-size:18px">‹</span>${img(160, 200, 'flex:0 0 160px')}<span style="flex:0;font-size:18px">›</span></div>
    <div class="t9">탭하면 뒤집혀 편지</div>
    <div class="card" style="justify-content:space-between"><span style="display:flex;align-items:center;gap:6px">${av()}<b style="font-size:10px">민지</b></span><span style="font-size:11px">♥ 12</span></div>
    <div class="row" style="margin-top:6px"><div class="btn2">♥ 좋아요</div><div class="btn2">신고</div></div>
    <div class="modal" style="bottom:12px"><div style="display:flex;gap:8px;align-items:center">${av('width:34px;height:34px')}<div><b style="font-size:10px">작성자 프로필</b><div class="t9" style="text-align:left">민지 · [프로필 신고]</div></div></div></div>` },

  s4: { title: '카드 목록', back: true, cap: '④ 카드 목록', desc: '무작위(기본) / 좋아요순 / 최신순', body: `
    <div class="tabs"><span class="on">무작위</span><span>좋아요순</span><span>최신순</span></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:10px">
    ${[1, 2, 3, 4, 5, 6].map(i => `<div>${img(100, 80)}<div class="t9" style="display:flex;justify-content:space-between;padding:2px 4px">${av('width:10px;height:10px')}<span>닉네임</span><span>♥${i * 3}</span></div></div>`).join('')}</div>` },

  s5: { title: '그룹 만들기', back: true, cap: '⑤ 그룹 만들기', desc: '이름 20자 · 개수 제한 없음<br>만든 사람 = 일반 멤버', body: `
    <div class="input" style="margin-top:20px">그룹 이름 (20자)</div>
    <div class="btn">만들기</div>
    <div class="modal" style="bottom:12px"><b style="font-size:10px">초대 링크</b><div class="input" style="margin-top:4px">example.com/g/xY7k…</div>
      <div class="row" style="margin-top:6px;gap:4px"><div class="pill">복사</div><div class="pill">카카오톡</div><div class="pill">더보기</div></div></div>` },

  s6: { title: '초대', cap: '⑥ 초대 랜딩 /g/{code}', desc: '그룹 이름 · 멤버 수만 보임<br>정원 30 · 12/24 23:59까지 참여', body: `
    <div style="height:30px"></div>${img(110, 90)}
    <div class="t" style="font-weight:700;color:#111;margin-top:12px">[우리 동아리 크리스마스]에<br>초대받았어요</div>
    <div class="t9">멤버 12명 · 12/25 12:25에 선물이 열려요</div>
    <div class="btn" style="margin-top:30px">참여하기</div>` },

  s6x: { title: '초대', edge: true, cap: '⑥ 예외: 가득 참 · 마감', desc: '정원 30 초과 / 12/24 23:59 이후<br>공개 트리로 안내', body: `
    <div style="height:30px"></div>${img(110, 90)}
    <div class="t" style="font-weight:700;color:#111;margin-top:12px">[우리 동아리 크리스마스]</div>
    <div class="notice" style="text-align:center;margin-top:14px">가득 찼어요 (30명)</div>
    <div class="t9">또는 "참여가 마감됐어요"</div>
    <div class="btn2" style="margin-top:30px">공개 트리 보러 가기</div>` },

  s7: { title: '우리 동아리 ▾', review: true, cap: '⑦ 그룹 홈 = 하늘 지도', desc: '산타 썰매 시점 · 집 = 멤버<br>멤버 수만큼 넓어지는 지도 · 숫자 표시 없음', body: `
    <div class="row" style="justify-content:space-between;font-size:9px"><span class="t9" style="text-align:left">D-5 · 12/25 12:25 개봉</span><span class="pill" style="flex:0 0 auto">목록 보기</span></div>
    <div style="position:relative;height:300px;margin-top:6px;background:#eef2ff;border:1px solid #c7d2fe;border-radius:8px;overflow:hidden">
      <div style="position:absolute;left:8px;top:6px;font-size:16px">🛷</div>
      ${house(20, 50, '민지') + house(90, 40, '서준') + house(160, 60, '하은') + house(40, 130, '지호') + house(115, 120, '<b>내 집</b>') + house(175, 150, '유나') + house(25, 210, '도윤') + house(100, 220, '수아') + house(170, 230, '…')}
      <div style="position:absolute;bottom:4px;width:100%;text-align:center" class="t9">드래그해서 둘러보기</div></div>
    <div class="btn">🎁 마니또 선물 떨어뜨리기</div>
    <div class="pill" style="margin-top:6px">초대하기</div>` },

  s7e: { title: '민지님의 집', back: true, review: true, cap: '⑦-E 집 내부', desc: '썰매 이동 0.8초(탭하면 건너뛰기)<br>트리 아래 상자는 그림으로만 · 숫자 없음', body: `
    <div style="height:6px"></div>${tree(180, '')}
    <div class="row" style="justify-content:center;gap:6px;margin-top:-10px">${['#fecaca', '#dbeafe', '#fef3c7'].map(c => `<div style="flex:0 0 26px;height:22px;background:${c};border:1.5px solid #374151;border-radius:3px;font-size:9px;text-align:center">🔒</div>`).join('')}</div>
    <div class="t9" style="margin-top:6px">보낸 사람·속은 12/25 12:25까지 잠김</div>
    <div class="btn" style="margin-top:16px">선물 상자 만들기</div>
    <div class="t9" style="margin-top:6px">이미 보냈으면 → "이미 보냈어요 · 수정할까요?"</div>
    <div class="t9">보내면 상자가 트리 아래로 내려앉는 연출(1.5초)</div>` },

  s7f: { title: '우리 동아리 ▾', review: true, cap: '⑦ 그룹 홈 = 요정', desc: '멤버마다 요정이 무작위로 날아다님<br>요정 탭 → 선물상자 만들기 창 · 숫자 표시 없음', body: `
    <div class="t9" style="text-align:left">D-5 · 12/25 12:25 개봉</div>
    <div style="position:relative;height:290px;margin-top:4px">
      ${tree(200, '')}
      <div class="row" style="justify-content:center;gap:6px;margin-top:-14px">${['#fecaca', '#dbeafe', '#fef3c7'].map(c => `<div style="flex:0 0 24px;height:20px;background:${c};border:1.5px solid #374151;border-radius:3px;font-size:8px;text-align:center">🔒</div>`).join('')}</div>
      ${[[10, 20], [175, 10], [20, 140], [180, 120], [60, 230], [165, 225]].map(([l, t]) => `<div style="position:absolute;left:${l}px;top:${t}px;font-size:14px">🧚<span class="av" style="position:absolute;width:10px;height:10px;right:-6px;top:-2px;border-width:1px"></span></div>`).join('')}
      <div class="modal" style="top:70px"><div style="display:flex;gap:6px;align-items:center">${av('width:22px;height:22px')}<b style="font-size:10px">민지님에게 선물상자를<br>만들까요?</b></div>
        <div class="row" style="margin-top:6px;gap:4px"><div class="btn" style="margin:0;padding:5px">만들기</div><div class="btn2">닫기</div></div><div class="t9" style="margin-top:4px">프로필 신고</div></div>
    </div>
    <div class="row" style="gap:4px;margin-top:4px"><div class="btn" style="margin:0">🎁 마니또 보내기</div></div>
    <div class="row" style="gap:4px;margin-top:6px"><div class="pill">멤버 보기</div><div class="pill">초대하기</div></div>` },

  s8: { title: '선물상자 꾸미기', back: true, cap: '⑧ 선물상자 꾸미기', desc: '지정 or 마니또 · 겉: 색·스티커<br>속: 편지·사진 5·음반 1곡 중 1개 이상', body: `
    <div class="card sel" style="font-size:9.5px">◉ 민지님에게</div>
    <div class="card" style="font-size:9.5px">○ 마니또 · 마감 후 그룹 안 한 명에게</div>
    <div style="height:6px"></div>${img(110, 80)}
    <div class="row" style="margin-top:6px;gap:4px"><div class="pill">상자 색</div><div class="pill">리본 색</div><div class="pill">스티커</div></div>
    <div class="tabs" style="margin-top:8px"><span>편지</span><span>사진</span><span class="on">음반</span></div>
    <div class="input" style="margin-top:6px">YouTube 링크 붙여넣기</div>
    <div class="card">${img(30, 30, 'margin:0')}<div style="flex:1">${lines(80, 50)}</div></div>
    <div class="t9" style="margin-top:4px">결제 없음 · 사진만 전달 · 기프티콘 비보증</div>
    <div class="btn">보내기</div>` },

  s9: { title: '🎁 개봉', cap: '⑨ 개봉 (12/25 12:25~)', desc: (V === 'fairy' ? '받은 상자를 하나씩 열기' : '내 집 트리 아래 상자를 하나씩 열기') + '<br>마니또는 열 때 공개 · 고마워요 답장', body: `
    <div class="t9">우리 동아리 · 받은 선물</div>
    <div class="row" style="justify-content:center;gap:6px;margin-top:6px">${['#fecaca', '#dbeafe', '#fef3c7', '#dcfce7'].map(c => `<div style="flex:0 0 30px;height:26px;background:${c};border:1.5px solid #374151;border-radius:3px"></div>`).join('')}</div>
    <div class="panel" style="margin-top:8px;padding:8px">
      <div class="notice" style="margin:0;text-align:center">🎁 마니또는 서준님이었어요</div>
      <div style="margin-top:6px">${lines(90, 85, 60)}</div>
      <div class="row" style="gap:4px;margin-top:6px">${img(50, 40, 'margin:0')}${img(50, 40, 'margin:0')}</div>
      <div class="card" style="margin-top:6px">▶ ${img(30, 22, 'margin:0')}<div style="flex:1">${lines(70)}</div></div>
      <div class="t9">광고가 나올 수 있어요 · 재생 중 캐롤 멈춤</div></div>
    <div class="input" style="margin-top:8px">고마워요 한 줄 (50자)</div>` },

  s9e: { title: '🎁 개봉', edge: true, cap: '⑨ 예외: 받은 상자 0개', desc: '빈 상태 + 공개 트리 안내<br>마니또 미전달은 보낸 사람에게 안내', body: `
    <div class="t9">우리 동아리 · 받은 선물</div>
    <div style="height:40px"></div>${img(90, 70)}
    <div class="t" style="font-weight:700;color:#111;margin-top:10px">아직 받은 상자가 없어요</div>
    <div class="t9">공개 트리에 걸린 마음을 읽어 보세요</div>
    <div class="btn2" style="margin-top:14px">공개 트리로</div>
    <div class="notice" style="margin-top:24px">내 마니또 선물은 받을 사람이 없어 전달되지 않았어요</div>` },

  s10: { title: '마이페이지', back: true, cap: '⑩ 마이페이지', desc: '프로필 · 내 카드 · 내 그룹 · 알림', body: `
    <div class="card" style="font-size:10px">${av('width:30px;height:30px')}<div style="flex:1"><b>닉네임</b><div class="t9" style="text-align:left">사진 바꾸기 · 기본으로</div></div></div>
    <div style="font-size:10.5px;font-weight:700;margin-top:12px">내 카드</div>
    <div class="card" style="font-size:9.5px;justify-content:space-between">${img(26, 26, 'margin:0;flex:0 0 26px')}<span style="flex:1">공개 트리에 걸린 카드</span><span>♥ 12</span></div>
    <div style="font-size:10.5px;font-weight:700;margin-top:12px">내 그룹</div>
    ${['우리 동아리', '가족'].map(n => `<div class="card" style="font-size:9.5px;justify-content:space-between"><span>${n}</span><span class="muted">›</span></div>`).join('')}
    <div class="btn2" style="margin-top:6px">+ 그룹 만들기</div>
    <div class="card" style="font-size:9.5px;justify-content:space-between;margin-top:12px"><span>12/25 카톡 개봉 알림</span><span class="tag">켜짐</span></div>
    <div class="t9" style="margin-top:8px">탈퇴 기능 없음 · 2027-01-31 일괄 삭제</div>` },
};

function phone(id, { mark = true } = {}) {
  const s = SCREENS[id];
  return `<div class="phone"><div class="frame">
    ${s.review && mark ? '<div class="review">디자인 검토 중</div>' : ''}${s.edge ? '<div class="review" style="background:#6b7280">예외 화면</div>' : ''}
    <div class="bar">${s.back ? '<span class="l">←</span>' : ''}${s.title}<span class="r">🔔</span></div>${s.body}</div>
    <div class="cap"><b>${s.cap}</b><div>${s.desc}</div></div></div>`;
}
