# 백엔드 작업별 명세

[요구사항 명세](../../docs/superpowers/specs/2026-11-25-requirements-design.md)(동작)와 [기술 스택](../../docs/superpowers/specs/2026-11-22-tech-stack-design.md)(구현 방식)을 **작업 단위로 나눈 것**이다. 작업 하나 = 파일 하나 = PR 하나가 기본이다. 명세끼리 다르면 요구사항 명세가 이긴다.

## 파일 구성

모든 명세는 같은 순서로 쓴다.

- **머리말**: 주차, 우선순위(P0/P1/P2), 근거 절, 선행 작업, 이 작업을 쓰는 작업
- **목적**: 왜 필요한가
- **동작 규칙**: 지켜야 할 규칙. 숫자와 문구는 정확히
- **인터페이스**: 만드는 테이블·RPC·함수의 이름과 형식. 프론트는 이 이름을 그대로 쓴다
- **완료 조건**: 통과해야 할 테스트. 이게 다 통과해야 끝난 것이다
- **범위 밖**: 이 작업에서 하지 않는 것

## 목록

| ID | 제목 | 주차 | 우선순위 | 선행 |
|---|---|---|---|---|
| [BE-00](BE-00-kakao-manual-check.md) | 카톡 "나에게 보내기" 수동 확인 | 1 (11/25) | P0 위험 확인 | - |
| [BE-01](BE-01-foundation.md) | 기반: 설정 시각, 프로필, 개인 설정, 아바타 | 1 (11/25) | P0 | - |
| [BE-02](BE-02-gift-lock-rls.md) | 개봉 전 잠금 (그룹·선물 테이블과 읽기 권한) | 1 (11/28) | P0 위험 확인 | BE-01 |
| [BE-03](BE-03-public-tree.md) | 공개 트리: 카드·좋아요·신고·금칙어 | 1 (11/27) | P0 | BE-01 |
| [BE-04](BE-04-kakao-token.md) | 카카오 토큰 저장·테스트 발송 | 1 (11/26) | P0 | BE-01 |
| [BE-05](BE-05-staging-deploy.md) | 스테이징 환경·배포 자동화 | 1 (11/26) | P0 | BE-01 |
| [BE-06](BE-06-groups-invite.md) | 그룹 만들기·초대·참여 | 2 (11/30) | P0 | BE-02 |
| [BE-07](BE-07-gift-write.md) | 선물상자 놓기·수정·삭제, 사진 저장소 | 2 (12/1) | P0 | BE-06 |
| [BE-08](BE-08-all-manito-join.md) | 모두 마니또 참여 | 2 (12/2) | P0 | BE-06, BE-07 |
| [BE-09](BE-09-youtube-meta.md) | YouTube 링크 검사 | 2 (12/3) | P1 | BE-01 |
| [BE-10](BE-10-manito-draw.md) | 마니또 추첨과 자동 안전장치 | 2 (12/4~5) | P0 | BE-07, BE-08 |
| [BE-11](BE-11-open-reply.md) | 개봉과 고마워요 답장 | 3 (12/7) | P0 (답장 P2) | BE-07, BE-10 |
| [BE-12](BE-12-open-notifications.md) | 12/25 카톡 알림 발송 | 3 (12/7) | P0 | BE-04 |
| [BE-13](BE-13-metrics-admin.md) | 지표와 관리자 기능 | 3 (12/8) | P0 지표 / P1 관리 | BE-03, BE-10, BE-11 |
| [BE-14](BE-14-ops-scripts.md) | 운영 스크립트 (백업·리허설·정리·파기) | 3 (12/9) | P0 | BE-10, BE-12, BE-13 |
| [BE-15](BE-15-card-images.md) | 직접 그리기 이미지 저장소 | 3 이후 | P1 | BE-03 |

1주차 작업(BE-00~05)의 단계별 실행 순서는 [1주차 계획](../../docs/superpowers/plans/2026-11-25-week1-foundation-public-tree.md)에 있다(B0~B5와 같은 작업).

## 공통 규칙

- Supabase 프로젝트는 `backend/supabase/`에 있다. Supabase CLI 명령은 `backend/`에서 실행한다. 명세의 파일 경로는 레포 루트 기준이다.
- 모든 시각은 KST로 정하고 `timestamptz`로 저장한다. 마감·개봉·걸기 마감 시각은 `public.app_config` 한 행에서만 읽는다. 코드에 날짜를 직접 쓰지 않는다.
- 모든 public 테이블은 RLS를 켠다. 클라이언트가 직접 쓰면 안 되는 테이블은 쓰기 정책을 만들지 않고, `security definer` RPC로만 쓴다.
- `security definer` 함수는 `set search_path = ''`를 두고 이름을 스키마까지 적는다. 첫 줄에서 `auth.uid()`가 null이면 `not_authenticated`를 낸다(anon 허용 함수 제외).
- 글자 수는 `char_length`(코드 포인트). 공백만 있는 문자열은 `btrim(x) <> ''`로 막는다.
- 테스트는 pgTAP(`backend/supabase/tests/database/*.test.sql`)과 Deno(`backend/supabase/functions/**/*_test.ts`). 사용자 흉내 방법은 1주차 계획의 "pgTAP 테스트 규칙"을 따른다.
- 관리자: `auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'`(`public.is_admin()`).

