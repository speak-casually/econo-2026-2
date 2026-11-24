# BE-12 12/25 카톡 알림 발송

- 주차: 3주차 (12/7, 12/10 리허설) · 우선순위: P0
- 근거: 요구사항 10절, 기술 4.4절
- 선행: BE-04 · 이 작업을 쓰는 작업: BE-14

## 목적

12/25 12:25에 알림을 켠 사용자에게 카톡 "나에게 보내기"로 1통씩 보낸다. 실패한 사람에게만 다시 보낼 수 있다.

## 동작 규칙

- 대상: `user_settings.kakao_notify = true`이고 `kakao_tokens` 행이 있는 사람. 그룹 수, 받은 선물 유무와 상관없이 1인 1통.
- 이미 `sent`로 기록된 사람에게는 다시 보내지 않는다. 몇 번을 실행해도 1인 1통이다.
- `mode = "all"`: 아직 `sent`가 아닌 대상 전부. `mode = "retry_failed"`: `failed`인 사람만.
- 개봉 시각 전에는 `409 not_open_yet`으로 거부한다. 리허설은 스테이징의 `app_config.open_at`을 옮겨서 한다.
- 사람마다: 토큰 복호화 → 갱신(새 refresh token이 오면 저장) → 발송 → `notification_logs`에 `sent` 또는 `failed`(에러 원문)와 시도 횟수 기록. 한 사람의 실패가 다른 사람 발송을 막지 않는다.
- 동시에 5명씩 보낸다.
- 메시지: 본문 200자 이내(문구는 구현자 재량, 요구사항 15절). 링크는 `SITE_URL`(홈).
- 호출 권한: `Authorization: Bearer <service_role key>`만 허용한다. 사용자 JWT는 거부한다.
- Cron `25 3 25 12 *`(UTC, 12/25 12:25 KST)이 pg_net으로 이 함수를 `{"mode":"all"}`로 부른다. service_role 키는 Supabase Vault에 두고 Cron SQL에서 읽는다.

## 인터페이스

```sql
public.notification_logs(user_id uuid pk → auth.users on delete cascade, status text /* 'sent' | 'failed' */,
                         error text null, attempts int, updated_at timestamptz)  -- RLS 켬, 정책 없음
public.notification_targets() returns setof uuid  -- 대상 user_id. postgres·service_role만
cron job 'open-notifications': '25 3 25 12 *'
```

**`POST /functions/v1/send-open-notifications`**
- 본문 `{ "mode": "all" | "retry_failed" }`
- `200 { "sent": int, "failed": int, "skipped": int }`
- `401 { "error": "unauthorized" }`, `409 { "error": "not_open_yet" }`

## 완료 조건

- [ ] pgTAP `notification_targets.test.sql`: 토글이 꺼진 사람, 토큰이 없는 사람은 빠진다. 구글 로그인 사용자(토큰 없음)도 빠진다.
- [ ] 사용자 JWT로 부르면 `401`. 개봉 시각 전에는 `409`.
- [ ] 12/10 스테이징 리허설: 팀원 전원에게 메시지가 도착한다. 같은 함수를 한 번 더 부르면 `sent: 0`. 발송 소요 시간과 호출 수를 `docs/ops/week3-rehearsal.md`에 기록한다.
- [ ] 한 명의 토큰을 일부러 망가뜨리면 그 사람만 `failed`가 되고, `retry_failed`로 그 사람만 다시 시도된다.

## 범위 밖

- 알림 대체 수단(캘린더 추가, 홈 안내 배너, FE-16)
