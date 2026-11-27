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
