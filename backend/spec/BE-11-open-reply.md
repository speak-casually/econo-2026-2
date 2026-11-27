# BE-11 개봉과 고마워요 답장

- 주차: 3주차 (12/7) · 우선순위: P0 (답장 P2)
- 근거: 요구사항 9절·13절(개봉률), 기술 4.2절
- 선행: BE-07, BE-10 · 이 작업을 쓰는 작업: FE-11, BE-13

## 목적

12/25 12:25 이후 받는 사람이 상자를 하나씩 열게 하고, 처음 연 시각을 기록한다(개봉률 지표). 마니또 선물은 열 때 보낸 사람이 공개된다.

## 동작 규칙

- 받는 사람만 연다(`not_recipient`). 개봉 시각 전이면 `not_opened_yet`.
- 처음 열 때만 `opened_at`을 채운다. 다시 열어도 바뀌지 않는다.
- 결과에 보낸 사람의 닉네임·사진을 담는다. 지정이든 마니또든 똑같이 돌려준다. 지정 선물의 보낸 사람은 화면에서 처음부터 보이고, 마니또는 이때 처음 공개된다(화면 처리는 FE-11).
- 사진은 이 결과의 경로로 프론트가 서명 URL을 만든다. 권한은 BE-07의 Storage 규칙이 이미 허용한다.
- **고마워요 답장(P2)**: 받은 사람이 개봉 후 상자마다 1번, 1~50자(공백만 불가). 받은 사람과 보낸 사람이 읽는다. 두 번째 답장은 `23505`. 고치거나 지울 수 없다.

## 인터페이스

```sql
public.open_gift(p_box_id uuid) returns jsonb
  -- { "box_id", "kind", "opened_at",
  --   "sender": { "id", "nickname", "avatar_path" },
  --   "letter", "photo_paths", "youtube_id" }
public.gift_replies(box_id uuid pk → gift_boxes on delete cascade, message text, created_at)
  -- insert: 받은 사람, now() >= open_at. select: 받은 사람 또는 보낸 사람
```

받은 상자 목록(겉)은 BE-02의 읽기 규칙으로 클라이언트가 직접 조회한다(`gift_boxes` where `recipient_id = 나`).

## 완료 조건

`backend/supabase/tests/database/open_reply.test.sql`:
- [ ] 개봉 전 받는 사람이 열면 `not_opened_yet`.
- [ ] 개봉 후 받는 사람이 열면 편지·보낸 사람 닉네임이 오고 `opened_at`이 채워진다. 다시 열어도 `opened_at`은 그대로다.
- [ ] 다른 멤버가 열면 `not_recipient`.
- [ ] 마니또 상자를 열면 보낸 사람 정보가 온다.
- [ ] 답장: 개봉 전 거부, 개봉 후 성공, 두 번째 `23505`, 51자 거부. 보낸 사람은 답장을 읽고, 제3자는 0행.

## 범위 밖

- 개봉 화면(FE-11), 개봉 알림(BE-12)
