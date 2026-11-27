# BE-02 개봉 전 잠금: 그룹·선물 테이블과 읽기 권한

- 주차: 1주차 (11/28) · 우선순위: P0 (위험 확인) · 계획: B2
- 근거: 요구사항 2절(실패 조건)·6.5절·7.2절, 기술 4.2절
- 선행: BE-01 · 이 작업을 쓰는 작업: BE-06~BE-11, FE-09~FE-11

## 목적

"12/25 12:25 전에는 받는 사람도 선물 속을 못 본다"가 이 서비스에서 가장 깨지면 안 되는 규칙이다. 쓰기 기능을 만들기 전에 테이블과 읽기 규칙부터 만들어 테스트로 증명한다.

## 동작 규칙

- 그룹, 멤버, 선물 겉은 **같은 그룹 멤버만** 본다. 비로그인과 그룹 밖 사람은 0행.
- 선물은 **겉**(`gift_boxes`)과 **속**(`gift_box_contents`) 두 테이블이다. RLS가 행 단위라서 나눴다. 겉에는 보낸 사람 열이 없다.
- 속은 보낸 사람은 언제나 본다. 받는 사람은 `now() >= open_at`일 때만 본다. 그 밖의 사람은 끝까지 못 본다.
- 네 테이블 모두 클라이언트가 직접 쓸 수 없다(쓰기 정책 없음). 쓰기는 BE-06·07·08·11의 RPC로만 한다.
- 제약
  - 그룹 이름 1~20자, 공백만 불가. 초대 코드 8자, 중복 없음.
  - 겉: `kind`는 `designated` 또는 `manito`. 지정 선물은 받는 사람이 반드시 있다. 마니또는 추첨 전까지 받는 사람이 비어 있다. 스티커 최대 20개.
  - 속: 편지는 없거나 1~1000자, 사진 경로 최대 5개, YouTube id는 없거나 `^[A-Za-z0-9_-]{11}$`. 편지·사진·음반 중 하나 이상 있어야 한다.

## 인터페이스

```sql
public.groups(id uuid pk, name text, invite_code text unique, all_manito boolean, created_by uuid, created_at)
public.group_members(group_id uuid, user_id uuid, joined_at timestamptz, pk(group_id, user_id))
public.gift_boxes(id uuid pk, group_id uuid, recipient_id uuid null, kind text, box_color text,
                  ribbon_color text, stickers jsonb, opened_at timestamptz null, created_at)
public.gift_box_contents(box_id uuid pk → gift_boxes on delete cascade, sender_id uuid, letter text null,
                         photo_paths text[], youtube_id text null, updated_at)
public.is_group_member(p_group_id uuid) returns boolean  -- security definer, 정책 재귀 방지
```

마이그레이션: `backend/supabase/migrations/20261125000200_gift_lock.sql`.

## 완료 조건

`backend/supabase/tests/database/gift_lock.test.sql`. 준비: a(보낸 사람), b(받는 사람), c(같은 그룹), d(그룹 밖), a→b 지정 선물 1개.
- [ ] d와 비로그인은 그룹·상자 0행.
- [ ] c는 겉 1행, 속 0행.
- [ ] 개봉 전 b는 속 0행. 개봉 후(`open_at`을 과거로) b는 편지를 읽는다.
- [ ] 개봉 후에도 c는 속 0행.
- [ ] a는 언제나 속 1행.
- [ ] 로그인 사용자가 `gift_boxes`에 직접 insert하면 `42501`.
- [ ] 편지·사진·음반이 모두 없는 속 행은 `23514`.

## 범위 밖

- 그룹 생성·참여(BE-06), 선물 쓰기(BE-07), 개봉 기록(BE-11)
