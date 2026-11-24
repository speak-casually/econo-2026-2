# Christmas Gift For You · 기술 스택

작성일 2026-11-22 · 개정 2026-11-25 (Spring Boot + AWS에서 Supabase로 변경) · 상태: 확정 (명세 정리 전 단계)

## 1. 목표와 배경

- **무엇**: 공개 트리(카드 걸기)와 비공개 그룹(선물상자·마니또·12/25 일괄 개봉)을 제공하는 모바일 웹.
- **고정 날짜**: 12/21 공개, 12/24 23:59 마감, 12/25 12:25 개봉. 2027-01-31 데이터 일괄 파기.
- **팀**: FE 1명, BE·PM 1명, 디자이너 1명. BE는 백엔드가 처음이다.
- **왜 이 스택인가**: 크리스마스는 미룰 수 없다. 백엔드 경험 없이 4주 안에 인증·DB·스토리지·스케줄·인프라를 직접 구성하면 오픈을 놓칠 위험이 크다. 그래서 이것들을 한 번에 제공하는 Supabase를 쓴다. 대신 SQL 스키마, RLS(행 단위 권한), DB 함수는 직접 작성해서 백엔드 기본기를 쌓는다.
- **일정**: 계획 문서(일정 artifact)를 따른다. 구현 11/25~12/13, QA 12/13~15, 수정 12/16~18(12/18 코드 동결), 12/19 운영 배포.
- **참고 자료**: 계획 artifact(일정·범위), 디자인 자료 산타 버전(정보구조, Lo-fi 와이어프레임, 루프 다이어그램, 두 공간 비교와 마니또 추첨, 핵심 시나리오 흐름도. 기준 design.md·정책명세서.md·기능명세서.md 2026-11-19), 프로토타입 v1 화면 ⓪~⑩.

## 2. 검토한 선택지

| 안 | 내용 | 결과 |
|---|---|---|
| **React + Supabase** | 인증·DB·스토리지·크론·서버 함수를 한 서비스에서 제공한다. 로컬 개발 환경(`supabase start`)이 있다 | **채택** (2026-11-25) |
| Spring Boot + React + AWS | 국내 채용 스택. 첫 주에 OAuth 세션, CloudFront, EC2/RDS, CD를 동시에 처음 배워야 한다 | 기각: 첫 백엔드로 마감을 맞추기 어렵다. 오픈 후 학습 과제로 미룸 |
| Next.js + NestJS + AWS | TypeScript 단일 언어 | 기각: 인프라 부담은 Spring안과 같다 |
| Firebase | 카카오 로그인은 커스텀 토큰이 필요하고, 관계형 데이터(그룹·멤버·선물)에 맞지 않는다 | 기각 |

## 3. 스택

### 백엔드: Supabase
| 영역 | 선택 | 비고 |
|---|---|---|
| DB | Postgres (Supabase) | 스키마는 `backend/supabase/migrations/*.sql`로 버전 관리 |
| API | 자동 생성 REST(PostgREST) + `supabase-js` | 단순 CRUD는 클라이언트가 바로 호출. 여러 행을 함께 바꾸는 작업은 Postgres 함수(RPC)로 |
| 권한 | RLS | **보안의 전부.** 아래 「권한 규칙」 참고 |
| 인증 | Supabase Auth: 카카오, 구글 | 세션은 브라우저 localStorage(JWT)에 저장. 쿠키 도메인 문제가 없다 |
| 파일 | Supabase Storage | 비공개 버킷 + 서명 URL |
| 서버 코드 | Edge Functions (Deno, TypeScript) | 브라우저가 직접 할 수 없는 일에만 쓴다: 카카오 토큰 저장(`save-kakao-token`), 카톡 발송(`send-open-notifications`), YouTube 링크 검사·정보 조회(`youtube-meta`) |
| 스케줄 | Supabase Cron (pg_cron) + pg_net | 두 개만: 12/25 11:00 추첨 안전장치(`run_draw(null, 'auto')`), 12/25 12:25 개봉 알림 발송. 잠금·개봉은 스케줄이 필요 없다(아래 참고) |
| 테스트 | pgTAP (`supabase test db`) | RLS 잠금, 추첨 함수 우선 |

