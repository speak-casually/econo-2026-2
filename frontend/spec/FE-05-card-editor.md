# FE-05 카드 꾸미기·수정·삭제

- 주차: 1주차 (11/28) · 우선순위: P0 · 화면: ② · 계획: F5
- 근거: 요구사항 5.2절
- 선행: FE-02, FE-04, BE-03 · 이 작업을 쓰는 작업: FE-06, FE-15

## 목적

공개 트리에 걸 카드 1장을 만들고, 걸기 마감 전까지 고치거나 지운다.

## 화면과 동작 (②, `/cards/new`, `/cards/:id/edit`, 로그인·프로필 필요)

- 카드 미리보기가 위에 있고, 탭 "앞면" / "뒷면(편지)".
- 앞면: 기본 카드 1종 선택. 직접 그리기·스티커는 P1(FE-15) 전까지 숨긴다.
- 뒷면: 편지 입력 + 카운터 `n/300`.
- "미리보기": 카드가 앞뒤로 뒤집힌다.
- 새 카드는 "트리에 걸기", 수정은 "수정하기". 요청 중에는 버튼을 비활성화한다.
- 성공하면 `/cards/{id}`로 간다.
- 수정 모드: 본인 카드가 아니면 `/cards/:id`로 보낸다. 하단 "카드 삭제" → 확인 창 "삭제하면 좋아요도 사라져요" → 삭제 후 `/`.
- 걸기 마감 후: 새 카드와 수정 화면은 "카드 걸기가 마감됐어요"만 보여준다. 삭제는 카드 보기에서 계속 할 수 있다.

## 사용하는 백엔드

- `tree_cards` insert(`template, letter`), update, delete (BE-03)

## 예외 처리

| 상황 | 문구 / 동작 |
|---|---|
| `23505`(이미 카드 있음) | "이미 카드를 걸었어요" → 내 카드로 이동 |
| `banned_word` | "쓸 수 없는 단어가 있어요" (어떤 단어인지 말하지 않는다) |
| `42501`(마감) | "카드 걸기가 마감됐어요" |
| `23514`(글자 수) | 화면 검사가 먼저 막으므로 "편지를 확인해 주세요" |

## 만드는 것

- `src/lib/errors.ts`: `isUniqueViolation(e)`(`23505`), `isPermissionDenied(e)`(`42501`), `isBannedWord(e)`(`message === 'banned_word'`), `errorCode(e): string | null`(RPC 에러 코드 추출. 이후 화면들이 쓴다)
- `validateLetter(raw: string): 'empty' | 'too_long' | null` (1~300자, 앞뒤 공백 제거 후)
- `CARD_TEMPLATES`: 디자이너 확정 전 임시값 `snowflake ❄️ 눈 송이`, `sled 🛷 산타 썰매`, `house 🏠 따뜻한 집`, `snowman ⛄ 눈사람`, `tree 🎄 크리스마스 트리`, `cookie 🍪 쿠키`
- `api.ts`: `createCard({ template, letter })`, `updateCard(id, { template, letter })`, `deleteCard(id)`, `fetchCard(id)`

## 완료 조건

Vitest:
- [ ] `validateLetter`: `""`·`"  \n "` → `empty`, 300자 → `null`, 301자 → `too_long`, 이모지 300개 → `null`
- [ ] `isUniqueViolation({code:'23505'})`, `isPermissionDenied({code:'42501'})`, `isBannedWord({message:'banned_word'})`는 true, `isBannedWord(null)`은 false

직접 확인:
- [ ] 카드를 걸면 홈 트리에 나타난다. 버튼을 빠르게 두 번 눌러도 카드는 1장이다.
- [ ] 금칙어가 들어간 편지는 거부된다.
- [ ] 수정·삭제가 되고, 삭제 후 다시 걸 수 있다.

## 범위 밖

- 직접 그리기·스티커(FE-15)
