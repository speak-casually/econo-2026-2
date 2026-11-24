# BE-09 YouTube 링크 검사

- 주차: 2주차 (12/3) · 우선순위: P1 (음반)
- 근거: 요구사항 7.2절, 기술 4.5절
- 선행: BE-01 · 이 작업을 쓰는 작업: FE-10

## 목적

선물상자에 붙인 YouTube 링크가 재생 가능한지 확인하고, 미리보기에 쓸 제목·채널·썸네일을 준다. 브라우저에서 YouTube oEmbed를 바로 부르면 CORS에 막힐 수 있어 Edge Function으로 대신 부른다.

## 동작 규칙

- 받는 링크 형식(이 밖은 `invalid_url`)
  - `https://www.youtube.com/watch?v=ID` (`m.`, `music.` 하위 도메인, `www` 없는 주소, 추가 쿼리 포함)
  - `https://youtu.be/ID` (쿼리 포함)
  - `https://www.youtube.com/shorts/ID`
- ID는 `^[A-Za-z0-9_-]{11}$`.
- `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=ID&format=json`을 부른다. 200이면 정보를 돌려주고, 401·403·404면 `not_playable`(없는 영상, 퍼가기 금지, 비공개). 그 밖은 `upstream_failed`.
- 로그인한 사용자만 부를 수 있다.
- DB에는 ID만 저장한다(BE-07). 썸네일은 `https://i.ytimg.com/vi/{ID}/hqdefault.jpg`.

## 인터페이스

**`POST /functions/v1/youtube-meta`**
- 본문 `{ "url": string }`
- `200 { "video_id": string, "title": string, "author_name": string, "thumbnail_url": string }`
- `400 { "error": "invalid_url" }`, `401 { "error": "unauthorized" }`, `422 { "error": "not_playable" }`, `502 { "error": "upstream_failed" }`

공용 함수: `_shared/youtube.ts`의 `parseYoutubeId(url: string): string | null`.

## 완료 조건

- [ ] `deno test`로 `parseYoutubeId` 검사: 위 형식 6가지(watch, m., music., youtu.be, youtu.be?si=, shorts)는 ID를 돌려주고, `https://vimeo.com/123`, `https://www.youtube.com/watch?v=short`, `javascript:alert(1)`, 빈 문자열은 `null`.
- [ ] 스테이징에서 공개 영상 링크는 200과 제목을, 퍼가기 금지 영상은 422를 돌려준다.

## 범위 밖

- 영상 재생(FE-10, FE-11의 YouTube IFrame Player)