### 프론트엔드
| 영역 | 선택 | 비고 |
|---|---|---|
| 프레임워크 | React + Vite + TypeScript | |
| 라우팅 | React Router | |
| 스타일 | Tailwind CSS | 모바일 우선 |
| 데이터 | `@supabase/supabase-js` | 타입은 `supabase gen types typescript`로 생성 |
| 그리기 (P1) | Canvas API | |
| 음악 | YouTube IFrame Player API + `<audio>`(캐롤) | 음반 재생 중에는 캐롤을 멈춤 |
| 카톡 공유 | Kakao JavaScript SDK | 초대 링크 공유 |
| 인앱 브라우저 탈출 | User-Agent 감지 + `kakaotalk://web/openExternal?url=` | **구글 로그인은 인앱 브라우저(웹뷰)에서 막힌다**(`disallowed_useragent`). 구글 버튼은 외부 브라우저로 보낸 뒤 실행 |

### 호스팅
| 영역 | 선택 | 비고 |
|---|---|---|
| 프론트 | Vercel (Hobby, 비상업) | `main` 푸시 시 자동 배포, PR마다 미리보기 URL. SPA 라우팅은 `vercel.json` rewrites |
| 도메인 | 기본 `*.vercel.app`, 필요하면 구매 도메인 연결 | HTTPS 자동. 도메인이 바뀌면 카카오 사이트 도메인과 Supabase Redirect URL을 다시 등록해야 하므로 12/19 전에 확정 |

```
브라우저 (React, Vercel)
  ├─ supabase-js ──> Supabase
  │                   ├─ Auth (카카오·구글)
  │                   ├─ Postgres + RLS  ← 모든 권한 판정
  │                   ├─ Storage (gift-photos 비공개, card-images·avatars 공개)
  │                   └─ Edge Functions ──> Kakao API (토큰 갱신, 나에게 보내기)
  │                          ▲
  │                   Cron (12/25 11:00 추첨 안전장치, 12:25 알림) ┘
  └─ Kakao JS SDK (공유)
```

## 4. 핵심 구현 방식

### 4.1 시각 규칙: 스케줄러 대신 DB 비교
마감·개봉은 "그 시각에 무언가를 실행"하지 않는다. RLS가 매 요청마다 `now()`와 설정 시각을 비교한다.

```sql
create table app_config (
  id boolean primary key default true check (id),  -- 한 행만
  deadline_at      timestamptz not null,  -- 2026-12-24 23:59 +09  그룹 생성·참여, 선물 놓기·수정·삭제 마감
  open_at          timestamptz not null,  -- 2026-12-25 12:25 +09  선물 개봉
  tree_deadline_at timestamptz not null   -- 2026-12-25 23:59 +09  공개 트리 카드 걸기 마감
);
```
- 공개 트리는 카드를 거는 즉시 누구나(비로그인 포함) 본다. 열람은 파기일(1/31)까지 계속된다.
- 시각은 항상 `timestamptz`로 저장한다. **pg_cron은 UTC 기준**이라 12/25 12:25 KST는 cron에서 `25 3 25 12 *`이다.
- **리허설**: 서버 시계를 바꾸지 않는다. 스테이징 프로젝트의 `app_config` 시각을 "지금+10분"으로 바꾸면 마감, 추첨, 개봉, 알림을 하루 안에 돌려 볼 수 있다.

### 4.2 권한 규칙 (RLS)
서버 코드 없이 브라우저가 DB를 직접 호출한다. **UI에서 숨기는 것은 보안이 아니다.** 모든 테이블에 RLS를 켜고, 아래 규칙은 pgTAP 테스트로 확인한다.

**RLS는 행 단위다. 열 단위로 숨기지 못한다.** 집 내부(⑦-E)에서 멤버들은 "트리 아래 상자 그림"을 본다. 하지만 보낸 사람과 속 내용은 12/25 12:25까지 잠긴다. 그래서 상자를 **겉과 속 두 테이블로 나눈다.** 보낸 사람 정보가 겉 테이블에 있으면 같은 그룹 멤버 누구나 조회할 수 있게 된다.

