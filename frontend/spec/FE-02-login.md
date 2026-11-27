# FE-02 로그인·인증 상태·인앱 탈출

- 주차: 1주차 (11/26) · 우선순위: P0 · 화면: ① · 계획: F2
- 근거: 요구사항 4.1절, 기술 3절(인앱 브라우저 탈출)·4.4절
- 선행: FE-01, BE-01, BE-04 · 이 작업을 쓰는 작업: 로그인이 필요한 모든 화면

## 목적

카카오·구글로 로그인하고, 카톡 인앱 브라우저에서 들어온 사용자를 외부 브라우저로 보낸다. 카카오 로그인 직후 알림용 토큰을 서버에 넘긴다.

## 화면과 동작 (①)

- 문구: "시작하기", "로그인하고 트리에 마음을 걸어요", 버튼 "카카오로 시작하기", "구글로 시작하기". 하단 "시작하면 서비스 이용약관과 개인정보 처리방침에 동의하게 돼요".
- **카톡 인앱 브라우저**면 상단에 "카톡 안에서 열었어요 → [외부 브라우저로 열기]". 누르면 `kakaotalk://web/openExternal?url=<지금 주소>`로 이동한다.
- **구글 버튼**: 인앱 브라우저(카톡 포함 모든 인앱)에서는 OAuth를 시작하지 않는다. 카톡이면 바로 외부 브라우저로 열고, 다른 인앱이면 "브라우저에서 열어 주세요" 안내를 띄운다. 구글이 웹뷰 로그인을 막기 때문이다(`disallowed_useragent`).
- 카카오 로그인은 `talk_message` 동의를 함께 요청한다(선택 동의).
- 로그인 후 돌아갈 곳: `/login?returnTo=` 값. 프로필이 없으면 먼저 `/profile/setup`.

## 인증 상태

- 앱 전체에서 `useAuth()`로 세션, 내 프로필, 카카오 메시지 동의 여부를 쓴다.
- 카카오 로그인 직후(`SIGNED_IN` 이벤트에 `provider_refresh_token`이 있을 때) `save-kakao-token`을 부르고, 응답의 `talk_message`를 `kakaoMessageConsent`에 둔다. 이 호출이 실패해도 로그인은 계속된다.
- 가드: `<RequireAuth>`는 비로그인을 `/login?returnTo=<현재 경로>`로, `<RequireProfile>`은 프로필이 없는 사용자를 `/profile/setup`으로 보낸다.

## 사용하는 백엔드

- Supabase Auth(`signInWithOAuth`, provider `kakao`·`google`, `redirectTo = <origin>/auth/callback`)
- `profiles`(본인 행), `POST /functions/v1/save-kakao-token`(BE-04)

## 만드는 것

- `detectInAppBrowser(ua: string): 'kakaotalk' | 'other' | null` (`KAKAOTALK` / `Instagram`, `FBAN`, `FBAV`, `Line/`, `NAVER(inapp`)
- `kakaoExternalUrl(url: string): string`
- `safeReturnTo(raw: string | null): string`: `/`로 시작하고 `//`, `/\`로 시작하지 않는 경로만, 아니면 `/`
- `useAuth(): { session, profile, loading, kakaoMessageConsent: boolean | null, refreshProfile() }`
- `signInWithKakao(returnTo: string)`, `signInWithGoogle(returnTo: string)`, `signOut()`
- `RequireAuth`, `RequireProfile`, `LoginPage`, `AuthCallbackPage`

## 완료 조건

Vitest:
- [ ] `detectInAppBrowser`: 카톡 UA → `kakaotalk`, 인스타그램 UA → `other`, 사파리 UA → `null`
- [ ] `kakaoExternalUrl("https://a.vercel.app/g/ab12?x=1")` → `kakaotalk://web/openExternal?url=https%3A%2F%2Fa.vercel.app%2Fg%2Fab12%3Fx%3D1`
- [ ] `safeReturnTo`: `/cards/new` → 그대로, `//evil.com`·`/\evil.com`·`https://evil.com`·`null` → `/`

직접 확인:
- [ ] 카카오 로그인 동의 화면에 "카카오톡 메시지 전송(선택)"이 보이고, 로그인 후 `kakao_tokens`에 1행이 생긴다.
- [ ] 카톡으로 받은 링크를 열면 외부 브라우저로 넘어갈 수 있다.
- [ ] 인앱에서 구글 버튼을 눌러도 구글 오류 화면이 뜨지 않는다.

## 범위 밖

- 프로필 설정 화면(FE-03)
