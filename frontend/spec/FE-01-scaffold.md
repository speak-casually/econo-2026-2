# FE-01 프로젝트 뼈대·공용 유틸

- 주차: 1주차 (11/25) · 우선순위: P0 · 계획: F1
- 근거: 기술 3절(프론트엔드·호스팅)
- 선행: 없음 (BE-01 전에는 가짜 데이터) · 이 작업을 쓰는 작업: 모든 FE 작업

## 목적

React 앱의 뼈대, 라우트, Supabase 클라이언트, 그리고 여러 화면이 함께 쓰는 시각·글자 수 유틸을 만든다.

## 화면과 동작

- 공통 레이아웃: 상단 바(왼쪽 🎄 "Christmas Gift For You", 오른쪽 "내 그룹" 버튼과 🔔 자리). 🔔는 FE-14에서 채운다. "내 그룹" 동작은 FE-09에서 정한다.
- [README의 라우트 표](README.md#라우트)에 있는 경로를 모두 만든다. 아직 없는 화면은 빈 페이지로 둔다.
- 없는 경로는 "페이지를 찾을 수 없어요"와 홈 버튼.

## 만드는 것

- `src/lib/supabase.ts`: `supabase: SupabaseClient<Database>` (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`)
- `src/lib/database.types.ts`: `frontend/`에서 `supabase gen types typescript --local --workdir ../backend > src/lib/database.types.ts`로 생성. 백엔드 마이그레이션이 머지될 때마다 다시 생성한다.
- `src/lib/time.ts`
  - `type AppConfig = { deadlineAt: Date; openAt: Date; treeDeadlineAt: Date }`
  - `fetchAppConfig(): Promise<AppConfig>` (앱 시작 시 한 번 읽고 공유)
  - `dDayKst(now: Date): number`: KST 달력 기준으로 12/25까지 남은 날 수
- `src/lib/text.ts`: `countChars(s: string): number` (코드 포인트 수, `[...s].length`)
- `vercel.json`: 모든 경로를 `index.html`로 rewrite
- `.env.example`: 변수 이름만
- CI(`.github/workflows/ci.yml`): `frontend/**` 변경 시 `npm ci`, `lint`, `typecheck`, `test`, `build`
- Vercel 프로젝트: Root Directory `frontend`, Production Branch `main`, `develop`은 스테이징 주소. 환경 변수는 BE-05의 스테이징 값

## 완료 조건

Vitest:
- [ ] `dDayKst`: `2026-12-20T15:00:00Z` → 4, `2026-12-24T14:59:59Z` → 1, `2026-12-24T15:00:00Z` → 0, `2026-12-25T15:00:00Z` → -1
- [ ] `countChars("🎄🎄")` → 2, `countChars("메리 크리스마스")` → 8

직접 확인:
- [ ] `npm run build` 성공, Vercel 스테이징 주소에서 새로고침해도 404가 나지 않는다(`/cards/abc` 등).

## 범위 밖

- 캐롤(FE-14), 각 화면 내용
