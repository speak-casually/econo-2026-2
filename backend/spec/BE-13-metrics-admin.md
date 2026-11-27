# BE-13 지표와 관리자 기능

- 주차: 3주차 (12/8) · 우선순위: P0 (지표) / P1 (관리 화면용 기능)
- 근거: 요구사항 5.5절·12절·13절, 기술 4.6절
- 선행: BE-03, BE-10, BE-11 · 이 작업을 쓰는 작업: FE-17, BE-14

## 목적

성공 지표를 한 번에 계산하고, 신고 처리와 현황 확인을 SQL 없이 할 수 있는 관리자 기능을 만든다. 모든 함수는 관리자만 쓴다.

## 동작 규칙

- 관리자가 아니면 `forbidden`.
- **지표** (분모 두 가지 모두 계산)

| 지표 | 분자 | 분모 A | 분모 B |
|---|---|---|---|
| `card_rate` | 카드를 건 사용자 | 전체 가입자(`profiles`) | 홈을 연 가입자(`first_home_visit_at` 있음) |
| `gift_sent_rate` | 선물을 1개 이상 보낸 사용자 | 전체 가입자 | 그룹 멤버인 사용자 |
| `groups_all_sent` | 모든 멤버가 1개 이상 보낸 그룹 | 2명 이상 그룹 | 같음 |
| `groups_all_received` | 모든 멤버가 1개 이상 받은 그룹(추첨 후 기준) | 2명 이상 그룹 | 같음 |
| `open_rate` | `opened_at`이 있는 상자 | 받는 사람이 있는 상자 | 같음 |

- **신고 목록**: 대상별로 묶어 신고 수, 처음·마지막 신고 시각, 대상 미리보기(카드 편지 앞 50자 또는 닉네임), 현재 숨김 여부를 준다. 신고 많은 순.
- **카드 숨김·해제**: `hidden`을 바꾼다.
- **프로필 초기화**: 사진을 비우고 닉네임을 "숨김 사용자"로 바꾼다(요구사항 5.5절).
- **그룹 현황**: 그룹마다 이름, 멤버 수, 상자 수, 마니또 상자 수, 추첨 여부(`draws` 유무와 mode). 관리자 전용이라 개수를 보여줘도 된다.

## 인터페이스

```sql
public.admin_metrics() returns table (metric text, basis text /* 'A' | 'B' */, numerator int, denominator int)
public.admin_list_reports() returns table (target_type text, target_id uuid, report_count int,
       first_reported_at timestamptz, last_reported_at timestamptz, preview text, hidden boolean)
public.admin_set_card_hidden(p_card_id uuid, p_hidden boolean) returns void
public.admin_reset_profile(p_user_id uuid) returns void
public.admin_group_status() returns table (group_id uuid, name text, member_count int, box_count int,
       manito_count int, draw_mode text /* null이면 미추첨 */)
```

모두 `security definer`이고 첫 줄에서 `public.is_admin()`을 확인한다.

## 완료 조건

`backend/supabase/tests/database/metrics_admin.test.sql`:
- [ ] 일반 사용자가 다섯 함수를 부르면 모두 `forbidden`.
- [ ] 준비 데이터(가입자 4명, 카드 2장, 홈 방문 3명)에서 `card_rate`는 A가 2/4, B가 2/3.
- [ ] 2명 그룹에서 한 명만 선물을 보냈으면 `groups_all_sent`의 분자는 0, 둘 다 보내면 1.
- [ ] 신고 2건이 들어온 카드는 `report_count = 2`로 한 줄에 나온다.
- [ ] `admin_set_card_hidden(id, true)` 후 비로그인은 그 카드를 못 본다.
- [ ] `admin_reset_profile` 후 닉네임은 "숨김 사용자", 사진은 null.

## 범위 밖

- 관리 화면(FE-17). 화면 전에는 대시보드 SQL 편집기에서 이 함수들을 직접 부른다.
