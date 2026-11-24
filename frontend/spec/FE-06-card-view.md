# FE-06 카드 보기·좋아요·신고·작성자 프로필

- 주차: 1주차 (11/29) · 우선순위: P0 · 화면: ③, ③-1 · 계획: F6
- 근거: 요구사항 5.3·5.5절
- 선행: FE-05, BE-03 · 이 작업을 쓰는 작업: FE-13

## 목적

카드 한 장을 읽고, 좋아요를 누르고, 신고하고, 다음 사람의 카드로 넘어간다.

## 화면과 동작 (③, `/cards/:id`, 비로그인 가능)

- 상단 닫기(✕) → 홈.
- 카드를 탭하면 뒤집혀 편지가 보인다. 안내 "탭하면 뒤집혀 편지가 보여요".
- ‹ › 버튼: 다음 사람 카드를 무작위로 보여준다.
- 작성자 줄: 아이콘·닉네임(누르면 ③-1 작성자 프로필), "♥ {개수}" 좋아요 버튼, "신고" 버튼.
- 좋아요: 비로그인이면 로그인으로. 로그인이면 누를 때마다 켜고 끈다. 숫자는 바로 ±1 하고, 실패하면 되돌린다. 내 카드에도 누를 수 있다.
- 신고: 비로그인이면 로그인으로. 성공 "신고했어요", 이미 신고했으면 "이미 신고했어요".
- **내 카드**일 때: "수정하기" 버튼(`/cards/{id}/edit`), "삭제" 버튼, 그리고 좋아요를 누른 사람 목록(아이콘·닉네임).
- 카드가 없거나 숨긴 카드면(작성자 아님) "카드를 찾을 수 없어요"와 홈 버튼.

## 작성자 프로필 (③-1)

- 아래에서 올라오는 시트. 큰 프로필 사진, 닉네임, "공개 트리에 카드 1장을 걸었어요", "프로필 신고" 버튼.

## 사용하는 백엔드

- `tree_cards` + `profiles`, `card_likes` insert/delete/select, `reports` insert, `random_tree_cards(2)` (BE-03)

## 만드는 것 (`api.ts`에 추가)

- `fetchMyLike(cardId, userId): Promise<boolean>`
- `likeCard(cardId)`, `unlikeCard(cardId, userId)`
- `fetchLikers(cardId): Promise<{ nickname; avatarPath }[]>` (작성자만 결과가 나온다)
- `report(targetType: 'card' | 'profile', targetId): Promise<'ok' | 'already'>` (`23505` → `already`)
- `fetchNextRandomCardId(currentId): Promise<string | null>` (`random_tree_cards(2)`에서 현재 카드가 아닌 첫 id)

## 완료 조건

- [ ] `npm run lint && npm run typecheck && npm test && npm run build` 통과

직접 확인:
- [ ] 두 계정으로 서로 좋아요·취소·신고가 되고, 다시 신고하면 "이미 신고했어요".
- [ ] 작성자만 좋아요 누른 사람 목록을 본다.
- [ ] SQL로 숨긴 카드는 다른 계정에서 "카드를 찾을 수 없어요", 작성자에게는 보인다.
- [ ] ‹ ›로 계속 넘겨도 같은 카드가 연달아 나오지 않는다.

## 범위 밖

- 카드 목록(FE-13)