| 대상 | 읽기 | 쓰기 |
|---|---|---|
| `profiles` (닉네임, 프로필 사진만) | 모두 | 본인만 추가·수정. 닉네임 1~12자 |
| `user_settings` (필수 동의 시각 2개, `kakao_notify`, `first_home_visit_at`) | 본인만 | 본인만. 공개 열과 섞지 않으려고 `profiles`와 분리한다(RLS가 행 단위라서) |
| `tree_cards` | 숨김이 아닌 카드는 비로그인 포함 모두. 숨긴 카드는 작성자 본인과 관리자만 | 추가·수정: 본인, `now() < tree_deadline_at`. 삭제: 본인, 언제든. 1인 1장(`unique(user_id)`), 편지 1~300자, 스티커 20개, 금칙어 트리거 통과. `like_count`·`hidden`은 열 권한(`grant insert/update (열 목록)`)으로 클라이언트가 못 바꾼다 |
| `card_likes` | **카드 작성자와 좋아요 누른 본인만** (누른 사람 목록은 작성자만 본다) | 본인 것만 추가·삭제, `unique(card_id, user_id)`. 개수는 `tree_cards.like_count`(트리거로 갱신)로 공개 |
| `reports` | 관리자만 | 로그인 사용자가 추가. 대상은 카드 또는 프로필 |
| `groups`, `group_members` | 같은 그룹 멤버만 | 생성·참여 모두 RPC로만: `create_group(name, all_manito, manito_box)`, `join_group(code, manito_box)`. 둘 다 `now() < deadline_at` 확인 |
| `gift_boxes` (겉: 받는 사람, 종류, 상자 색, 리본 색, 스티커, `opened_at`) | 같은 그룹 멤버. **보낸 사람 열 없음** | RPC로만: `place_gift`, `update_gift`, `delete_gift`, `open_gift` |
| `gift_box_contents` (속: 보낸 사람, 편지, 사진 경로, 음반) | 보낸 사람은 항상. **받는 사람은 `now() >= open_at`일 때만** | RPC로만(위와 같음). 겉에 보낸 사람 열이 없어서 RLS만으로는 "보낸 사람만 수정·삭제"를 표현할 수 없다 |
| `gift_replies` (고마워요 50자, P2) | 받은 사람, 보낸 사람 | 받은 사람이 개봉 후 상자당 1회 |
| Storage `gift-photos` | 올린 본인, 그리고 그 경로를 `photo_paths`에 담은 속 행을 읽을 수 있는 사람(개봉 후 받는 사람). 정책 안의 하위 조회에 `gift_box_contents`의 RLS가 그대로 적용된다 | 경로 첫 폴더가 본인 id일 때만, 마감 전에만. 상자를 만들기 전에 올릴 수 있어야 해서 상자 id가 아니라 올린 사람 기준으로 나눈다 |

- **관리자 판별**: `auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'`. `app_metadata`는 사용자가 바꿀 수 없다(`user_metadata`는 바꿀 수 있으니 쓰지 않는다).
- **방장 없음**: 그룹을 만든 사람도 일반 멤버다. 그룹 관리 권한을 두지 않는다.
- **초대 랜딩(⑥)**: 멤버가 아니어도 그룹 이름과 멤버 수만 봐야 한다. `get_invite(code)` `security definer` 함수가 이 두 값만 돌려준다.
- **그룹 참여**: `join_group`은 그룹 행을 `for update`로 잠근 뒤 인원을 센다(정원 30). 동시에 참여해도 31명이 되지 않는다.
- **모두 마니또**: 멤버 행과 마니또 상자가 **한 트랜잭션**에서 함께 생긴다. 켜진 그룹에서는 `create_group`·`join_group`의 `manito_box`가 필수이고, 꺼진 그룹에서는 무시한다. 그래서 "상자를 만들어야 멤버 확정"이 DB에서 보장된다. 사진은 미리 올려 둔 경로를 넘긴다(Storage 행 참고). 초대 랜딩의 멤버 수는 확정된 멤버만 센다.
- **선물 규칙**: `place_gift`가 검사한다. 지정 선물은 **그룹 안에서** 보낸 사람·받는 사람 쌍마다 1개, 받는 사람은 같은 그룹의 자기 외 멤버. 마니또는 그룹마다 1인 1개. 속에는 편지(1~1000자)·사진(최대 5장)·음반 1곡 중 1개 이상. 보낸 사람과 받는 사람이 서로 다른 테이블에 있어 unique 제약을 걸 수 없으므로, 같은 보낸 사람의 동시 요청은 `pg_advisory_xact_lock(그룹, 보낸 사람)`으로 줄 세운다.
- **수정·삭제**: `update_gift`는 마감 전, 보낸 사람만. 받는 사람은 바꿀 수 없다. `delete_gift`는 마감 전, 보낸 사람만. 모두 마니또 그룹의 마니또 상자는 삭제를 거부한다.
- **개봉**: `open_gift(box_id)`는 받는 사람만, `now() >= open_at`일 때 `opened_at`이 비어 있으면 채운다.
- **숫자 표시 없음**: 그룹 홈과 집 내부에는 받은 개수를 숫자로 보여주지 않는다. 개수를 돌려주는 API를 만들지 않는다.
- **프로필 신고 처리**: 관리자가 `profiles`의 사진을 지우고(기본 이미지) 닉네임을 "숨김 사용자"로 바꾼다. 숨김 열은 없다.
- `security definer` 함수는 `search_path`를 고정하고, 함수 안에서 호출자 권한을 직접 확인한다.

