# BE-10 마니또 추첨과 자동 안전장치

- 주차: 2주차 (12/4~12/5) · 우선순위: P0
- 근거: 요구사항 8.2절, 기술 4.3절
- 선행: BE-07, BE-08 · 이 작업을 쓰는 작업: BE-11, BE-13, BE-14, FE-09

## 목적

마감 후 마니또 선물의 받는 사람을 정한다. 아무것도 못 받는 멤버를 줄이는 것이 목표다. 사람이 실행을 놓쳐도 12/25 11:00에 자동으로 실행된다.

## 동작 규칙

**실행**
- 마감 전에는 `draw_before_deadline`을 내고 아무것도 하지 않는다.
- 추첨 기록(`draws`)이 없는 그룹만 처리한다. 이미 처리한 그룹은 다시 실행해도 그대로다.
- 그룹마다 시드를 정하고(인자로 주지 않으면 무작위) `draws`에 기록한다. 같은 시드면 같은 결과가 나온다.
- 무작위 순서와 동률 처리는 `md5(시드 || id)` 정렬로 정한다. `random()`을 쓰지 않아 실행 환경과 상관없이 재현된다.
- 배정한 상자 id와 미전달 상자 id를 `draws`에 남긴다. 이것이 자동 실행의 백업이다. 되돌릴 때는 배정한 상자의 `recipient_id`를 비우고 `draws` 행을 지운다(BE-14).
- 실행 권한은 `postgres`(대시보드 SQL 편집기)와 Cron만. 클라이언트 역할에서 execute를 회수한다.
- 한 번의 실행은 한 트랜잭션이다.

**일반 그룹**
1. 마니또 상자를 `md5(시드 || box_id)` 순서로 처리한다.
2. 후보 = 그룹 멤버 − 보낸 사람 − 보낸 사람이 이 그룹에서 지정 선물을 보낸 멤버.
3. 후보 중 지금까지 받은 수(이 그룹의 지정 선물 + 앞에서 배정된 마니또)가 가장 적은 멤버. 동률이면 `md5(시드 || box_id || 후보 id)`가 가장 작은 멤버.
4. 후보가 없으면 미전달(받는 사람이 비어 있는 채로 둔다).

**모두 마니또 그룹**
- 마니또 상자를 가진 멤버를 `md5(시드 || user_id)` 순서로 한 줄로 세우고, 각자 다음 사람에게, 마지막 사람은 첫 사람에게 배정한다(하나의 순환). 자기 자신만 피하고, 지정 선물을 보낸 상대도 후보다.
- 멤버가 1명이면 미전달.

**자동 안전장치**: Cron `0 2 25 12 *`(UTC, 12/25 11:00 KST)이 `run_draw(null, 'auto')`를 부른다. 수동 실행을 마쳤다면 처리할 그룹이 없어 아무 일도 일어나지 않는다.

**공개 범위**: `draws`는 그 그룹 멤버가 읽는다. 프론트는 이것으로 "추첨이 끝났는지"와 미전달 여부를 안다.

## 인터페이스

```sql
public.draws(group_id uuid pk → groups, seed bigint, mode text /* 'manual' | 'auto' */,
             assigned_box_ids uuid[], undelivered_box_ids uuid[], executed_at timestamptz)
public.run_draw(p_seed bigint default null, p_mode text default 'manual')
  returns table (group_id uuid, assigned int, undelivered int)
public._draw_group(p_group_id uuid, p_seed bigint) returns table (box_id uuid, recipient_id uuid)  -- 내부용
cron job 'draw-safety': '0 2 25 12 *' → select public.run_draw(null, 'auto')
```

기술 문서의 `run_draw_if_missing()`은 `run_draw(null, 'auto')`와 같다(별도 함수를 만들지 않는다).

## 완료 조건

`backend/supabase/tests/database/manito_draw.test.sql`:
- [ ] 마감 전 실행은 `draw_before_deadline`.
- [ ] 자료의 예시 그룹(민지·서준·하은·지호·유나. 지정 선물 서준→민지, 민지→유나, 지호→민지. 마니또는 서준·민지·지호)을 시드 1~20으로 각각 추첨하면, 매번 마니또가 자기 자신이나 지정 선물을 보낸 상대에게 가지 않는다. (예시의 "5명 모두 받음"은 동률이 그렇게 풀린 경우다. 처리 순서에 따라 한 명이 못 받을 수 있으므로 모두 받는다는 단언은 하지 않는다.)
- [ ] 받은 수 최소 규칙: 4명 그룹(A·B·C·D)에서 지정 선물 A→B, C→B, D→B가 있고 A가 마니또를 보내면, 시드 1~20 모두 A의 마니또는 B가 아닌 C 또는 D에게 간다.
- [ ] 같은 그룹, 같은 시드로 두 번 추첨(`_draw_group`)하면 결과가 같다.
- [ ] `run_draw`를 두 번 실행하면 두 번째는 0개 그룹을 처리하고 배정이 바뀌지 않는다.
- [ ] 후보가 없는 경우(2명 그룹에서 서로 지정 선물을 보내고 한 명이 마니또) 미전달로 기록된다.
- [ ] 모두 마니또 1명·2명·3명·30명: 1명은 미전달, 나머지는 모두 정확히 1개씩 주고받고 자기 자신에게 가지 않는다.
- [ ] `mode = 'auto'`로 실행하면 `draws.mode`가 `auto`.
- [ ] 로그인 사용자가 `run_draw`를 부르면 권한 오류.
- [ ] 같은 그룹 멤버는 `draws`를 읽고, 그룹 밖 사람은 0행.

## 범위 밖

- 추첨 결과를 보여주는 화면(FE-09의 미전달 안내, FE-11의 공개)
- 되돌리기 절차 문서(BE-14)
