# BE-15 직접 그리기 이미지 저장소

- 주차: 3주차 이후 · 우선순위: P1
- 근거: 요구사항 5.2절, 기술 4.5절
- 선행: BE-03 · 이 작업을 쓰는 작업: FE-15

## 목적

공개 카드 앞면을 직접 그린 경우, 그 그림을 PNG로 저장할 곳을 만든다.

## 동작 규칙

- 공개 버킷 `card-images`. 공개 카드는 누구나 보므로 서명 URL이 필요 없다.
- 경로 `{user_id}/{uuid}.png`. 2MB 이하, `image/png`만.
- 올리기는 본인 폴더, 걸기 마감 전에만. 지우기는 본인 폴더, 언제든.
- `tree_cards.drawing_path`는 비어 있거나 `<본인 user id>/`로 시작해야 한다(insert·update 정책의 with check에 추가).

## 인터페이스

```sql
storage bucket 'card-images' (public, 2MB, image/png)
-- tree_cards insert/update 정책: drawing_path is null or drawing_path like auth.uid()::text || '/%'
```

## 완료 조건

`backend/supabase/tests/database/card_images.test.sql`:
- [ ] 남의 폴더에 올리기 거부, 걸기 마감 후 올리기 거부.
- [ ] 다른 사람 폴더 경로를 `drawing_path`로 넣으면 `42501`.
- [ ] 비로그인도 그림 파일을 읽을 수 있다.

## 범위 밖

- 그리기 화면(FE-15)