### 4.3 마니또 추첨
- 마감 후 관리자가 **백업 후 수동 실행**한다(실행 1명 + 확인 1명). `run_draw()` Postgres 함수는 관리자(대시보드 SQL 편집기, 즉 `postgres` 역할)만 실행할 수 있고(`revoke execute ... from public, anon, authenticated`), 트랜잭션 하나로 처리한다. `now() < deadline_at`이면 예외를 내고 아무것도 하지 않는다.
- 결과는 `gift_boxes.recipient_id`에 저장하고, 그룹별 시드와 실행 방식(수동/자동)은 `draws` 테이블에 기록한다. 다시 실행해도 이미 배정된 상자는 건드리지 않는다.
- **자동 안전장치**: Cron이 12/25 11:00 KST(`0 2 25 12 *`, UTC)에 `run_draw(null, 'auto')`를 호출한다. `run_draw`는 수동이든 자동이든 `draws` 기록이 없는 그룹만 추첨한다. 추첨은 배정되지 않은 상자의 `recipient_id`만 채우므로, 실행 전에 대상 상자 id 목록을 `draws`에 함께 남기면 되돌릴 수 있다. 이것을 백업으로 삼는다.
- **일반 규칙** (정책명세서 §5.3, "두 공간 비교와 마니또 추첨" 자료):
  1. 마니또 상자들의 처리 순서를 시드로 섞는다(`setseed(seed)` 후 `order by random()`).
  2. 상자마다 후보를 정한다. 같은 그룹 멤버에서 **본인과, 본인이 지정 선물을 이미 보낸 멤버를 뺀다.**
  3. 후보 중 **지금까지 받은 수(지정 + 앞에서 배정된 마니또)가 가장 적은 멤버**를 고른다. 동률이면 시드 난수로 고른다.
  4. 후보가 없으면 미전달로 표시하고, 보낸 사람에게 안내한다.
  - 목적: 아무것도 못 받는 멤버를 줄인다. 받은 수는 계산에만 쓰고 화면에는 보여주지 않는다.
- **모두 마니또 그룹** (요구사항 8.2): 자기 자신만 후보에서 뺀다(지정 선물을 보낸 상대도 후보). 멤버를 시드로 섞어 한 줄로 세우고 각자 다음 사람에게, 마지막 사람은 첫 사람에게 보낸다(하나의 순환). 2명 이상이면 항상 성공한다. 1명이면 미전달.
- 테스트: 자료의 예시 그룹 5명을 재현한다(받은 수 최소 규칙이 강제하는 배정 확인, 동률은 시드에 따름). 일반 그룹: 자기 배정 없음, 지정 선물을 보낸 상대에게는 배정되지 않음, 후보 없음이면 미전달, 같은 시드면 같은 결과, 이미 배정된 상자는 다시 실행해도 그대로. 모두 마니또: 1명·2명·3명·30명에서 모두 정확히 1개씩 주고받음, 자기 배정 없음. 마감 전 실행은 거부.

