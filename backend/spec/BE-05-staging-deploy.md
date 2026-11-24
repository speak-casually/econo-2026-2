# BE-05 스테이징 환경·배포 자동화

- 주차: 1주차 (11/26) · 우선순위: P0 · 계획: B5
- 근거: 기술 5절·6절
- 선행: BE-01 · 이 작업을 쓰는 작업: 모든 통합 확인, FE-01(Vercel 환경 변수)

## 목적

실기기·카톡 인앱 브라우저·실제 카카오 발송은 로컬에서 확인할 수 없다. 스테이징 Supabase 프로젝트를 만들고, `develop`에 머지하면 DB와 함수가 자동으로 배포되게 한다.

## 동작 규칙

- 프로젝트 2개: 스테이징(지금), 운영(12/19 배포 전에 만든다). 리전은 서울.
- `develop` 머지 → 스테이징에 `supabase db push` + `supabase functions deploy`. `main` 머지 → 운영. 운영 ref가 없으면 건너뛴다.
- 스키마는 마이그레이션 파일로만 바꾼다. 대시보드에서 직접 고치지 않는다.
- 비밀 값은 GitHub Secrets와 Supabase 함수 secrets에만 둔다. 레포에 올리지 않는다.
- **12/24 ~ 12/25 배포 금지.** 12/18 코드 동결 후에는 버그 수정만.

## 설정할 것

- Supabase Auth: 카카오·구글 provider, Site URL(Vercel 스테이징 주소), Redirect URLs(`<스테이징>/auth/callback`, `http://localhost:5173/auth/callback`)
- 카카오 디벨로퍼스: Redirect URI `https://<ref>.supabase.co/auth/v1/callback`, Web 사이트 도메인에 Vercel 스테이징 주소
- 구글 Cloud: OAuth 웹 클라이언트, 승인된 리디렉션 URI에 같은 Supabase 콜백. 동의 화면 "게시" 소요 기간 확인
- 함수 secrets: `KAKAO_REST_API_KEY`, `KAKAO_CLIENT_SECRET`, `TOKEN_ENC_KEY`, `SITE_URL`
- GitHub Secrets: `SUPABASE_ACCESS_TOKEN`, `STAGING_PROJECT_REF`, `STAGING_DB_PASSWORD`, `PROD_PROJECT_REF`, `PROD_DB_PASSWORD`

## 인터페이스

- `.github/workflows/deploy-db.yml` (작업 디렉터리 `backend`)
- `docs/ops/environments.md`: 프로젝트 ref, 주소, 콘솔에 등록한 값 목록(비밀 값 제외), 구글 게시 소요 기간
- 프론트에 넘기는 값: 스테이징 `SUPABASE_URL`, `anon key`

## 완료 조건

- [ ] `develop` 머지 후 Actions 로그에 `Finished supabase db push.`와 함수 배포가 보인다.
- [ ] 스테이징 대시보드에 BE-01~04의 테이블이 있다.
- [ ] Vercel 스테이징 주소에서 카카오·구글 로그인이 된다(FE-02와 함께 확인).

## 범위 밖

- 운영 프로젝트 생성과 운영 도메인 확정(3주차, 12/19 배포 전)
