# FE-04 홈 = 공개 트리

- 주차: 1주차 (11/27) · 우선순위: P0 · 화면: ⓪ · 계획: F4
- 근거: 요구사항 5.1절, 기술 4.6절
- 선행: FE-01, BE-03 · 이 작업을 쓰는 작업: FE-05, FE-06, FE-16

## 목적

첫 화면. 누구나 트리에 걸린 카드를 보고, 내 카드를 걸러 간다.

## 화면과 동작 (⓪)

- 비로그인도 볼 수 있다.
- 상단 칩: "지금까지 걸린 마음 {N}개 · D-{n}". N은 숨김이 아닌 카드 수. D 표시는 `n > 0`이면 `D-n`, `0`이면 `D-DAY`, 음수면 숨긴다.
- 트리: 카드 최대 50장을 무작위로 건다. 카드마다 작성자 프로필 아이콘. 좋아요 5개 이상·20개 이상·50개 이상에서 3단계로 밝아진다(반짝임). 카드를 누르면 `/cards/:id`.
- 버튼
  - "카드 걸기": 비로그인 → `/login?returnTo=/cards/new`. 내 카드가 있으면 `/cards/{내 카드 id}`. 없으면 `/cards/new`.
  - "전체 보기" → `/cards` (FE-13 전에는 숨긴다)
- 로그인 상태로 홈을 처음 열면 `mark_home_visit`을 한 번 부른다(지표용).
- 카드가 0장이면 "아직 걸린 카드가 없어요. 첫 카드를 걸어 보세요".

## 사용하는 백엔드

- `rpc('random_tree_cards', { p_limit: 50 }).select('*, profiles!tree_cards_user_id_fkey(nickname, avatar_path)')`
- `tree_cards` 개수(`hidden = false`, `count: 'exact', head: true`), 내 카드(`user_id = 나`)
- `rpc('mark_home_visit')`

## 만드는 것 (`src/features/tree/`)

- `type TreeCard = { id; userId; template; drawingPath; stickers; letter; likeCount; hidden; createdAt; author: { nickname; avatarPath } }`
- `api.ts`: `fetchRandomCards(limit)`, `countVisibleCards()`, `fetchMyCard(userId)`. FE-05·06·13이 이 파일에 함수를 더한다.
- `sparkleLevel(likes: number): 0 | 1 | 2 | 3`
- 카드 50장의 배치 방식은 구현자 재량(요구사항 15절).

## 완료 조건

Vitest:
- [ ] `sparkleLevel`: 0→0, 4→0, 5→1, 19→1, 20→2, 49→2, 50→3, 999→3

직접 확인:
- [ ] 시크릿 창(비로그인)에서도 트리가 보인다.
- [ ] 카드 수와 D-n이 맞다. 좋아요 5개 이상인 카드가 밝게 보인다.
- [ ] 숨긴 카드는 트리와 개수에 나오지 않는다.

## 범위 밖

- 카드 목록(FE-13), 넛지 배너(FE-16), 캐롤(FE-14)