## 에러 코드 (프론트와의 약속)

RPC는 규칙 위반 시 `raise exception '<코드>'`(errcode `P0001`)를 낸다. 프론트는 `error.message`로 구분해 아래 문구를 보여준다. 문구가 비어 있는 코드는 사용자에게 보이지 않는 경우다.

| 코드 | 언제 | 사용자 문구 |
|---|---|---|
| `not_authenticated` | 로그인 없이 호출 | (로그인 화면으로 이동) |
| `profile_exists` | 프로필을 두 번 만듦 | (무시하고 진행) |
| `deadline_passed` | 마감 후 그룹 생성·참여, 선물 쓰기 | "마감됐어요" |
| `invite_not_found` | 없는 초대 코드 | "초대 링크를 찾을 수 없어요" |
| `group_full` | 정원 30명 초과 | "정원이 다 찼어요" |
| `manito_box_required` | 모두 마니또 그룹에 상자 없이 참여 | "마니또 선물을 먼저 만들어 주세요" |
| `not_member` | 그룹 멤버가 아님 | "이 그룹의 멤버가 아니에요" |
| `invalid_recipient` | 자기 자신 또는 다른 그룹 사람에게 지정 선물 | "받을 수 없는 사람이에요" |
| `already_sent` | 같은 사람에게 지정 선물 2개, 또는 마니또 2개 | "이미 선물을 놓았어요" |
| `empty_contents` | 편지·사진·음반 모두 없음 | "편지, 사진, 음반 중 하나는 넣어 주세요" |
| `invalid_photo_path` | 본인 폴더가 아닌 사진 경로 | "사진을 다시 올려 주세요" |
| `not_sender` | 남의 선물 수정·삭제 | "내가 보낸 선물만 고칠 수 있어요" |
| `manito_box_locked` | 모두 마니또 그룹의 마니또 선물 삭제 | "모두 마니또 선물은 지울 수 없어요" |
| `not_recipient` | 내가 받지 않은 상자 열기 | "내 선물이 아니에요" |
| `not_opened_yet` | 개봉 시각 전에 열기 | "12/25 12:25에 열 수 있어요" |
| `banned_word` | 공개 카드 금칙어 | "쓸 수 없는 단어가 있어요" |
| `draw_before_deadline` | 마감 전 추첨 실행 | (관리자 전용) |
| `forbidden` | 관리자 전용 기능을 일반 사용자가 호출 | (관리자 전용) |

Postgres 기본 코드: `23505`(중복, 예: 카드 두 장·좋아요 두 번·신고 두 번·답장 두 번), `42501`(권한·RLS 거부, 예: 걸기 마감 후 카드), `23514`(글자 수 등 제약 위반).

## 클라이언트가 직접 읽는 테이블

RPC를 거치지 않고 `supabase.from(...)`이나 `supabase.storage`로 바로 읽는 대상이다. 컬럼 이름과 타입은 각 명세의 「인터페이스」와 `supabase gen types`를 본다. 이 표는 **누구에게 어떤 행이 보이는지**만 모은다. 규칙의 원본은 근거 명세와 [기술 문서 4.2절](../../docs/superpowers/specs/2026-11-22-tech-stack-design.md)이다.

**RLS로 막힌 읽기는 에러가 아니라 0행이다.** 행이 없을 수 있는 조회는 `.single()` 대신 `.maybeSingle()`을 쓴다. 예를 들어 개봉 전 받는 사람이 선물 속을 조회하면 에러 없이 빈 결과가 온다.

