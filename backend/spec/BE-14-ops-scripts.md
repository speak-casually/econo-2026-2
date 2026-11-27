# BE-14 운영 스크립트 (백업·리허설·정리·파기)

- 주차: 3주차 (12/9, 12/10 리허설, 12/16~17 복구 리허설) · 우선순위: P0
- 근거: 요구사항 12절, 기술 4.8·6절
- 선행: BE-10, BE-12, BE-13 · 이 작업을 쓰는 작업: 운영 전체

## 목적

계획의 운영 매뉴얼(추첨 실행, 알림 재발송, 신고 처리, 백업·복구)에 쓸 명령과 스크립트를 만들고, 스테이징에서 실제로 돌려 본다.

## 만들 것

**운영 매뉴얼** `docs/ops/runbook.md`: 아래 일정표와 각 명령을 복사해서 바로 쓸 수 있게 적는다.

| 시각 (KST) | 할 일 | 담당 |
|---|---|---|
| 12/20 | 운영 DB 정리(테스트 데이터 전부 삭제) → 첫 카드 준비 | BE |
| 12/21부터 매일 10:00·22:00 | 신고 확인·처리 | 신고 당번 |
| 12/24 23:59 직후 | 백업 → 추첨(실행 1명 + 확인 1명) → 결과 확인 | BE + 1명 |
| 12/25 11:00 | 자동 안전장치가 돌았는지 확인(`draws.mode = 'auto'` 행) | BE |
| 12/25 12:25 | 알림 발송 결과 확인 → 실패자 재발송 | BE |
| 2027-01-31 | 전체 파기 → 프로젝트 삭제 | BE |

**스크립트** (`backend/supabase/scripts/`)
- `backup.sh <project-ref>`: `supabase db dump`로 스키마와 데이터를 `backend/backups/<시각>/`에 저장한다. `backend/backups/`는 gitignore.
- `rehearsal_set_times.sql`: 스테이징 `app_config`를 마감 = 지금+10분, 개봉 = 지금+20분, 걸기 마감 = 지금+30분으로 바꾼다. `restore_times.sql`은 원래 세 시각으로 되돌린다.
- `draw_undo.sql`: 그룹 하나의 추첨을 되돌린다(`draws.assigned_box_ids`의 `recipient_id`를 비우고 `draws` 행 삭제).
- `reports.sql`: BE-13 함수 호출 예시(목록, 숨김, 프로필 초기화).
- `purge.ts`(Deno, service_role 키를 환경 변수로): Storage 세 버킷의 모든 파일을 Storage API로 지우고, `auth.users`를 전부 지운다(외래 키 cascade로 나머지 데이터도 지워진다). `--yes` 없이 실행하면 지울 개수만 출력하고 멈춘다. 12/20 정리와 1/31 파기에 같이 쓴다. SQL로 `storage.objects`를 지우면 파일이 남거나 막힐 수 있어서 Storage API를 쓴다.
- 알림 재발송: `curl`로 `send-open-notifications`에 `{"mode":"retry_failed"}`.

## 완료 조건

- [ ] 12/10 스테이징 리허설: `rehearsal_set_times.sql` → 선물 놓기 → 마감 → `backup.sh` → `run_draw()` → 개봉 → 알림 발송까지 하루 안에 끝나고, 소요 시간을 `docs/ops/week3-rehearsal.md`에 기록한다.
- [ ] `draw_undo.sql`로 한 그룹을 되돌린 뒤 다시 추첨하면 같은 시드로 같은 결과가 나온다.
- [ ] `purge.ts`를 `--yes` 없이 실행하면 아무것도 지우지 않는다. 스테이징에서 `--yes`로 실행하면 사용자 0명, 세 버킷 파일 0개.
- [ ] 12/16~17: 백업 파일을 로컬 Supabase에 복원해 카드·그룹·선물 수가 같은지 확인한다.

## 범위 밖

- 12/15 결정에 따른 자체 설치 이전 절차(필요해지면 이 매뉴얼에 추가)
