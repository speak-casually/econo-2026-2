# 프론트엔드 작업별 명세

[요구사항 명세](../../docs/superpowers/specs/2026-11-25-requirements-design.md)(동작)와 [기술 스택](../../docs/superpowers/specs/2026-11-22-tech-stack-design.md)(구현 방식)을 **화면·기능 단위로 나눈 것**이다. 작업 하나 = 파일 하나 = PR 하나가 기본이다. 명세끼리 다르면 요구사항 명세가 이긴다. 화면 번호(⓪~⑩)는 프로토타입과 디자인 자료의 번호다.

## 파일 구성

모든 명세는 같은 순서로 쓴다.

- **머리말**: 주차, 우선순위(P0/P1/P2), 화면 번호, 근거 절, 선행 작업(백엔드 포함)
- **목적**
- **화면과 동작**: 보이는 것, 누르면 일어나는 것. 문구는 따옴표 그대로
- **사용하는 백엔드**: 호출하는 테이블·RPC·함수. 이름은 [백엔드 명세](../../backend/spec/README.md)와 같다
- **예외 처리**: 에러 코드별 문구. 코드 표는 [백엔드 README의 에러 코드](../../backend/spec/README.md#에러-코드-프론트와의-약속)
- **완료 조건**: 단위 테스트(Vitest)와 직접 확인할 항목
- **범위 밖**

## 목록

| ID | 제목 | 화면 | 주차 | 우선순위 | 선행 |
|---|---|---|---|---|---|
| [FE-01](FE-01-scaffold.md) | 프로젝트 뼈대·공용 유틸 | - | 1 (11/25) | P0 | - |
| [FE-02](FE-02-login.md) | 로그인·인증 상태·인앱 탈출 | ① | 1 (11/26) | P0 | FE-01, BE-01, BE-04 |
| [FE-03](FE-03-profile-setup.md) | 프로필 설정 | ①-a | 1 (11/27) | P0 | FE-02, BE-01 |
| [FE-04](FE-04-home-tree.md) | 홈 = 공개 트리 | ⓪ | 1 (11/27) | P0 | FE-01, BE-03 |
| [FE-05](FE-05-card-editor.md) | 카드 꾸미기·수정·삭제 | ② | 1 (11/28) | P0 | FE-02, FE-04, BE-03 |
| [FE-06](FE-06-card-view.md) | 카드 보기·좋아요·신고·작성자 프로필 | ③, ③-1 | 1 (11/29) | P0 | FE-05, BE-03 |
| [FE-07](FE-07-group-create.md) | 그룹 만들기·초대 링크 공유 | ⑤ | 2 (11/30) | P0 (공유 P1) | FE-02, BE-06, BE-08 |
| [FE-08](FE-08-invite-join.md) | 초대 랜딩·참여 | ⑥ | 2 (11/30) | P0 | FE-02, BE-06, BE-08 |
| [FE-09](FE-09-group-home.md) | 그룹 홈·집 내부 | ⑦, ⑦-E | 2 (12/1) | P0 (요정 연출 P1) | FE-07, BE-06, BE-07, BE-10 |
| [FE-10](FE-10-gift-editor.md) | 선물상자 꾸미기 | ⑧ | 2 (12/2~3) | P0 (사진·음반 P1) | FE-09, BE-07, BE-08, BE-09 |
| [FE-11](FE-11-open.md) | 개봉 | ⑨ | 3 (12/7) | P0 (답장 P2) | FE-10, BE-11 |
| [FE-12](FE-12-my-page.md) | 마이페이지 | ⑩ | 3 (12/8) | P0 | FE-03, FE-09, BE-01 |
| [FE-13](FE-13-card-list.md) | 카드 목록 | ④ | 3 | P1 | FE-06 |
| [FE-14](FE-14-carol.md) | 배경 캐롤 | 모든 화면 | 2 (12/6) | P1 | FE-01 |
| [FE-15](FE-15-card-stickers-drawing.md) | 카드 스티커·직접 그리기 | ② | 3 이후 | P1 | FE-05, BE-15 |
| [FE-16](FE-16-nudge-fallback.md) | 알림 대체·넛지 배너·링크 미리보기 | ⓪, ⑦ | 3 (12/9) | P0 | FE-04, FE-09 |
| [FE-17](FE-17-admin.md) | 관리 화면 | - | 3 | P1 | BE-13 |

1주차 작업(FE-01~06)의 단계별 실행 순서는 [1주차 계획](../../docs/superpowers/plans/2026-11-25-week1-foundation-public-tree.md)에 있다(F1~F6와 같은 작업).

P2(트리 점등, 보낸 상자 화면)는 동작이 정해지지 않아 명세가 없다. 시간이 남으면 그때 명세부터 쓴다. 고마워요 답장(P2)은 FE-11에 포함했다.

## 공통 규칙

- 모바일 우선. 기준 폭 375px. Tailwind CSS.
- 글자 수는 `countChars`(코드 포인트)로 센다. `string.length`를 쓰지 않는다. 입력값은 앞뒤 공백을 지우고 보낸다.
- 시각은 `fetchAppConfig()`로 받은 값으로만 판단한다. 날짜를 코드에 직접 쓰지 않는다(예외: D-n 계산 기준일 12/25).
- 로그인이 필요한 동작을 비로그인이 누르면 `/login?returnTo=<현재 경로>`로 보낸다. `returnTo`는 항상 `safeReturnTo`를 거친다.
- 제출 버튼은 요청 중 비활성화한다(두 번 누르기 방지).
- `service_role` 키를 프론트에 넣지 않는다. 환경 변수는 `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_KAKAO_JS_KEY`뿐이다.
- 받은 선물 개수를 **숫자로** 보여주는 곳이 없어야 한다(그룹 홈, 집, 마이페이지).
- 디자인 시안이 없는 화면은 프로토타입 v1과 Lo-fi 와이어프레임을 따른다. 그룹 홈은 요정/산타 중 디자이너가 정한 버전으로 만든다.

## 라우트

| 경로 | 화면 | 작업 | 로그인 필요 |
|---|---|---|---|
| `/` | ⓪ 홈 | FE-04 | 아니오 |
| `/login` | ① 로그인 | FE-02 | 아니오 |
| `/auth/callback` | 로그인 콜백 | FE-02 | - |
| `/profile/setup` | ①-a 프로필 설정 | FE-03 | 예 |
| `/cards` | ④ 카드 목록 | FE-13 | 아니오 |
| `/cards/new`, `/cards/:id/edit` | ② 카드 꾸미기 | FE-05 | 예 |
| `/cards/:id` | ③ 카드 보기 | FE-06 | 아니오 |
| `/groups/new` | ⑤ 그룹 만들기 | FE-07 | 예 |
| `/g/:code` | ⑥ 초대 랜딩 | FE-08 | 아니오 (참여는 예) |
| `/groups/:groupId` | ⑦ 그룹 홈 | FE-09 | 예 (멤버만) |
| `/groups/:groupId/members/:userId` | ⑦-E 집 내부 | FE-09 | 예 (멤버만) |
| `/groups/:groupId/gifts/new`, `/groups/:groupId/gifts/:boxId/edit` | ⑧ 선물상자 꾸미기 | FE-10 | 예 (멤버만) |
| `/groups/:groupId/open` | ⑨ 개봉 | FE-11 | 예 (멤버만) |
| `/me` | ⑩ 마이페이지 | FE-12 | 예 |
| `/admin` | 관리 화면 | FE-17 | 관리자 |