| 대상 | 누가 읽나 | 시각 조건 | 클라이언트 직접 쓰기 | 근거 |
|---|---|---|---|---|
| `app_config` | 누구나(비로그인 포함) | - | 없음 | [BE-01](BE-01-foundation.md) |
| `profiles` | 누구나(비로그인 포함) | - | 본인 행 수정. 생성은 `complete_profile` | [BE-01](BE-01-foundation.md) |
| `user_settings` | 본인만 | - | `kakao_notify`만 수정. `first_home_visit_at`은 `mark_home_visit` | [BE-01](BE-01-foundation.md) |
| `tree_cards` | 숨김 아닌 카드: 누구나. 숨긴 카드: 작성자·관리자 | 걸기·수정은 `tree_deadline_at` 전, 삭제는 언제든 | 본인 카드 추가·수정(`template, drawing_path, stickers, letter`)·삭제 | [BE-03](BE-03-public-tree.md) |
| `card_likes` | 카드 작성자, 그리고 누른 본인 | 마감 후에도 누르고 취소 가능 | 본인 좋아요 추가·삭제. 개수는 `tree_cards.like_count` | [BE-03](BE-03-public-tree.md) |
| `reports` | 관리자만(일반 사용자는 0행) | - | 로그인 사용자 추가 | [BE-03](BE-03-public-tree.md) |
| `groups` | 같은 그룹 멤버. 비멤버는 `get_invite` | - | 없음(`create_group`) | [BE-02](BE-02-gift-lock-rls.md), [BE-06](BE-06-groups-invite.md) |
| `group_members` | 같은 그룹 멤버 | - | 없음(`create_group`, `join_group`) | [BE-02](BE-02-gift-lock-rls.md), [BE-06](BE-06-groups-invite.md) |
| `gift_boxes` (겉) | 같은 그룹 멤버. **보낸 사람 열 없음** | - | 없음(`place_gift` 등) | [BE-02](BE-02-gift-lock-rls.md) |
| `gift_box_contents` (속) | 보낸 사람: 항상. 받는 사람: 개봉 후. 그 밖: 끝까지 0행 | 받는 사람은 `now() >= open_at` | 없음(`place_gift` 등) | [BE-02](BE-02-gift-lock-rls.md), [BE-07](BE-07-gift-write.md) |
| `draws` | 같은 그룹 멤버 | 추첨 전에는 행 없음 | 없음 | [BE-10](BE-10-manito-draw.md) |
| `gift_replies` (P2) | 받은 사람, 보낸 사람 | 쓰기는 개봉 후 | 받은 사람이 상자당 1번 추가 | [BE-11](BE-11-open-reply.md) |
| Storage `avatars` (공개) | 누구나 | - | 본인 폴더(`{user_id}/`)에 올리기·지우기 | [BE-01](BE-01-foundation.md) |
| Storage `card-images` (공개, P1) | 누구나 | 올리기는 걸기 마감 전 | 본인 폴더에 올리기. 지우기는 언제든 | [BE-15](BE-15-card-images.md) |
| Storage `gift-photos` (비공개) | 올린 본인, 개봉 후 받는 사람 | 올리기·지우기는 마감 전 | 본인 폴더에 올리기·지우기 | [BE-07](BE-07-gift-write.md) |

클라이언트가 접근하지 않는 테이블: `banned_words`, `kakao_tokens`, `notification_logs`.

**화면별 대표 조회**

```ts
// 시각 설정 (마감·개봉 안내)
supabase.from('app_config').select('deadline_at, open_at, tree_deadline_at').single()

// 공개 트리: 무작위, 인기순. 작성자 정보는 profiles를 붙인다
supabase.rpc('random_tree_cards', { p_limit: 50 }).select('*, profiles!tree_cards_user_id_fkey(nickname, avatar_path)')
supabase.from('tree_cards').select('*, profiles!tree_cards_user_id_fkey(nickname, avatar_path)').order('like_count', { ascending: false })
// 내 카드 (없으면 null)
supabase.from('tree_cards').select('*').eq('user_id', myId).maybeSingle()
// 내가 이 카드에 좋아요를 눌렀나 (없으면 null)
supabase.from('card_likes').select('card_id').eq('card_id', cardId).eq('user_id', myId).maybeSingle()

// 내 그룹 목록: RLS가 내가 멤버인 그룹만 돌려준다
supabase.from('groups').select('id, name, all_manito')
// 그룹 멤버
supabase.from('group_members').select('user_id, joined_at, profiles(nickname, avatar_path)').eq('group_id', groupId)
// 집 내부 상자 그림 (겉만)
supabase.from('gift_boxes').select('id, recipient_id, kind, box_color, ribbon_color, stickers, opened_at').eq('group_id', groupId)
// 받은 상자 목록 (겉만). 속은 open_gift RPC로 연다
supabase.from('gift_boxes').select('*').eq('recipient_id', myId)
// 내가 보낸 선물 (속 + 겉)
supabase.from('gift_box_contents').select('*, gift_boxes(*)').eq('sender_id', myId)
// 추첨이 끝났나, 미전달 상자는 무엇인가 (추첨 전이면 null)
supabase.from('draws').select('executed_at, undelivered_box_ids').eq('group_id', groupId).maybeSingle()

// 사진 URL
supabase.storage.from('avatars').getPublicUrl(path)
supabase.storage.from('gift-photos').createSignedUrl(path, 3600)
```

그룹 홈과 집 내부에는 받은 개수를 숫자로 보여주지 않는다([기술 문서 4.2절](../../docs/superpowers/specs/2026-11-22-tech-stack-design.md)). `gift_boxes`를 직접 세면 숫자를 만들 수 있지만 화면에 쓰지 않는다.

## 선물 입력 형식 `GiftBoxInput` (BE-07, BE-08 공통)

```json
{
  "box_color": "red",
  "ribbon_color": "gold",
  "stickers": [{ "id": "star", "x": 0.4, "y": 0.2 }],
  "letter": "메리 크리스마스",
  "photo_paths": ["<내 user id>/<uuid>.jpg"],
  "youtube_id": "E8gmARGvPlI"
}
```

`letter`·`youtube_id`는 없으면 `null`, `photo_paths`는 없으면 `[]`. 셋 중 하나 이상 있어야 한다. 색과 스티커 id 목록은 디자이너가 정하며 DB는 형식만 검사한다.
