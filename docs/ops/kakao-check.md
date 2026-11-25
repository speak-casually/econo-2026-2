# 카톡 "나에게 보내기" 수동 확인 결과 (BE-00)

확인일 2026-11-25 · 확인 방법: [1주차 계획 B0](../superpowers/plans/2026-11-25-week1-foundation-public-tree.md) Step 1~5, 우리 코드 없이 `curl`로 카카오 API 직접 호출 · 명세: [BE-00](../../backend/spec/BE-00-kakao-manual-check.md)

## 결론

**성공.** 카카오 API만으로 "나에게 보내기"와 refresh token 갱신 후 재발송이 된다. 12/25 개봉 알림 계획을 그대로 진행한다. 대체안(캘린더·홈 안내)으로 바꿀 필요 없음.

## 완료 조건

| 항목 | 결과 |
|---|---|
| 발송 응답 `{"result_code":0}`, "나와의 채팅"에 도착 | 통과 |
| 갱신한 access token으로 재발송 | 통과 |
| 메시지 링크를 누르면 등록한 도메인(`http://localhost:5173`)이 열림 | 통과 |

## 기록할 값

| 항목 | 값 | 의미 |
|---|---|---|
| `expires_in` (access token) | `21599`초 | 약 6시간 |
| `refresh_token_expires_in` | `5183999`초 | 약 60일. 11/25 발급분은 1월 말 만료, 12/25 알림까지 충분 |
| `scope` | `talk_message` | 선택 동의로 설정, 동의 화면에 "(선택) 카카오톡 메시지 전송"으로 표시 |
| `account_email` 사용 가능 여부 | **불가** | 일반 앱은 동의항목이 "권한 없음". 비즈 앱 전환이 필요하다 |

## 앱 설정 (카카오 디벨로퍼스)

- 사이트 도메인: `http://localhost:5173`
- 카카오 로그인 활성화, 로그인 Redirect URI: `http://localhost:5173/oauth-test`, `http://127.0.0.1:54321/auth/v1/callback`
  - "카카오 로그인 > 고급"의 **로그아웃** 리다이렉트 URI와 다르다. 로그아웃 쪽은 비워 둔다.
- Client Secret: 활성화
- 동의항목: 카카오톡 메시지 전송(`talk_message`) 선택 동의. 이메일은 권한 없음.

## 후속 작업에 넘길 것

- **BE-01 / FE-02 (카카오 로그인)**: Supabase 카카오 로그인은 기본으로 이메일을 요청한다. 이메일 권한이 없으므로 이메일 없이 로그인되는지 로컬 Supabase에서 확인한다. 안 되면 비즈 앱 전환을 신청한다.
- **BE-04 (토큰 저장)**: refresh 갱신 응답에 `refresh_token`이 없을 수 있다(만료 1개월 이내일 때만 새로 준다). 오면 교체하고, 없으면 기존 값을 유지한다.
- **스테이징·운영 도메인**: 도메인이 정해지면 사이트 도메인과 Redirect URI를 추가 등록한다. 메시지 링크는 등록된 도메인만 쓸 수 있다.

## 겪은 문제

- `KOE101 Not exist client_id`: 숨김 입력(`read -s`)에 REST API 키를 두 번 붙여 넣었다. `echo ${#KAKAO_REST_API_KEY}`로 길이(32)를 확인해 찾았다.
