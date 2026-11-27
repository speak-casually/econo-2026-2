# BE-04 카카오 토큰 저장·테스트 발송

- 주차: 1주차 (11/26) · 우선순위: P0 · 계획: B4
- 근거: 요구사항 4.2·10절, 기술 4.4절
- 선행: BE-01, BE-00 · 이 작업을 쓰는 작업: FE-02, FE-03, BE-12

## 목적

12/25에 카톡을 보내려면 사용자의 카카오 refresh token이 필요하다. Supabase는 이 토큰을 보관해 주지 않고 로그인 직후에만 준다. 그래서 로그인 직후 받아서 암호화해 저장하고, 실제로 보낼 수 있는지 시험하는 함수를 만든다.

## 동작 규칙

- 토큰은 AES-GCM(256비트)으로 암호화해 `kakao_tokens`에 저장한다. 키는 함수 secret `TOKEN_ENC_KEY`에 둔다. 매번 새 IV를 쓴다.
- `kakao_tokens`는 RLS를 켜고 정책을 두지 않는다. 클라이언트는 읽지도 쓰지도 못하고, Edge Function(`service_role`)만 접근한다.
- 저장 전에 토큰이 진짜인지 확인한다: 토큰을 한 번 갱신하고, 카카오 회원번호가 로그인한 사용자의 카카오 identity와 같은지 본다. 다르면 저장하지 않는다.
- 갱신 응답에 새 refresh token이 오면(만료 1개월 미만일 때) 그것을 저장한다.
- 사용자가 다시 로그인하면 기존 행을 덮어쓴다(사용자당 1행).
- `talk_message` 동의 여부를 함께 돌려준다. 프론트는 이것으로 재동의를 안내한다.
- 테스트 발송은 관리자만, 호출한 본인에게만 보낸다.

## 인터페이스

```sql
public.kakao_tokens(user_id uuid pk → auth.users on delete cascade, kakao_user_id text,
                    enc_refresh_token text, iv text, updated_at timestamptz)
```

**`POST /functions/v1/save-kakao-token`**
- 헤더 `Authorization: Bearer <사용자 JWT>`, 본문 `{ "refresh_token": string }`
- `200 { "ok": true, "talk_message": boolean }`
- `400 { "error": "missing_token" }`, `401 { "error": "unauthorized" }`, `403 { "error": "kakao_user_mismatch" }`, `502 { "error": "kakao_refresh_failed" }`

**`POST /functions/v1/send-kakao-test`**
- 관리자만. 본인에게 지금 1통.
- `200 { "ok": true }`, `403 { "error": "forbidden" }`, `404 { "error": "no_token" }`, `502 { "error": "kakao_send_failed" }`

**공용 모듈** (BE-12도 쓴다)
- `_shared/crypto.ts`: `encryptToken(plain, keyB64) → { ciphertext, iv }`, `decryptToken(ciphertext, iv, keyB64) → string`
- `_shared/kakao.ts`: `refreshKakaoToken(refreshToken) → { accessToken, refreshToken | null }`, `fetchKakaoUserId(accessToken) → string`, `hasTalkMessageScope(accessToken) → boolean`, `buildMemoTemplate(text, url) → string`(본문 200자로 자름), `sendKakaoMemo(accessToken, templateJson) → void`

함수 secrets: `KAKAO_REST_API_KEY`, `KAKAO_CLIENT_SECRET`, `TOKEN_ENC_KEY`(base64 32바이트), `SITE_URL`.

## 완료 조건

- [ ] `deno test backend/supabase/functions/_shared/` 통과: 암호화 왕복, 매번 다른 IV, 틀린 키로 복호화 실패, 메모 템플릿 형식, 250자 본문이 200자로 잘림.
- [ ] 로컬에서 anon 키로 `save-kakao-token`을 부르면 `401`.
- [ ] 스테이징에서 카카오 로그인 후 `kakao_tokens`에 1행이 생기고, 관리자 계정으로 `send-kakao-test`를 부르면 메시지가 도착한다(통합 확인에서).
- [ ] 같은 계정으로 다시 로그인해도 행은 1개다.

## 범위 밖

- 12/25 일괄 발송, 발송 기록, 재발송(BE-12)
