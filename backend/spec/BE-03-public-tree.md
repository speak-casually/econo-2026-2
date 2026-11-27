# BE-03 공개 트리: 카드·좋아요·신고·금칙어

- 주차: 1주차 (11/27) · 우선순위: P0 · 계획: B3
- 근거: 요구사항 5.1~5.5절, 기술 4.2·4.6절
- 선행: BE-01 · 이 작업을 쓰는 작업: FE-04, FE-05, FE-06, FE-13, BE-13

## 목적

누구나 카드를 걸고, 보고, 좋아요·신고하는 공개 트리의 데이터와 권한을 만든다.

## 동작 규칙

**카드**
- 1인 1장. 편지 1~300자(공백만 불가), 스티커 최대 20개, 사진·음반 없음.
- 숨김이 아닌 카드는 비로그인 포함 누구나 본다. 숨긴 카드는 작성자 본인과 관리자만 본다.
- 걸기와 수정은 본인만, 걸기 마감(`tree_deadline_at`) 전까지. 삭제는 본인만, 언제든. 삭제하면 좋아요도 사라지고 마감 전이면 다시 걸 수 있다.
- 클라이언트가 바꿀 수 있는 열은 `template, drawing_path, stickers, letter`뿐이다. `like_count`와 `hidden`은 못 바꾼다.
- 금칙어: 편지와 금칙어 모두 소문자로 바꾸고 공백을 지운 뒤 포함 여부를 본다. 걸리면 `banned_word`. 어떤 단어인지는 알려주지 않는다.

**좋아요**
- 1인 1카드 1회, 취소 가능, 내 카드에도 가능. 걸기 마감 후에도 가능.
- 개수(`like_count`)는 모두 본다. 누른 사람 목록은 카드 작성자만 본다(본인이 누른 것은 본인도 본다).
- 숨긴 카드에는 id를 알아도 좋아요를 누를 수 없다.

**신고**
- 대상은 카드 또는 프로필. 한 사람이 같은 대상을 한 번만(`23505`). 사유 없음.
- 신고 목록은 관리자만 본다. 자동 숨김은 없다.

**무작위 조회**: 숨김이 아닌 카드에서 무작위 N장.

## 인터페이스

```sql
public.tree_cards(id uuid pk, user_id uuid unique default auth.uid() → profiles, template text,
                  drawing_path text null, stickers jsonb, letter text, like_count int, hidden boolean,
                  created_at, updated_at)
public.card_likes(card_id uuid → tree_cards on delete cascade, user_id uuid default auth.uid(), created_at,
                  pk(card_id, user_id))
public.reports(id uuid pk, reporter_id uuid default auth.uid(), target_type text  -- 'card' | 'profile'
               , target_id uuid, created_at, unique(reporter_id, target_type, target_id))
public.banned_words(word text pk)   -- 클라이언트 접근 없음
public.random_tree_cards(p_limit int default 50) returns setof public.tree_cards  -- anon 허용
```

카드 작성자 정보는 `tree_cards.user_id → profiles.id` 외래 키로 함께 조회한다(`select('*, profiles(nickname, avatar_path)')`). 인덱스: `like_count desc`, `created_at desc`. 마이그레이션: `backend/supabase/migrations/20261125000300_public_tree.sql`.

## 완료 조건

`backend/supabase/tests/database/public_tree.test.sql` (1주차 계획 B3의 18개 단언):
- [ ] 카드 걸기 성공, 두 번째 카드 `23505`.
- [ ] `like_count`를 직접 고치면 `42501`. 공백만 있는 편지 `23514`.
- [ ] `'나 쁜 말 이야'`는 금칙어 `'나쁜말'`에 걸려 `banned_word`.
- [ ] 이모지 300개 편지는 통과한다.
- [ ] 좋아요하면 `like_count`가 1 오르고, 두 번째 좋아요는 `23505`, 취소하면 내려간다.
- [ ] 제3자는 좋아요 누른 사람 목록을 0행으로, 작성자는 1행으로 본다.
- [ ] 신고 성공, 같은 신고 `23505`, 일반 사용자는 신고 목록 0행.
- [ ] 숨긴 카드는 비로그인에게 0행, 작성자에게 1행. 숨긴 카드 id로 좋아요하면 `42501`.
- [ ] 걸기 마감 후 새 카드·수정은 거부, 삭제는 성공.

## 범위 밖

- 관리자가 숨기는 기능의 화면과 RPC(BE-13, FE-17). 1주차에는 대시보드 SQL로 숨긴다.
- 직접 그리기 이미지 저장소(BE-15)