### 4.4 12/25 카톡 알림: "나에게 보내기"
1. 카카오 로그인 시 `scopes: 'talk_message'`를 요청한다(선택 동의).
2. 로그인 직후 세션의 `provider_refresh_token`을 Edge Function `save-kakao-token`에 보낸다. **Supabase는 이 토큰을 보관해 주지 않고, 로그인 직후에만 받을 수 있다.**
3. 함수는 JWT로 사용자를 확인하고, 토큰을 AES-GCM으로 암호화해 `kakao_tokens` 테이블에 저장한다. 이 테이블은 RLS를 켜고 정책을 하나도 두지 않아서 `service_role`(Edge Function)만 접근한다. 별도 스키마에 두면 Edge Function의 supabase-js도 접근하지 못하므로 쓰지 않는다. 암호화 키는 함수 secrets에 둔다.
4. 12/25 12:25 KST에 Cron이 pg_net으로 Edge Function `send-open-notifications`를 호출한다. 함수는 동의자마다 토큰을 갱신(`POST kauth.kakao.com/oauth/token`)하고 `POST kapi.kakao.com/v2/api/talk/memo/default/send`로 발송한 뒤 결과를 `notification_logs`에 기록한다.
5. 실패한 사람만 다시 보내는 "알림 재발송"은 같은 함수에 `retry_failed` 옵션으로 둔다(운영 매뉴얼).
- 프로필 설정(①-a)과 마이페이지(⑩)의 알림 토글은 `user_settings.kakao_notify`에 저장한다. 발송 대상은 토글이 켜져 있고 토큰이 있는 사람이다.
- 동의 시점: 카카오 로그인 동의 화면에서 `talk_message`를 받는다. 거기서 거부했는데 나중에 토글을 켜면, 카카오 로그인을 다시 실행해(`scopes: 'talk_message'`) 동의 화면을 띄운다. 토큰은 그때 새로 저장된다.
- refresh token 유효기간은 약 2개월이라 12/21 이후 가입자는 문제없다.
- 구글 로그인 사용자와 미동의자는 카톡을 받지 못한다. 계획의 대체안(캘린더 추가, 홈 안내 배너)으로 보완한다.

### 4.5 사진·음반
- 사진은 브라우저에서 긴 변 1600px JPEG로 줄인 뒤 업로드한다(무료 저장 용량 절약).
- 버킷에 크기 제한(5MB)과 허용 형식(`image/jpeg`, `image/png`, `image/webp`)을 설정한다. 서버 코드 없이 버킷이 막는다.
- 경로: `gift-photos/{user_id}/{uuid}.jpg`(상자당 최대 5장). 상자를 만들기 전에 올린다(모두 마니또 입장 때는 상자와 멤버가 함께 생기므로). 읽을 때는 Storage 정책을 통과한 사용자에게만 서명 URL(`createSignedUrl`)을 준다. 상자에 쓰이지 않은 사진은 파기 때 함께 지운다.
- 공개 버킷 2개: `avatars`(프로필 사진. 안 올리면 기본 이미지), `card-images`(직접 그리기 결과를 PNG로 저장. P1). 공개 카드는 누구나 보는 것이라 서명 URL이 필요 없다. 공개 카드에는 사진·음반을 넣지 않는다.
- 음반은 YouTube 링크에서 영상 ID만 추출해 저장하고, DB `check` 제약으로 ID 형식(11자, `[A-Za-z0-9_-]`)을 검사한다.
- 제목·채널은 Edge Function `youtube-meta`가 YouTube oEmbed(`https://www.youtube.com/oembed?url=...&format=json`)로 가져온다. 브라우저에서 바로 부르면 CORS에 막힐 수 있어서다. oEmbed가 404·401이면(없는 영상, 퍼가기 금지) "재생할 수 없는 링크예요"로 거부한다. 이것이 계획의 "음반 링크 검사"다. 썸네일은 `i.ytimg.com/vi/{id}/hqdefault.jpg`를 쓴다.

### 4.6 공개 트리 운영
- **홈 트리(⓪)**: 카드 50장을 무작위로 보여준다. `random_tree_cards(50)` RPC(`order by random() limit 50`)를 쓴다. 이 규모에서는 충분하다.
- **반짝임**: 좋아요 5·20·50 단계. `like_count`만 있으면 프론트가 판단한다.
- **카드 목록(④)**: 무작위(기본)·좋아요순·최신순. `like_count`, `created_at`에 인덱스를 건다.
- **카드 보기(③)**: ‹ › 버튼은 다음 무작위 카드로 넘어간다. 좋아요는 1인 1카드 1회.
- **금칙어**: `banned_words` 테이블 + `tree_cards` insert/update 트리거. 클라이언트 검사는 안내용일 뿐이다.
- **신고·숨김**: 자동 숨김은 없다. 관리자가 하루 2회(10시·22시) 확인하고 `hidden = true`로 바꾼다. 숨긴 카드는 RLS에서 걸러진다. 신고는 `unique(reporter_id, target_type, target_id)`로 1회만. 프로필 신고 처리는 4.2 참고.
- **지표**: 성공 지표를 SQL view로 만든다(요구사항 13절). 두 분모를 모두 계산한다. "공개 트리를 연 가입자"는 로그인 사용자가 홈을 처음 열 때 `user_settings.first_home_visit_at`을 채워서 센다.

