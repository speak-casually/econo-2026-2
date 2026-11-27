# FE-10 선물상자 꾸미기

- 주차: 2주차 (12/2~12/3) · 우선순위: P0 (사진·음반 P1) · 화면: ⑧
- 근거: 요구사항 7절, 기술 4.5절
- 선행: FE-09, BE-07, BE-08, BE-09 · 이 작업을 쓰는 작업: FE-07, FE-08(입장 모드)

## 목적

선물상자의 겉(색·리본·스티커)과 속(편지·사진·음반)을 꾸며 놓거나 고친다.

## 모드

| 모드 | 진입 | 받는 사람 | 버튼 | 결과 |
|---|---|---|---|---|
| 새 지정 | 집 내부 `?to={userId}` | 고정(마니또로 바꿀 수 있음) | "보내기" | `place_gift` |
| 새 마니또 | 그룹 홈 "마니또 선물 보내기" | 없음 | "보내기" | `place_gift` |
| 수정 | `/gifts/{boxId}/edit` | 바꿀 수 없음 | "수정하기", "삭제" | `update_gift` / `delete_gift` |
| 입장 | FE-07·08 (모두 마니또) | 없음 | "이 선물로 참여하기" | 호출한 화면에 `GiftBoxInput`을 돌려준다 |

## 화면과 동작 (⑧)

- 받는 사람: 라디오 "{닉네임}님에게" / "🎁 마니또로 보내기 — 마감 후 그룹 안 한 명에게 가요". 새 지정 모드에서만 둘 중 고를 수 있다. 마니또로 바꿨는데 이 그룹에 이미 마니또가 있으면 "이미 마니또 선물을 놓았어요".
- 겉: 상자 미리보기, "상자 색", "리본 색", "스티커"(최대 20개). 색·스티커 목록은 디자이너가 준다.
- 속: 탭 "편지" / "사진" / "음반".
  - 편지: 입력 + 카운터 `n/1000`.
  - 사진(P1): 최대 5장. 고르면 긴 변 1600px JPEG로 줄여 `gift-photos/{내 id}/{uuid}.jpg`에 바로 올린다. 미리보기와 삭제.
  - 음반(P1): "YouTube 링크 붙여넣기" → `youtube-meta` → 썸네일·제목·채널 미리보기. 1곡.
- 편지·사진·음반 중 하나 이상이 있어야 버튼이 켜진다.
- 안내 "결제 기능은 없어요 · 기프티콘은 사진으로만 전할 수 있어요".
- 성공하면 받는 사람의 집(마니또는 그룹 홈)으로 돌아간다. 상자가 트리 아래로 내려오는 연출 1.5초(P1).
- 삭제: 확인 창 → `delete_gift`. 모두 마니또 그룹의 마니또 선물은 삭제 버튼이 없다.
- 마감 후: 읽기 전용 화면과 "마감돼서 더 고칠 수 없어요".
- 일정이 밀려 사진·음반을 자르는 경우를 위해, 두 탭은 `src/config.ts`의 `FEATURES.photo`, `FEATURES.music`으로 끌 수 있다.

## 사용하는 백엔드

- `rpc('place_gift' | 'update_gift' | 'delete_gift')` (BE-07), Storage `gift-photos`, `POST /functions/v1/youtube-meta` (BE-09)

## 예외 처리

[백엔드 에러 코드 표](../../backend/spec/README.md#에러-코드-프론트와의-약속)의 문구를 쓴다: `already_sent`, `empty_contents`, `invalid_recipient`, `invalid_photo_path`, `not_sender`, `manito_box_locked`, `deadline_passed`. YouTube: `invalid_url` → "YouTube 링크만 넣을 수 있어요", `not_playable` → "재생할 수 없는 링크예요", 그 밖 → "링크를 확인하지 못했어요. 잠시 후 다시 시도해 주세요".

## 만드는 것

- `type GiftDraft`(화면 상태) → `toGiftBoxInput(draft): GiftBoxInput`(편지 앞뒤 공백 제거, 빈 편지는 `null`)
- `validateGift(input): 'empty' | 'letter_too_long' | 'too_many_photos' | null`

## 완료 조건

Vitest:
- [ ] `validateGift`: 셋 다 없음 → `empty`, 공백만 있는 편지만 → `empty`, 1001자 → `letter_too_long`, 사진 6장 → `too_many_photos`, 사진 1장만 → `null`, 음반만 → `null`
- [ ] `toGiftBoxInput`: `"  안녕  "` → `"안녕"`, `"   "` → `null`

직접 확인:
- [ ] 지정·마니또 선물을 놓고, 고치고, 지울 수 있다. 같은 사람에게 두 번째 지정 선물은 "이미 선물을 놓았어요".
- [ ] 사진 5장까지 올라가고 6장째는 막힌다. 10MB 사진도 줄여서 올라간다.
- [ ] 퍼가기 금지 YouTube 링크는 "재생할 수 없는 링크예요".
- [ ] 입장 모드에서 만든 상자로 모두 마니또 그룹에 참여할 수 있다.

## 범위 밖

- 개봉 화면에서의 재생(FE-11)
