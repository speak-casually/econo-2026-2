# BE-07 선물상자 놓기·수정·삭제, 사진 저장소

- 주차: 2주차 (12/1) · 우선순위: P0 (사진 P1)
- 근거: 요구사항 7절, 기술 4.2·4.5절
- 선행: BE-06 · 이 작업을 쓰는 작업: BE-08, BE-10, BE-11, FE-09, FE-10

## 목적

그룹 멤버가 지정 선물 또는 마니또 선물을 놓고, 마감 전까지 고치거나 지울 수 있게 한다. 겉 테이블에 보낸 사람이 없어서 RLS만으로는 "보낸 사람만 수정"을 표현할 수 없으므로 쓰기는 모두 RPC로 한다.

## 동작 규칙

**놓기** (`place_gift`)
- 로그인, 그 그룹 멤버(`not_member`), 마감 전(`deadline_passed`).
- 지정 선물: 받는 사람이 같은 그룹의 자기 외 멤버여야 한다(`invalid_recipient`). **그룹 안에서** 같은 사람에게는 1개만(`already_sent`). 두 사람이 다른 그룹에도 같이 있으면 그 그룹에서 또 보낼 수 있다.
- 마니또 선물: 받는 사람을 받지 않는다. 그룹마다 1인 1개(`already_sent`).
- 속에 편지·사진·음반 중 하나 이상(`empty_contents`). 편지 1~1000자, 사진 최대 5장, YouTube id 형식 검사.
- 사진 경로는 모두 `<내 user id>/`로 시작해야 한다(`invalid_photo_path`).
- 같은 보낸 사람의 동시 요청은 `pg_advisory_xact_lock(hashtext(그룹 id || 보낸 사람 id))`로 줄 세운다. 중복 검사가 두 테이블에 걸쳐 있어 unique 제약을 쓸 수 없기 때문이다.
- 겉과 속 두 행을 한 트랜잭션으로 만든다.

**수정** (`update_gift`): 보낸 사람만(`not_sender`), 마감 전. 겉(색·리본·스티커)과 속(편지·사진·음반)을 바꾼다. **받는 사람과 종류는 바꿀 수 없다.** 같은 내용 규칙을 다시 검사한다.

**삭제** (`delete_gift`): 보낸 사람만, 마감 전. 모두 마니또 그룹의 마니또 선물은 `manito_box_locked`. 겉을 지우면 속도 함께 지워진다.

**사진 저장소** (`gift-photos`, 비공개 버킷, 5MB, JPEG·PNG·WebP)
- 경로 `{user_id}/{uuid}.jpg`. 상자를 만들기 전에 올린다.
- 올리기·지우기: 경로 첫 폴더가 본인 id이고 마감 전일 때만.
- 읽기: 올린 본인, 그리고 그 경로를 `photo_paths`에 담은 속 행을 읽을 수 있는 사람(즉 개봉 후 받는 사람). 정책 안의 하위 조회에 `gift_box_contents`의 RLS가 그대로 적용된다.

**내가 보낸 선물 조회**: 속 테이블은 보낸 사람이 항상 읽을 수 있으므로, 클라이언트가 `gift_box_contents`에 `gift_boxes`를 붙여 직접 조회한다.

## 인터페이스

```sql
public.place_gift(p_group_id uuid, p_kind text, p_recipient_id uuid, p_box jsonb) returns uuid  -- box_id
public.update_gift(p_box_id uuid, p_box jsonb) returns void
public.delete_gift(p_box_id uuid) returns void
public._insert_gift_box(p_group_id uuid, p_sender_id uuid, p_kind text, p_recipient_id uuid, p_box jsonb)
  returns uuid   -- 내부용. BE-08도 쓴다. execute 권한을 클라이언트에 주지 않는다
storage bucket 'gift-photos' (private)
```

`p_box`는 [README의 `GiftBoxInput`](README.md#선물-입력-형식-giftboxinput-be-07-be-08-공통) 형식이다.

## 완료 조건

`backend/supabase/tests/database/gift_write.test.sql`:
- [ ] 멤버가 아니면 `not_member`.
- [ ] 자기 자신, 다른 그룹 사람에게 지정 선물이면 `invalid_recipient`.
- [ ] 같은 그룹에서 같은 사람에게 두 번째 지정 선물이면 `already_sent`. 다른 그룹에서는 성공.
- [ ] 같은 그룹에서 마니또 두 번째면 `already_sent`.
- [ ] 편지·사진·음반이 모두 없으면 `empty_contents`. 편지 1001자는 거부.
- [ ] 다른 사람 폴더의 사진 경로면 `invalid_photo_path`.
- [ ] 마감 후 놓기·수정·삭제는 `deadline_passed`.
- [ ] 다른 사람이 수정·삭제하면 `not_sender`. 수정해도 받는 사람이 바뀌지 않는다.
- [ ] 일반 그룹의 마니또 선물 삭제는 성공, 모두 마니또 그룹의 마니또 선물 삭제는 `manito_box_locked`.
- [ ] Storage: 남의 폴더에 올리기 거부, 마감 후 올리기 거부. 개봉 전 받는 사람은 사진을 못 읽고, 개봉 후에는 읽는다. 같은 그룹의 다른 멤버는 끝까지 못 읽는다.

## 범위 밖

- 상자를 지울 때 사진 파일 정리(남은 파일은 파기 때 지운다, BE-14)
- 사진 파일이 실제로 있는지 확인(경로 형식만 검사)