### 4.7 캐롤
- 모든 화면에서 켜기·끄기(🔔). `<audio>`를 라우트 바깥(최상위 레이아웃)에 두어 화면을 옮겨도 끊기지 않게 한다. 설정은 localStorage에 저장한다.
- 브라우저 자동재생 정책 때문에 처음에는 꺼진 상태로 시작하고, 사용자가 눌러야 재생된다.
- 선물상자에서 음반(YouTube)을 재생하면 캐롤을 멈춘다.

### 4.8 데이터 파기 (2027-01-31)
- 삭제 스크립트(SQL)로 사용자 데이터와 Storage 객체, `auth.users`를 지운다. 이후 프로젝트를 삭제한다.

## 5. 환경과 CI/CD

| 환경 | 구성 | 용도 |
|---|---|---|
| 로컬 | `supabase start`(docker) + Vite 개발 서버 | 개발, pgTAP 테스트 |
| 스테이징 | Supabase 프로젝트 1 + Vercel 미리보기 | 실기기·카톡 인앱 테스트, 리허설 |
| 운영 | Supabase 프로젝트 2 + Vercel 운영 | 12/19 배포 |

Supabase 무료 요금제는 활성 프로젝트 2개까지라 스테이징과 운영이 딱 맞는다.

**브랜치 전략**
```
feature/*, docs/*  ──PR──>  develop  ──PR(릴리스)──>  main
                    (CI)    스테이징 배포           운영 배포
```

**CI (PR마다, GitHub Actions)**
| 대상 | 내용 |
|---|---|
| DB | `supabase start` → `supabase db reset` → `supabase test db` (마이그레이션 적용 + RLS·추첨 테스트) |
| 프론트 | lint, 타입 체크, `vite build` |
| 경로 필터 | `backend/supabase/**`, `frontend/**` 변경 시 해당 작업만 |

**CD**
- DB·함수: `develop` 머지 시 스테이징에, `main` 머지 시 운영에 `supabase db push` + `supabase functions deploy`
- 프론트: Vercel Git 연동(브랜치별 자동 배포)
- GitHub Secrets: `SUPABASE_ACCESS_TOKEN`, 프로젝트 ref 2개, DB 비밀번호 2개

**운영 규칙**
- 스키마 변경은 마이그레이션 파일로만 한다. 운영 대시보드에서 직접 고치지 않는다.
- 카카오 client secret, 토큰 암호화 키는 Edge Function secrets(`supabase secrets set`)에 둔다. `service_role` 키는 프론트·레포에 절대 넣지 않는다.
- 12/18 코드 동결 이후는 버그 수정만, **12/24 ~ 12/25 배포 금지.**

### 레포 구조
```
econo-2026-2/
├── backend/
│   ├── spec/             # 백엔드 작업별 명세 (BE-00~)
│   └── supabase/         # backend/에서 `supabase init`으로 생성
│       ├── config.toml
│       ├── migrations/   # 스키마·RLS·함수 SQL
│       ├── functions/    # Edge Functions (save-kakao-token, send-kakao-test, send-open-notifications, youtube-meta)
│       ├── tests/        # pgTAP
│       └── scripts/      # 운영 스크립트 (BE-14)
├── frontend/
│   ├── spec/             # 프론트 작업별 명세 (FE-01~)
│   └── (React + Vite)
├── docs/
└── .github/workflows/
```

- 문서의 파일 경로는 레포 루트 기준이다(`backend/supabase/...`).
- Supabase CLI(`supabase start`, `supabase test db`, `supabase db push` 등)는 **`backend/`에서 실행한다.** CI와 배포 워크플로도 작업 디렉터리를 `backend`로 둔다.
- 프론트 타입 생성은 `frontend/`에서 `supabase gen types typescript --local --workdir ../backend > src/lib/database.types.ts`.

## 6. 무료 요금제 한도와 대체 방안

**확인할 한도** (가입 시 요금 페이지에서 수치 확인)
- DB 500MB, Storage 1GB, 월 전송량, MAU 50,000, Edge Function 호출 수
- **자동 백업 없음**: 추첨 전과 12/24 마감 직후에 `supabase db dump`(또는 `pg_dump`)로 수동 백업한다.
- 7일간 활동이 없으면 프로젝트가 일시정지된다. 개발 기간에는 해당 없음.

**사진 용량 추정**: 그룹 10개 × 30명 × 사진 최대 5장 × 약 300KB ≈ 450MB. 1GB 안이다.

**12/15 결정 (계획과 동일)**: QA에서 측정한 사용량으로 결정한다.
1. 무료 유지
2. Supabase Pro로 한 달 업그레이드 (이전 작업 없음, 백업 포함)
3. 자체 설치로 이전 (동아리 server2, 안 되면 팀원 미니 PC): 마이그레이션 파일로 스키마를 그대로 옮긴다. `auth` 스키마 덤프와 Storage 객체 복사가 필요하고, JWT secret이 바뀌면 사용자가 다시 로그인해야 한다. 이전 절차는 12/9 운영 매뉴얼에 적고 12/16~17에 실제로 해 본다.

## 7. 기술 위험 순서 (계획 일정에 맞춤)

| 주 | 기간 | 먼저 확인할 기술 위험 |
|---|---|---|
| 1 | 11/25 ~ 11/29 | 11/25 카톡 "나에게 보내기" 실제 발송(4.4의 1~4 수동 확인). 카카오·구글 로그인(인앱 브라우저 탈출 포함). 개봉 전 잠금 RLS 테스트. 공개 트리 |
| 2 | 11/30 ~ 12/6 | 그룹·초대(`join_group`, 정원), 선물상자 마감 잠금, Storage RLS, 추첨 함수와 테스트 |
| 3 | 12/7 ~ 12/13 | Cron 개봉 알림·추첨 안전장치, 관리자 화면(P1), 12/10 스테이징 전원 리허설(4.1 방식), 12/11 보안 점검(RLS 전 테이블, `service_role` 노출 여부) |

## 8. 결정 기록

- 백엔드: Spring Boot + AWS에서 **Supabase**로 변경 (2026-11-25). 첫 백엔드 경험으로 12/21 오픈을 맞추기 위함. 이에 따라 2026-11-22에 정한 CloudFront 단일 진입점, EC2·RDS, GHCR+SSH CD 결정은 폐기
- 프론트 호스팅: Vercel (2026-11-25)
- 잠금·개봉: 스케줄러 대신 RLS 시각 비교, 리허설은 `app_config` 시각 변경 (2026-11-25)
- 선물상자: 겉(`gift_boxes`)과 속(`gift_box_contents`) 테이블 분리. RLS가 행 단위라서 (2026-11-25)
- 마니또 추첨: 받은 수가 가장 적은 멤버 우선, 동률은 시드 난수 (정책명세서 §5.3 반영, 2026-11-25)
- 12/25 알림: 카카오 "나에게 보내기" (2026-11-22, 유지)
- 그룹 홈: 요정/산타 버전은 디자인이 결정한다. 데이터 구조는 같다 (2026-11-25)
- 브랜치: develop(스테이징) → main(운영) (2026-11-22, 대상만 변경)
- 모두 마니또 추첨은 자기 자신만 빼는 순환 배정, 12/25 11:00 추첨 자동 안전장치, 공개 전 접속 허용, 카드 수정 허용 (요구사항 14절, 2026-11-25)
- 그룹 생성·참여·선물 쓰기는 모두 RPC로만. 사진 경로는 올린 사람 기준, 공개 프로필과 개인 설정 테이블 분리 (요구사항과 대조 후, 2026-11-25)

## 9. 미결·확인 필요

- Supabase 카카오 provider의 이메일 동의 요구 여부. 비즈 앱 전환 없이 가능한지 11/25 테스트에서 확인
- `talk_message` 선택 동의 항목 사용 조건(카카오 개발자 콘솔)
- 구글 로그인 운영 전환(OAuth 동의 화면 게시) 소요 기간
- YouTube oEmbed가 브라우저에서 CORS를 허용하는지. 허용하면 `youtube-meta` 없이 브라우저에서 직접 부른다
- 동작 규칙은 [요구사항 명세](2026-11-25-requirements-design.md)에서 확정했다(모두 마니또, 지표 분모, 고마워요 답장 P2 등). 원문 명세서(design.md 등)는 없다
- 오픈 후 학습 과제: 같은 도메인을 Spring Boot로 재구현
