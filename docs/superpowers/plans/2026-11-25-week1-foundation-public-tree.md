# 1주차: 기반·위험 확인·공개 트리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카카오·구글 로그인과 프로필 설정을 거쳐 공개 트리에 카드를 걸고, 보고, 좋아요·신고할 수 있게 한다. 동시에 가장 큰 기술 위험 두 가지(카톡 "나에게 보내기", 개봉 전 잠금 RLS)를 1주차 안에 확인한다.

**Architecture:** Supabase(Postgres + RLS + Edge Functions)가 백엔드 전부다. 브라우저(React)는 `supabase-js`로 DB를 직접 호출하고, 권한은 모두 RLS와 `security definer` RPC가 판정한다. 비밀 키가 필요한 카카오 토큰 처리만 Edge Function에서 한다.

**Tech Stack:** Supabase CLI(로컬 docker), Postgres 15+, pgTAP, Deno(Edge Functions), React 19 + Vite + TypeScript, Tailwind CSS v4(`@tailwindcss/vite`), React Router, `@supabase/supabase-js` v2, Vitest, GitHub Actions.

**Spec:** [요구사항 명세](../specs/2026-11-25-requirements-design.md) (동작), [기술 스택](../specs/2026-11-22-tech-stack-design.md) (구현 방식). 둘 다 읽고 시작한다.

**전체 계획 중 위치** (주차별 계획 3개)
1. **이 문서 (11/25~11/29)**: 기반, 위험 확인, 로그인·프로필, 공개 트리 P0
2. 2주차 (11/30~12/6): 그룹·초대·모두 마니또, 선물상자(놓기·수정·삭제, 사진, 음반·`youtube-meta`), 추첨 함수
3. 3주차 (12/7~12/13): 개봉, 카톡 알림 Cron, 추첨 안전장치 Cron, 지표 view, 마이페이지, 운영 스크립트(파기·리허설), P1(카드 목록, 스티커, 캐롤, 관리 화면)

**담당 구분**: 작업은 **백엔드(B, BE·PM 담당)**와 **프론트엔드(F, FE 담당)**로 나눴다. 두 사람이 동시에 진행한다. 프론트 작업은 각 작업의 Interfaces에 적힌 백엔드 작업이 `develop`에 머지된 뒤 시작하거나, 그 전에는 같은 이름의 가짜 데이터로 화면을 먼저 만든다.

| 날짜 | 백엔드 | 프론트엔드 |
|---|---|---|
| 11/25 (수) | B0 카톡 발송 수동 확인, B1 기반 | F1 프로젝트 뼈대 |
| 11/26 (목) | B4 카카오 토큰 함수, B5 스테이징 | F2 로그인 |
| 11/27 (금) | B3 공개 트리 스키마 | F3 프로필 설정, F4 홈 트리 |
| 11/28 (토) | B2 개봉 전 잠금 RLS | F5 카드 꾸미기 |
| 11/29 (일) | 통합 확인 (BE·FE 함께) → 시연·회고 | F6 카드 보기 |

## Global Constraints

- 모든 시각은 KST(+09:00). DB에는 `timestamptz`로 저장. 마감 `2026-12-24 23:59:00+09`, 개봉 `2026-12-25 12:25:00+09`, 걸기 마감 `2026-12-25 23:59:00+09`.
- "마감 전" = `now() < 시각`, "개봉 후" = `now() >= 시각`.
- 글자 수는 **유니코드 코드 포인트** 기준. Postgres `char_length`와 같아야 하므로 프론트는 `string.length`가 아니라 `countChars`(F1)를 쓴다.
- 닉네임 1~12자, 공개 카드 편지 1~300자, 카드 스티커 최대 20개. 공백만 있는 문자열은 빈 값으로 본다.
- 모든 public 테이블은 RLS를 켠다. `service_role` 키는 프론트 코드·레포·`.env.example`에 넣지 않는다.
- 관리자 판별: `auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'`. `user_metadata`는 쓰지 않는다.
- `security definer` 함수는 `set search_path = ''`를 두고 이름을 스키마까지 적는다(`public.profiles`).
- 사용자에게 보이는 문구는 요구사항 명세에 따옴표로 적힌 것을 그대로 쓴다.

### pgTAP 테스트 규칙 (B 작업 공통)

파일은 `supabase/tests/database/*.test.sql`. 각 파일은 `begin; select plan(N); ... select * from finish(); rollback;` 구조다. 사용자 흉내는 아래처럼 한다.

```sql
-- 준비 데이터는 기본 역할(postgres)로 넣는다
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.local');

-- 사용자 a로 전환
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

-- 비로그인으로 전환
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

-- 다시 준비 데이터를 넣을 때
reset role;
```

준비 단계에서 만든 행의 id가 테스트 문장에 필요하면 psql의 `\gset`으로 변수에 담고 `:'card_id'`처럼 쓴다(예: `select id as card_id from public.tree_cards where letter = '메리 크리스마스' \gset`). `$$ ... $$` 안에서는 변수가 치환되지 않으므로 `format($$ ... %L $$, :'card_id')`로 넘긴다.

시각에 따른 동작은 서버 시계 대신 `update public.app_config set open_at = now() - interval '1 minute';`처럼 설정값을 옮겨서 시험한다(`reset role` 상태에서).

## Review Focus

이 다섯 가지는 명세가 직접 말하지 않지만 실제 사용자가 가장 먼저 부딪힐 상황이다. 각각 아래 작업에 테스트로 넣었다.

1. **이모지 글자 수**: "🎄"를 300번 쓰면 JS `length`는 600이지만 DB는 300으로 센다. 프론트가 막거나 DB가 거부하면 안 된다. → F1 `countChars` 테스트, B3 이모지 300자 편지 테스트
2. **로그인 후 돌아갈 주소 조작**: `/login?returnTo=//evil.com` 같은 값으로 외부 사이트로 보내면 안 된다. → F2 `safeReturnTo` 테스트
3. **공백만 있는 닉네임·편지**: 공백만 입력해도 빈 값으로 거부한다. → B1·B3 테스트
4. **숨긴 카드에 직접 접근**: 숨긴 카드의 URL이나 id를 아는 사람이 보거나 좋아요를 누를 수 없다. → B3 테스트, F6 "카드를 찾을 수 없어요"
5. **카드 걸기 두 번 누르기**: 버튼을 빠르게 두 번 눌러도 카드는 1장이고, 두 번째 요청은 "이미 카드를 걸었어요"로 안내한다. → B3 unique 테스트, F5 처리

---

## 백엔드

### Task B0: 카톡 "나에게 보내기" 수동 확인 (코드 없음, 11/25)

가장 큰 위험을 첫날 확인한다. 우리 코드 없이 카카오 API만으로 메시지가 오는지 본다.

**Files:**
- Create: `docs/ops/kakao-check.md` (확인 결과 기록)

- [ ] **Step 1: 카카오 개발자 앱 설정**

카카오 디벨로퍼스에서 앱을 만들고 다음을 설정한다.
- 플랫폼 > Web 사이트 도메인: `http://localhost:5173`
- 카카오 로그인 활성화, Redirect URI: `http://localhost:5173/oauth-test`, `http://127.0.0.1:54321/auth/v1/callback`
- 보안 > Client Secret 활성화
- 동의항목: 닉네임·프로필 사진(필수 또는 선택), **카카오톡 메시지 전송 `talk_message`(선택 동의)**. 이메일(`account_email`)을 켤 수 있는지(비즈 앱 전환 필요 여부)도 확인한다.

- [ ] **Step 2: 인가 코드 받기**

브라우저에서 아래 주소를 열고 동의한 뒤, 주소창의 `code=` 값을 복사한다(페이지가 안 떠도 된다).

```
https://kauth.kakao.com/oauth/authorize?client_id=<REST_API_KEY>&redirect_uri=http://localhost:5173/oauth-test&response_type=code&scope=talk_message
```

- [ ] **Step 3: 토큰 발급**

```bash
curl -s -X POST https://kauth.kakao.com/oauth/token \
  -d grant_type=authorization_code -d client_id="$KAKAO_REST_API_KEY" \
  -d client_secret="$KAKAO_CLIENT_SECRET" \
  -d redirect_uri=http://localhost:5173/oauth-test -d code="$CODE"
```
Expected: `access_token`, `refresh_token`, `refresh_token_expires_in`이 있는 JSON.

- [ ] **Step 4: 나에게 보내기**

```bash
curl -s -X POST https://kapi.kakao.com/v2/api/talk/memo/default/send \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  --data-urlencode 'template_object={"object_type":"text","text":"Christmas Gift For You 테스트","link":{"web_url":"http://localhost:5173","mobile_web_url":"http://localhost:5173"},"button_title":"열어보기"}'
```
Expected: `{"result_code":0}`. 카카오톡 "나와의 채팅"에 메시지가 온다.

- [ ] **Step 5: refresh token으로 갱신**

```bash
curl -s -X POST https://kauth.kakao.com/oauth/token \
  -d grant_type=refresh_token -d client_id="$KAKAO_REST_API_KEY" \
  -d client_secret="$KAKAO_CLIENT_SECRET" -d refresh_token="$REFRESH_TOKEN"
```
Expected: 새 `access_token`. 갱신한 토큰으로 Step 4를 다시 실행해 성공하면 통과.

- [ ] **Step 6: 결과 기록 후 커밋**

`docs/ops/kakao-check.md`에 적는다: 성공 여부, `refresh_token_expires_in` 값(초), `account_email` 사용 가능 여부, 실패했다면 에러 응답 원문. **실패하면 그날 팀에 알리고 계획의 대체안(캘린더·홈 안내)으로 전환을 논의한다.**

```bash
git add docs/ops/kakao-check.md
git commit -m "docs: record Kakao memo API manual check"
```

### Task B1: Supabase 기반 (설정 시각, 프로필, 개인 설정, 아바타 버킷, CI)

**Files:**
- Delete: `backend/.gitkeep`
- Create: `supabase/` (`supabase init`으로 생성), `supabase/migrations/20261125000100_base.sql`, `supabase/tests/database/base.test.sql`, `.github/workflows/ci.yml`
- Modify: `supabase/config.toml` (auth 설정)

**Interfaces:**
- Produces:
  - `public.app_config(id boolean, deadline_at timestamptz, open_at timestamptz, tree_deadline_at timestamptz)`: 한 행. anon·authenticated 읽기 가능
  - `public.is_admin() returns boolean`
  - `public.profiles(id uuid pk → auth.users, nickname text, avatar_path text null, created_at timestamptz)`: 모두 읽기, 본인만 수정(nickname, avatar_path)
  - `public.user_settings(user_id uuid pk → auth.users, privacy_agreed_at timestamptz, age14_agreed_at timestamptz, kakao_notify boolean, first_home_visit_at timestamptz null)`: 본인만 읽기·수정(kakao_notify만)
  - `public.complete_profile(p_nickname text, p_avatar_path text, p_kakao_notify boolean) returns void`: 두 행을 한 번에 만든다. 이미 있으면 `raise exception 'profile_exists'`
  - `public.mark_home_visit() returns void`: `first_home_visit_at`이 비어 있을 때만 `now()`로 채움
  - Storage 버킷 `avatars`(공개, 5MB, jpeg/png/webp). 경로 `{auth.uid()}/{파일명}`만 본인이 추가·삭제 가능

- [ ] **Step 1: 프로젝트 초기화**

Run: `git rm backend/.gitkeep && supabase init && supabase start`
Expected: `supabase start`가 `API URL: http://127.0.0.1:54321`과 `anon key`를 출력한다.

`supabase/config.toml`에서 설정한다: `[auth] site_url = "http://localhost:5173"`, `additional_redirect_urls = ["http://localhost:5173/auth/callback"]`, `[auth.external.kakao] enabled = true`, `client_id = "env(KAKAO_REST_API_KEY)"`, `secret = "env(KAKAO_CLIENT_SECRET)"`, `[auth.external.google]`도 같은 방식(`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`). 키 값은 `supabase/.env`(gitignore)에 둔다.

- [ ] **Step 2: 실패하는 테스트 작성** `supabase/tests/database/base.test.sql`

```sql
-- plan(10)
select is((select count(*)::int from public.app_config), 1, 'app_config has one row');
select is((select deadline_at from public.app_config), '2026-12-24 23:59:00+09'::timestamptz, 'deadline is 12/24 23:59 KST');
select is((select open_at from public.app_config), '2026-12-25 12:25:00+09'::timestamptz, 'open is 12/25 12:25 KST');
select is((select tree_deadline_at from public.app_config), '2026-12-25 23:59:00+09'::timestamptz, 'tree deadline is 12/25 23:59 KST');
-- as user a
select lives_ok($$ select public.complete_profile('눈사람조아', null, true) $$, 'complete_profile creates rows');
select throws_ok($$ select public.complete_profile('again', null, true) $$, 'P0001', 'profile_exists', 'second call rejected');
select throws_ok($$ update public.profiles set nickname = '1234567890123' where id = auth.uid() $$, '23514', null, '13-char nickname rejected');
select throws_ok($$ update public.profiles set nickname = '   ' where id = auth.uid() $$, '23514', null, 'whitespace-only nickname rejected');
-- as user b
select is((select count(*)::int from public.user_settings), 0, 'b cannot read a settings');
select is((select count(*)::int from public.profiles where nickname = '눈사람조아'), 1, 'b can read a profile');
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `supabase test db`
Expected: FAIL (`relation "public.app_config" does not exist`)

- [ ] **Step 4: 마이그레이션 작성** `supabase/migrations/20261125000100_base.sql`

- `app_config`는 기술 문서 4.1의 정의 그대로 만들고, 위 테스트의 세 시각을 `insert`한다. select 정책 `using (true)`.
- `profiles.nickname`에 `check (char_length(nickname) between 1 and 12 and btrim(nickname) <> '')`.
- `user_settings`는 select·update 정책 `user_id = auth.uid()`. update 열 권한은 `kakao_notify`만.
- `complete_profile`은 `security definer`. `auth.uid()`가 null이면 `raise exception 'not_authenticated'`. 동의 시각 두 개는 `now()`로 채운다(동의 체크는 프론트가 막고, 서버는 시각만 기록).
- `avatars` 버킷은 `insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)`로 만들고, `storage.objects` 정책은 `bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text`.

- [ ] **Step 5: 테스트 통과 확인**

Run: `supabase db reset && supabase test db`
Expected: `base.test.sql .. ok`, `All tests successful.`

- [ ] **Step 6: CI 작성** `.github/workflows/ci.yml`

`pull_request`에서 실행. `dorny/paths-filter`로 `supabase/**` 변경 시 `db` 작업을 돌린다: `supabase/setup-cli@v1` → `supabase start` → `supabase test db`. 프론트 작업은 F1이 같은 파일에 추가한다.

- [ ] **Step 7: 커밋**

```bash
git add supabase .github/workflows/ci.yml
git commit -m "feat(db): add base schema with app config, profiles and settings"
```

### Task B2: 개봉 전 잠금 RLS (위험 확인)

그룹·선물 테이블과 **읽기 규칙만** 만든다. 쓰기 RPC(`place_gift` 등)는 2주차 계획에서 만든다. 1주차에 "받는 사람도 12/25 12:25 전에는 속을 못 본다"를 테스트로 증명하는 것이 목적이다.

**Files:**
- Create: `supabase/migrations/20261125000200_gift_lock.sql`, `supabase/tests/database/gift_lock.test.sql`

**Interfaces:**
- Consumes: B1의 `app_config`, `profiles`
- Produces:
  - `public.groups(id uuid pk, name text, invite_code text unique, all_manito boolean, created_by uuid, created_at)`
  - `public.group_members(group_id uuid, user_id uuid, joined_at, pk(group_id, user_id))`
  - `public.gift_boxes(id uuid pk, group_id uuid, recipient_id uuid null, kind text, box_color text, ribbon_color text, stickers jsonb, opened_at timestamptz null, created_at)`. 보낸 사람 열 없음
  - `public.gift_box_contents(box_id uuid pk → gift_boxes on delete cascade, sender_id uuid, letter text null, photo_paths text[], youtube_id text null, updated_at)`
  - `public.is_group_member(p_group_id uuid) returns boolean`(security definer, 정책 재귀 방지용)
  - 클라이언트 쓰기 정책 없음. 네 테이블 모두 클라이언트가 직접 쓸 수 없다

- [ ] **Step 1: 실패하는 테스트 작성** `supabase/tests/database/gift_lock.test.sql`

준비 데이터(`reset role` 상태): 사용자 a(보낸 사람), b(받는 사람), c(같은 그룹 멤버), d(그룹 밖). 그룹 1개에 a·b·c가 멤버. a→b 지정 선물 상자 1개(겉 + 속, 편지 `'메리 크리스마스'`). `app_config.open_at`은 기본값(미래).

```sql
-- plan(9)
-- as d
select is((select count(*)::int from public.gift_boxes), 0, 'non-member sees no boxes');
select is((select count(*)::int from public.groups), 0, 'non-member sees no groups');
-- as c
select is((select count(*)::int from public.gift_boxes), 1, 'member sees exterior');
select is((select count(*)::int from public.gift_box_contents), 0, 'other member never sees contents');
-- as b, before open
select is((select count(*)::int from public.gift_box_contents), 0, 'recipient cannot see contents before open');
-- as a
select is((select count(*)::int from public.gift_box_contents), 1, 'sender always sees contents');
select throws_ok(format($$ insert into public.gift_boxes (group_id, recipient_id, kind, box_color, ribbon_color) values (%L, %L, 'designated', 'red', 'gold') $$, :'group_id', :'user_b'), '42501', null, 'client cannot insert boxes directly');
-- reset role; update app_config set open_at = now() - interval '1 minute'; then as b
select is((select letter from public.gift_box_contents), '메리 크리스마스', 'recipient sees contents after open');
-- as c, after open
select is((select count(*)::int from public.gift_box_contents), 0, 'other member still cannot see contents after open');
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `supabase test db`
Expected: FAIL (`relation "public.groups" does not exist`)

- [ ] **Step 3: 마이그레이션 작성** `supabase/migrations/20261125000200_gift_lock.sql`

- 제약: `groups.name` 1~20자·공백만 불가. `invite_code` 기본값 `substr(md5(gen_random_uuid()::text), 1, 8)`. `gift_boxes.kind in ('designated','manito')`, `check (kind = 'manito' or recipient_id is not null)`, 스티커 `jsonb_array_length(stickers) <= 20`. `gift_box_contents`: 편지 `null` 또는 1~1000자, `cardinality(photo_paths) <= 5`, `youtube_id ~ '^[A-Za-z0-9_-]{11}$'`, 셋 중 하나 이상 존재.
- 읽기 정책: groups·group_members·gift_boxes는 `public.is_group_member(group_id)`(groups는 `id`). contents는 `sender_id = auth.uid() or exists (select 1 from public.gift_boxes b where b.id = box_id and b.recipient_id = auth.uid() and now() >= (select open_at from public.app_config))`.
- insert·update·delete 정책은 만들지 않는다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `supabase db reset && supabase test db`
Expected: `gift_lock.test.sql .. ok`

- [ ] **Step 5: 커밋**

```bash
git add supabase/migrations/20261125000200_gift_lock.sql supabase/tests/database/gift_lock.test.sql
git commit -m "feat(db): add group and gift tables with open-time lock RLS"
```

### Task B3: 공개 트리 스키마 (카드, 좋아요, 신고, 금칙어)

**Files:**
- Create: `supabase/migrations/20261125000300_public_tree.sql`, `supabase/tests/database/public_tree.test.sql`

**Interfaces:**
- Consumes: B1의 `app_config`, `profiles`, `is_admin()`
- Produces (F4~F6이 쓴다):
  - `public.tree_cards(id uuid, user_id uuid unique → profiles, template text, drawing_path text null, stickers jsonb, letter text, like_count int, hidden boolean, created_at, updated_at)`. 클라이언트가 쓸 수 있는 열은 `template, drawing_path, stickers, letter`뿐. `user_id` 기본값 `auth.uid()`
  - `public.card_likes(card_id uuid → tree_cards on delete cascade, user_id uuid default auth.uid(), created_at, pk(card_id, user_id))`
  - `public.reports(id uuid, reporter_id uuid default auth.uid(), target_type text in ('card','profile'), target_id uuid, created_at, unique(reporter_id, target_type, target_id))`
  - `public.banned_words(word text pk)`: 클라이언트 접근 없음
  - `public.random_tree_cards(p_limit int default 50) returns setof public.tree_cards` (security invoker, 숨김 제외)
  - 금칙어 위반 시 에러 메시지 `'banned_word'`(errcode `P0001`)

- [ ] **Step 1: 실패하는 테스트 작성** `supabase/tests/database/public_tree.test.sql`

준비: 사용자 a·b·c와 각자 `profiles`. `insert into public.banned_words values ('나쁜말')`.

```sql
-- plan(18)
-- as a
select lives_ok($$ insert into public.tree_cards (template, letter) values ('snowman', '메리 크리스마스') $$, 'a hangs a card');
select throws_ok($$ insert into public.tree_cards (template, letter) values ('tree', '두 번째') $$, '23505', null, 'one card per user');
select throws_ok($$ update public.tree_cards set like_count = 999 where user_id = auth.uid() $$, '42501', null, 'client cannot set like_count');
select throws_ok($$ update public.tree_cards set letter = '   ' where user_id = auth.uid() $$, '23514', null, 'whitespace-only letter rejected');
select throws_ok($$ update public.tree_cards set letter = '나 쁜 말 이야' where user_id = auth.uid() $$, 'P0001', 'banned_word', 'banned word ignoring spaces');
-- as b
select lives_ok($$ insert into public.tree_cards (template, letter) values ('tree', repeat('🎄', 300)) $$, '300 emoji letter accepted');
select lives_ok($$ insert into public.card_likes (card_id) select id from public.tree_cards where letter = '메리 크리스마스' $$, 'b likes a card');
select throws_ok($$ insert into public.card_likes (card_id) select id from public.tree_cards where letter = '메리 크리스마스' $$, '23505', null, 'double like rejected');
select is((select like_count from public.tree_cards where letter = '메리 크리스마스'), 1, 'like_count incremented');
select lives_ok($$ insert into public.reports (target_type, target_id) select 'card', id from public.tree_cards where letter = '메리 크리스마스' $$, 'b reports card');
select throws_ok($$ insert into public.reports (target_type, target_id) select 'card', id from public.tree_cards where letter = '메리 크리스마스' $$, '23505', null, 'duplicate report rejected');
select is((select count(*)::int from public.reports), 0, 'non-admin cannot read reports');
-- as c
select is((select count(*)::int from public.card_likes), 0, 'c cannot see who liked');
-- as a (card owner)
select is((select count(*)::int from public.card_likes), 1, 'owner sees likers');
-- reset role; update tree_cards set hidden = true where letter = '메리 크리스마스'; then as anon
select is((select count(*)::int from public.tree_cards where letter = '메리 크리스마스'), 0, 'hidden card invisible to anon');
-- as c (card_id captured earlier with \gset, see test rules)
select throws_ok(format($$ insert into public.card_likes (card_id) values (%L) $$, :'card_id'), '42501', null, 'cannot like hidden card by id');
-- as a
select is((select count(*)::int from public.tree_cards where letter = '메리 크리스마스'), 1, 'owner still sees own hidden card');
-- reset role; update app_config set tree_deadline_at = now() - interval '1 minute'; then as b
select results_eq($$ with d as (delete from public.tree_cards where user_id = auth.uid() returning 1) select count(*)::int from d $$, $$ values (1) $$, 'delete allowed after tree deadline');
```

c는 숨긴 카드의 id를 알고 있다고 가정한다. RLS `with check`의 `exists`가 숨긴 카드를 볼 수 없으므로 거부된다.

- [ ] **Step 2: 테스트 실패 확인**

Run: `supabase test db`
Expected: FAIL (`relation "public.tree_cards" does not exist`)

- [ ] **Step 3: 마이그레이션 작성** `supabase/migrations/20261125000300_public_tree.sql`

- 열 권한: `revoke insert, update on public.tree_cards from anon, authenticated; grant insert (template, drawing_path, stickers, letter), update (template, drawing_path, stickers, letter) on public.tree_cards to authenticated;`
- `tree_cards` 정책: select `not hidden or user_id = auth.uid() or public.is_admin()`(anon 포함). insert `with check (user_id = auth.uid() and now() < (select tree_deadline_at from public.app_config))`. update는 using `user_id = auth.uid()`, with check에 같은 시각 조건. delete `using (user_id = auth.uid())`.
- `letter` 제약: `char_length between 1 and 300 and btrim(letter) <> ''`. 스티커 `jsonb_typeof(stickers) = 'array' and jsonb_array_length(stickers) <= 20`.
- 금칙어 트리거 `check_banned_words()`(before insert or update of letter): 편지와 금칙어 모두 `lower(regexp_replace(x, '\s', '', 'g'))`로 바꾼 뒤 포함 여부를 본다. 걸리면 `raise exception 'banned_word'`. `banned_words`를 읽어야 하므로 security definer.
- 좋아요 수 트리거(after insert or delete on card_likes, security definer)가 `like_count`를 ±1.
- `card_likes` 정책: select `user_id = auth.uid() or exists (select 1 from public.tree_cards t where t.id = card_id and t.user_id = auth.uid())`. insert with check `user_id = auth.uid() and exists (select 1 from public.tree_cards t where t.id = card_id)`. delete `user_id = auth.uid()`.
- `reports` 정책: insert with check `reporter_id = auth.uid()`, select `public.is_admin()`.
- `random_tree_cards`: `select * from public.tree_cards where not hidden order by random() limit p_limit`. `grant execute ... to anon, authenticated`.
- 인덱스: `tree_cards(like_count desc)`, `tree_cards(created_at desc)`.

- [ ] **Step 4: 테스트 통과 확인**

Run: `supabase db reset && supabase test db`
Expected: 세 파일 모두 `ok`

- [ ] **Step 5: 커밋**

```bash
git add supabase/migrations/20261125000300_public_tree.sql supabase/tests/database/public_tree.test.sql
git commit -m "feat(db): add public tree cards, likes, reports and banned words"
```

### Task B4: 카카오 토큰 저장과 테스트 발송 (Edge Functions)

**Files:**
- Create: `supabase/migrations/20261125000400_kakao_tokens.sql`, `supabase/functions/_shared/crypto.ts`, `supabase/functions/_shared/crypto_test.ts`, `supabase/functions/_shared/kakao.ts`, `supabase/functions/_shared/kakao_test.ts`, `supabase/functions/save-kakao-token/index.ts`, `supabase/functions/send-kakao-test/index.ts`
- Modify: `.github/workflows/ci.yml` (`deno test supabase/functions/_shared/` 추가)

**Interfaces:**
- Consumes: B1의 `is_admin` 규칙(함수 안에서는 `user.app_metadata.role === 'admin'`으로 확인)
- Produces:
  - `public.kakao_tokens(user_id uuid pk → auth.users on delete cascade, kakao_user_id text, enc_refresh_token text, iv text, updated_at timestamptz)`. RLS 켬, 정책 없음, `revoke all ... from anon, authenticated`
  - `_shared/crypto.ts`: `encryptToken(plain: string, keyB64: string): Promise<{ ciphertext: string; iv: string }>`, `decryptToken(ciphertext: string, iv: string, keyB64: string): Promise<string>` (AES-GCM 256, Web Crypto, base64)
  - `_shared/kakao.ts`: `refreshKakaoToken(refreshToken: string): Promise<{ accessToken: string; refreshToken: string | null }>`, `fetchKakaoUserId(accessToken: string): Promise<string>`, `hasTalkMessageScope(accessToken: string): Promise<boolean>`, `buildMemoTemplate(text: string, url: string): string`, `sendKakaoMemo(accessToken: string, templateJson: string): Promise<void>`
  - **`POST /functions/v1/save-kakao-token`** (F2가 호출): 헤더 `Authorization: Bearer <사용자 JWT>`, 본문 `{ "refresh_token": string }`. 응답 `200 { "ok": true, "talk_message": boolean }`, `400 { "error": "missing_token" }`, `401 { "error": "unauthorized" }`, `403 { "error": "kakao_user_mismatch" }`, `502 { "error": "kakao_refresh_failed" }`
  - **`POST /functions/v1/send-kakao-test`**: 관리자만. 호출한 본인에게 지금 메시지 1통. 응답 `200 { "ok": true }`, `403 { "error": "forbidden" }`, `404 { "error": "no_token" }`, `502 { "error": "kakao_send_failed" }`
  - 함수 secrets: `KAKAO_REST_API_KEY`, `KAKAO_CLIENT_SECRET`, `TOKEN_ENC_KEY`(base64 32바이트), `SITE_URL`

- [ ] **Step 1: 실패하는 테스트 작성**

`supabase/functions/_shared/crypto_test.ts`:
```ts
Deno.test("round trip", async () => {
  const key = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))));
  const { ciphertext, iv } = await encryptToken("refresh-abc", key);
  assertEquals(await decryptToken(ciphertext, iv, key), "refresh-abc");
});
Deno.test("fresh iv each call", async () => { /* 같은 평문 두 번 암호화 → iv와 ciphertext가 서로 다름 */ });
Deno.test("wrong key fails", async () => { /* 다른 키로 decryptToken → assertRejects */ });
```

`supabase/functions/_shared/kakao_test.ts`:
```ts
Deno.test("memo template", () => {
  const t = JSON.parse(buildMemoTemplate("선물이 열렸어요", "https://example.com"));
  assertEquals(t.object_type, "text");
  assertEquals(t.text, "선물이 열렸어요");
  assertEquals(t.link.web_url, "https://example.com");
  assertEquals(t.link.mobile_web_url, "https://example.com");
});
Deno.test("memo text cut to 200 chars", () => {
  assertEquals([...JSON.parse(buildMemoTemplate("가".repeat(250), "https://x")).text].length, 200);
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `deno test supabase/functions/_shared/`
Expected: FAIL (모듈 없음)

- [ ] **Step 3: `_shared/crypto.ts`, `_shared/kakao.ts` 구현**

카카오 호출 주소: 토큰 갱신 `POST https://kauth.kakao.com/oauth/token`(form: `grant_type=refresh_token, client_id, client_secret, refresh_token`. 응답의 `refresh_token`은 만료 1개월 미만일 때만 온다), 사용자 `GET https://kapi.kakao.com/v2/user/me`(`id`), 동의 범위 `GET https://kapi.kakao.com/v2/user/scopes?scopes=["talk_message"]`(`scopes[0].agreed`), 발송 `POST https://kapi.kakao.com/v2/api/talk/memo/default/send`(form `template_object`, 응답 `result_code === 0`). 실패하면 응답 본문을 담아 `Error`를 던진다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `deno test supabase/functions/_shared/`
Expected: `ok | 5 passed`

- [ ] **Step 5: `kakao_tokens` 마이그레이션과 두 함수 구현**

`save-kakao-token`: JWT로 `auth.getUser()` → 사용자의 `identities`에서 `provider === 'kakao'`인 것의 `id`(카카오 회원번호)를 찾는다(없으면 403) → `refreshKakaoToken`으로 토큰이 진짜인지 확인 → `fetchKakaoUserId` 결과가 identity id와 다르면 403 → 새 refresh token이 오면 그것을, 아니면 받은 것을 암호화해 `service_role` 클라이언트로 `kakao_tokens`에 upsert(`onConflict: 'user_id'`) → `hasTalkMessageScope` 결과를 `talk_message`로 돌려준다.
`send-kakao-test`: 관리자 확인 → 토큰 복호화 → 갱신(새 refresh token이면 다시 저장) → `buildMemoTemplate("Christmas Gift For You 테스트 메시지", SITE_URL)` 발송.
두 함수 모두 CORS preflight(`OPTIONS`)에 응답한다.

- [ ] **Step 6: 로컬 실행 확인**

Run: `supabase functions serve --env-file supabase/.env` 후 `curl -s -X POST http://127.0.0.1:54321/functions/v1/save-kakao-token -H "Authorization: Bearer <anon key>" -d '{}'`
Expected: `401 {"error":"unauthorized"}` (anon 키는 사용자가 아니므로). 실제 토큰 저장은 F2 이후 통합 확인에서 본다.

- [ ] **Step 7: 커밋**

```bash
git add supabase/migrations/20261125000400_kakao_tokens.sql supabase/functions .github/workflows/ci.yml
git commit -m "feat(functions): store encrypted Kakao refresh tokens and send test memo"
```

### Task B5: 스테이징 환경과 DB 배포 자동화

**Files:**
- Create: `.github/workflows/deploy-db.yml`, `docs/ops/environments.md`

**Interfaces:**
- Produces: 스테이징 Supabase 프로젝트 URL과 anon key(→ F1의 Vercel 환경 변수), 카카오·구글 콘솔 등록 정보

- [ ] **Step 1: 스테이징 Supabase 프로젝트 만들기 (대시보드)**

리전은 서울(`ap-northeast-2`). Auth > Providers에서 카카오(REST API 키, Client Secret), 구글(Client ID, Secret)을 켠다. Auth > URL Configuration: Site URL은 Vercel 스테이징 주소, Redirect URLs에 `<스테이징 주소>/auth/callback`과 `http://localhost:5173/auth/callback`.

- [ ] **Step 2: 외부 콘솔 등록**

카카오: Redirect URI에 `https://<스테이징 ref>.supabase.co/auth/v1/callback`, Web 사이트 도메인에 Vercel 스테이징 주소. 구글 Cloud: OAuth 클라이언트(웹)의 승인된 리디렉션 URI에 같은 Supabase 콜백 주소. 구글 OAuth 동의 화면 "게시" 신청 소요 기간을 확인해 `docs/ops/environments.md`에 적는다.

- [ ] **Step 3: 함수 secrets 등록**

Run: `supabase secrets set --project-ref <ref> KAKAO_REST_API_KEY=... KAKAO_CLIENT_SECRET=... TOKEN_ENC_KEY=$(openssl rand -base64 32) SITE_URL=<스테이징 주소>`
Expected: `Finished supabase secrets set.`

- [ ] **Step 4: 배포 워크플로 작성** `.github/workflows/deploy-db.yml`

`push`가 `develop`이면 스테이징, `main`이면 운영 ref를 쓴다. 단계: `supabase link --project-ref $REF` → `supabase db push` → `supabase functions deploy`. Secrets: `SUPABASE_ACCESS_TOKEN`, `STAGING_PROJECT_REF`, `STAGING_DB_PASSWORD`, `PROD_PROJECT_REF`, `PROD_DB_PASSWORD`. 운영 프로젝트는 아직 없으므로 `main` 분기는 ref가 비어 있으면 건너뛴다.

- [ ] **Step 5: 첫 배포 확인**

`develop`에 머지한 뒤 Actions 로그 확인.
Expected: `Finished supabase db push.`, 함수 2개 배포. 대시보드 Table Editor에 `app_config`, `profiles`, `tree_cards` 등이 보인다.

- [ ] **Step 6: 커밋**

```bash
git add .github/workflows/deploy-db.yml docs/ops/environments.md
git commit -m "ci: deploy database and functions to staging on develop"
```

---

## 프론트엔드

### Task F1: 프로젝트 뼈대와 공용 유틸

**Files:**
- Delete: `frontend/.gitkeep`
- Create: `frontend/` (Vite react-ts 템플릿), `frontend/src/lib/supabase.ts`, `frontend/src/lib/database.types.ts`(생성), `frontend/src/lib/time.ts`, `frontend/src/lib/time.test.ts`, `frontend/src/lib/text.ts`, `frontend/src/lib/text.test.ts`, `frontend/src/app/App.tsx`, `frontend/src/app/Layout.tsx`, `frontend/vercel.json`, `frontend/.env.example`
- Modify: `.github/workflows/ci.yml` (프론트 작업 추가)

**Interfaces:**
- Consumes: B1의 `app_config` (가짜 데이터로 먼저 시작 가능)
- Produces:
  - `supabase: SupabaseClient<Database>` (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`)
  - `type AppConfig = { deadlineAt: Date; openAt: Date; treeDeadlineAt: Date }`, `fetchAppConfig(): Promise<AppConfig>`
  - `dDayKst(now: Date): number`: KST 달력 기준 12/25까지 남은 날 수
  - `countChars(s: string): number`: 코드 포인트 수
  - 라우트: `/`, `/login`, `/auth/callback`, `/profile/setup`, `/cards/new`, `/cards/:id`, `/cards/:id/edit`
  - `Layout`: 상단 바(로고, 오른쪽 🔔 자리만. 캐롤은 3주차) + `<Outlet />`

- [ ] **Step 1: 생성과 의존성**

Run: `git rm frontend/.gitkeep && npm create vite@latest frontend -- --template react-ts && cd frontend && npm i @supabase/supabase-js react-router && npm i -D tailwindcss @tailwindcss/vite vitest`
`package.json` scripts에 `"typecheck": "tsc -b"`, `"test": "vitest run"`.

- [ ] **Step 2: 실패하는 테스트 작성**

`src/lib/time.test.ts`:
```ts
test.each([
  ["2026-12-20T15:00:00Z", 4],  // 12/21 00:00 KST
  ["2026-12-24T14:59:59Z", 1],  // 12/24 23:59:59 KST
  ["2026-12-24T15:00:00Z", 0],  // 12/25 00:00 KST
  ["2026-12-25T15:00:00Z", -1], // 12/26 00:00 KST
])("dDayKst(%s) = %i", (iso, d) => expect(dDayKst(new Date(iso))).toBe(d));
```
`src/lib/text.test.ts`:
```ts
test("emoji counts as one", () => expect(countChars("🎄🎄")).toBe(2));
test("korean", () => expect(countChars("메리 크리스마스")).toBe(8));
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `npm test`
Expected: FAIL (`Cannot find module './time'`)

- [ ] **Step 4: 구현**

`dDayKst`: `now`와 `2026-12-25T00:00:00+09:00`을 각각 KST 날짜(연·월·일)로 바꿔 일 수 차이를 낸다. `countChars`: `[...s].length`. `fetchAppConfig`: `app_config` 한 행을 읽어 `Date`로 변환. 라우트는 페이지 컴포넌트 자리만 만든다. `vercel.json`: `{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }`. `.env.example`에는 두 `VITE_` 변수 이름만.

- [ ] **Step 5: 통과 확인과 타입 생성**

Run: `npm test && npx supabase gen types typescript --local > src/lib/database.types.ts && npm run typecheck && npm run build`
Expected: 테스트 6개 통과, 빌드 성공. B1이 아직 머지되지 않았으면 타입 생성은 건너뛰고, 백엔드 마이그레이션이 머지될 때마다 다시 생성해 커밋한다.

- [ ] **Step 6: CI와 Vercel**

`ci.yml`에 `frontend/**` 변경 시 `fe` 작업 추가: Node 22, `npm ci`, `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`(작업 디렉터리 `frontend`). Vercel 프로젝트를 만들고 Root Directory를 `frontend`, Production Branch를 `main`으로, `develop`을 스테이징 주소로 쓴다. 환경 변수에 B5의 스테이징 URL·anon key를 넣는다.

- [ ] **Step 7: 커밋**

```bash
git add frontend .github/workflows/ci.yml
git commit -m "feat(fe): scaffold React app with routes and time/text utils"
```

### Task F2: 로그인과 인증 상태

**Files:**
- Create: `frontend/src/lib/inApp.ts`, `frontend/src/lib/inApp.test.ts`, `frontend/src/lib/returnTo.ts`, `frontend/src/lib/returnTo.test.ts`, `frontend/src/auth/AuthProvider.tsx`, `frontend/src/auth/guards.tsx`, `frontend/src/pages/LoginPage.tsx`, `frontend/src/pages/AuthCallbackPage.tsx`

**Interfaces:**
- Consumes: B1의 `profiles`, B4의 `save-kakao-token` 응답 형식
- Produces:
  - `detectInAppBrowser(ua: string): 'kakaotalk' | 'other' | null`, `kakaoExternalUrl(url: string): string`
  - `safeReturnTo(raw: string | null): string`: `/`로 시작하고 `//`나 `/\`로 시작하지 않는 경로만 통과, 아니면 `'/'`
  - `useAuth(): { session: Session | null; profile: Profile | null; loading: boolean; kakaoMessageConsent: boolean | null; refreshProfile(): Promise<void> }` (`Profile = { id: string; nickname: string; avatarPath: string | null }`)
  - `signInWithKakao(returnTo: string): Promise<void>`, `signInWithGoogle(returnTo: string): Promise<void>`
  - `<RequireAuth>`: 비로그인이면 `/login?returnTo=<현재 경로>`로. `<RequireProfile>`: 프로필이 없으면 `/profile/setup`으로

- [ ] **Step 1: 실패하는 테스트 작성**

`inApp.test.ts`:
```ts
test("kakaotalk", () => expect(detectInAppBrowser("Mozilla/5.0 ... KAKAOTALK 10.4.5")).toBe("kakaotalk"));
test("instagram", () => expect(detectInAppBrowser("Mozilla/5.0 ... Instagram 300.0")).toBe("other"));
test("safari", () => expect(detectInAppBrowser("Mozilla/5.0 (iPhone ...) Version/17.0 Mobile/15E148 Safari/604.1")).toBeNull());
test("external url", () => expect(kakaoExternalUrl("https://a.vercel.app/g/ab12?x=1"))
  .toBe("kakaotalk://web/openExternal?url=https%3A%2F%2Fa.vercel.app%2Fg%2Fab12%3Fx%3D1"));
```
`returnTo.test.ts`:
```ts
test.each([
  ["/cards/new", "/cards/new"],
  ["//evil.com", "/"],
  ["/\\evil.com", "/"],
  ["https://evil.com", "/"],
  [null, "/"],
])("safeReturnTo(%s)", (raw, out) => expect(safeReturnTo(raw)).toBe(out));
```
다른 인앱 판별 문자열: `FBAN`, `FBAV`, `Line/`, `NAVER(inapp`, `Instagram`.

- [ ] **Step 2: 테스트 실패 확인**

Run: `npm test`
Expected: FAIL (모듈 없음)

- [ ] **Step 3: 유틸 구현 후 통과 확인**

Run: `npm test`
Expected: PASS

- [ ] **Step 4: 인증 흐름 구현**

- `signInWithKakao`: `sessionStorage.returnTo = safeReturnTo(returnTo)` 저장 후 `supabase.auth.signInWithOAuth({ provider: 'kakao', options: { redirectTo: origin + '/auth/callback', scopes: 'talk_message' } })`. 구글은 scopes 없이 같은 방식.
- `AuthProvider`: `onAuthStateChange`에서 `SIGNED_IN`이고 `session.provider_refresh_token`이 있고 `session.user.app_metadata.provider === 'kakao'`이면 `supabase.functions.invoke('save-kakao-token', { body: { refresh_token } })`를 부르고 응답의 `talk_message`를 `kakaoMessageConsent`에 둔다. 실패해도 로그인은 막지 않는다(콘솔 경고만). 세션이 생기면 `profiles`에서 본인 행을 읽는다.
- `AuthCallbackPage`: 세션이 잡히면 프로필이 없을 때 `/profile/setup`, 있으면 `sessionStorage.returnTo`(없으면 `/`)로 이동.
- `LoginPage`(①): "카카오로 시작하기", "구글로 시작하기". 인앱이 `kakaotalk`이면 상단 안내 "카톡 안에서 열었어요 → [외부 브라우저로 열기]"를 보여주고, 누르면 `location.href = kakaoExternalUrl(location.href)`. 구글 버튼은 인앱(`kakaotalk`, `other`)에서 누르면 OAuth 대신 외부 브라우저 안내를 띄운다(`kakaotalk`이면 바로 외부로 열기).

- [ ] **Step 5: 로컬 확인**

Run: `npm run dev` 후 `http://localhost:5173/login`에서 카카오 로그인.
Expected: 카카오 동의 화면에 "카카오톡 메시지 전송(선택)"이 보인다. 로그인 후 `/profile/setup`으로 이동한다. `supabase functions serve` 로그에 `save-kakao-token` 200이 찍히고, 로컬 DB `kakao_tokens`에 1행이 생긴다.

- [ ] **Step 6: 커밋**

```bash
git add frontend/src
git commit -m "feat(fe): add Kakao/Google login with in-app browser escape"
```

### Task F3: 프로필 설정 (①-a)

**Files:**
- Create: `frontend/src/lib/image.ts`, `frontend/src/pages/ProfileSetupPage.tsx`, `frontend/src/features/profile/validate.ts`, `frontend/src/features/profile/validate.test.ts`

**Interfaces:**
- Consumes: B1의 `complete_profile`, `avatars` 버킷, F1의 `countChars`, F2의 `useAuth`, `signInWithKakao`
- Produces:
  - `resizeImage(file: File, maxEdge: number): Promise<Blob>`: 캔버스로 긴 변을 `maxEdge`로 줄여 JPEG(품질 0.85). 2주차 선물 사진도 쓴다
  - `validateNickname(raw: string): 'empty' | 'too_long' | null`: 앞뒤 공백 제거 후 판단

- [ ] **Step 1: 실패하는 테스트 작성** `validate.test.ts`

```ts
test.each([
  ["", "empty"],
  ["   ", "empty"],
  ["눈사람조아", null],
  ["가".repeat(12), null],
  ["가".repeat(13), "too_long"],
  ["🎄".repeat(12), null],
])("validateNickname(%s)", (s, r) => expect(validateNickname(s)).toBe(r));
```

- [ ] **Step 2: 실패 확인 → 구현 → 통과 확인**

Run: `npm test` (FAIL: 모듈 없음) → `validateNickname` 구현 → `npm test` (PASS)

- [ ] **Step 3: 화면 구현** `ProfileSetupPage`

- 프로필 사진: "사진 올리기"(파일 선택 → `resizeImage(file, 512)` → `avatars/{uid}/{uuid}.jpg` 업로드) 또는 "건너뛰기(기본 이미지)". 안내 "모든 사람에게 보여요".
- 닉네임 입력(카운터 `n/12`), 필수 동의 체크 2개("[필수] 개인정보 수집·이용 동의", "[필수] 만 14세 이상이에요"), "12/25 12:25 카톡 개봉 알림 받기" 토글.
- 토글 기본값: 카카오 사용자 켜짐. 구글 사용자는 꺼짐·비활성, 안내 "카카오 로그인 사용자만 받을 수 있어요".
- "시작하기"는 닉네임이 유효하고 두 동의가 체크됐을 때만 활성. `rpc('complete_profile', { p_nickname: 닉네임.trim(), p_avatar_path, p_kakao_notify })` → `refreshProfile()` → `sessionStorage.returnTo`(없으면 `/`)로 이동. `profile_exists` 에러면 그냥 이동.
- 토글을 켰는데 `kakaoMessageConsent === false`이면 저장 후 `signInWithKakao(returnTo)`를 다시 불러 동의 화면을 띄운다.
- 하단 "모든 데이터는 2027-01-31에 삭제돼요".

- [ ] **Step 4: 로컬 확인**

Expected: 새 계정으로 설정을 마치면 `profiles`·`user_settings`에 각 1행, 사진을 올렸다면 `avatars` 버킷에 파일 1개. 같은 계정으로 다시 로그인하면 설정 화면을 건너뛴다.

- [ ] **Step 5: 커밋**

```bash
git add frontend/src
git commit -m "feat(fe): add profile setup with consents and notification toggle"
```

### Task F4: 홈 = 공개 트리 (⓪)

**Files:**
- Create: `frontend/src/features/tree/api.ts`, `frontend/src/features/tree/sparkle.ts`, `frontend/src/features/tree/sparkle.test.ts`, `frontend/src/pages/HomePage.tsx`, `frontend/src/features/tree/TreeView.tsx`

**Interfaces:**
- Consumes: B3의 `random_tree_cards`, `tree_cards`, B1의 `mark_home_visit`, F1의 `dDayKst`
- Produces (`api.ts`, F5·F6이 이어서 함수를 추가한다):
  - `type TreeCard = { id: string; userId: string; template: string; letter: string; likeCount: number; hidden: boolean; createdAt: string; author: { nickname: string; avatarPath: string | null } }`
  - `fetchRandomCards(limit: number): Promise<TreeCard[]>`: `rpc('random_tree_cards', { p_limit }).select('*, profiles(nickname, avatar_path)')`
  - `countVisibleCards(): Promise<number>`: `hidden = false` 필터 + `count: 'exact', head: true`
  - `fetchMyCard(userId: string): Promise<TreeCard | null>`
  - `sparkleLevel(likes: number): 0 | 1 | 2 | 3`

- [ ] **Step 1: 실패하는 테스트 작성** `sparkle.test.ts`

```ts
test.each([[0, 0], [4, 0], [5, 1], [19, 1], [20, 2], [49, 2], [50, 3], [999, 3]])
  ("sparkleLevel(%i) = %i", (n, l) => expect(sparkleLevel(n)).toBe(l));
```

- [ ] **Step 2: 실패 확인 → 구현 → 통과 확인**

Run: `npm test` (FAIL) → 구현 → `npm test` (PASS)

- [ ] **Step 3: 화면 구현** `HomePage`

- 비로그인도 볼 수 있다(가드 없음). 로그인 상태면 처음 렌더 때 `rpc('mark_home_visit')`를 한 번 부른다.
- 상단: "지금까지 걸린 마음 {N}개 · D-{n}". `n > 0`이면 `D-n`, `0`이면 `D-DAY`, 음수면 D 표시를 숨긴다.
- `TreeView`: 카드 최대 50장을 트리 위 자리에 배치(배치 방식은 구현자 재량), 카드마다 작성자 아이콘, `sparkleLevel`에 따라 밝기 3단계. 카드를 누르면 `/cards/:id`.
- 버튼 "카드 걸기": 비로그인 → `/login?returnTo=/cards/new`, 내 카드 있음 → `/cards/{내 카드 id}`, 없음 → `/cards/new`. "전체 보기"(카드 목록)와 "내 그룹"은 각각 3주차·2주차 계획에서 붙인다.

- [ ] **Step 4: 로컬 확인**

`supabase/seed.sql`이 없으므로 대시보드나 SQL로 카드 몇 장을 넣고 본다.
Expected: 카드 수와 D-n이 맞게 나오고, 좋아요 5개 이상인 카드가 밝게 보인다. 비로그인 시크릿 창에서도 트리가 보인다.

- [ ] **Step 5: 커밋**

```bash
git add frontend/src
git commit -m "feat(fe): add public tree home with random cards and sparkle"
```

### Task F5: 카드 꾸미기·수정·삭제 (②)

**Files:**
- Create: `frontend/src/lib/errors.ts`, `frontend/src/lib/errors.test.ts`, `frontend/src/features/tree/validate.ts`, `frontend/src/features/tree/validate.test.ts`, `frontend/src/features/tree/templates.ts`, `frontend/src/pages/CardEditorPage.tsx`
- Modify: `frontend/src/features/tree/api.ts`

**Interfaces:**
- Consumes: B3의 `tree_cards` 쓰기 규칙과 `banned_word` 에러, F1 `countChars`, F2 `RequireAuth`·`RequireProfile`, F4 `api.ts`
- Produces:
  - `isUniqueViolation(e: { code?: string } | null): boolean` (`23505`), `isPermissionDenied(e: { code?: string } | null): boolean` (`42501`), `isBannedWord(e: { message?: string } | null): boolean` (`'banned_word'`)
  - `validateLetter(raw: string): 'empty' | 'too_long' | null` (1~300자, 앞뒤 공백 제거 후)
  - `CARD_TEMPLATES: { id: string; label: string; emoji: string }[]`: 디자이너 확정 전 임시값 `snowflake 눈 송이 ❄️`, `sled 산타 썰매 🛷`, `house 따뜻한 집 🏠`, `snowman 눈사람 ⛄`, `tree 크리스마스 트리 🎄`, `cookie 쿠키 🍪`
  - `api.ts`: `createCard(input: { template: string; letter: string }): Promise<TreeCard>`, `updateCard(id: string, input: { template: string; letter: string }): Promise<void>`, `deleteCard(id: string): Promise<void>`, `fetchCard(id: string): Promise<TreeCard | null>`

- [ ] **Step 1: 실패하는 테스트 작성**

`validate.test.ts`:
```ts
test.each([["", "empty"], ["  \n ", "empty"], ["메리", null], ["가".repeat(300), null],
  ["가".repeat(301), "too_long"], ["🎄".repeat(300), null]])
  ("validateLetter", (s, r) => expect(validateLetter(s)).toBe(r));
```
`errors.test.ts`:
```ts
test("unique", () => expect(isUniqueViolation({ code: "23505" })).toBe(true));
test("denied", () => expect(isPermissionDenied({ code: "42501" })).toBe(true));
test("banned", () => expect(isBannedWord({ message: "banned_word" })).toBe(true));
test("null", () => expect(isBannedWord(null)).toBe(false));
```

- [ ] **Step 2: 실패 확인 → 구현 → 통과 확인**

Run: `npm test` (FAIL) → 구현 → `npm test` (PASS)

- [ ] **Step 3: 화면 구현** `CardEditorPage` (`/cards/new`, `/cards/:id/edit`, 둘 다 `RequireAuth` + `RequireProfile`)

- 탭 "앞면"(기본 카드 선택. 직접 그리기·스티커는 P1이라 이번에 없음)과 "뒷면(편지)"(입력 + 카운터 `n/300`).
- "미리보기"는 앞뒤가 뒤집히는 카드. "트리에 걸기"(새 카드) / "수정하기"(수정 모드).
- 제출 중에는 버튼을 비활성화한다(두 번 누르기 방지).
- 에러 처리: `isUniqueViolation` → "이미 카드를 걸었어요" 안내 후 `/cards/{내 카드 id}`로 이동. `isBannedWord` → "쓸 수 없는 단어가 있어요"(어떤 단어인지는 말하지 않는다). `isPermissionDenied` → "카드 걸기가 마감됐어요".
- 수정 모드: 본인 카드가 아니면 `/cards/:id`로 보낸다. 하단 "카드 삭제"(확인 창 "삭제하면 좋아요도 사라져요") → 삭제 후 `/`.
- 성공하면 `/cards/{id}`로 이동한다.

- [ ] **Step 4: 로컬 확인**

Expected: 카드를 걸면 홈 트리에 나타난다. 금칙어를 넣으면 거부된다. 걸기 버튼을 빠르게 두 번 눌러도 카드는 1장이다. 수정·삭제가 동작하고, 삭제 후 다시 걸 수 있다.

- [ ] **Step 5: 커밋**

```bash
git add frontend/src
git commit -m "feat(fe): add card editor with create, edit and delete"
```

### Task F6: 카드 보기·좋아요·신고·작성자 프로필 (③, ③-1)

**Files:**
- Create: `frontend/src/pages/CardViewPage.tsx`, `frontend/src/features/tree/AuthorSheet.tsx`
- Modify: `frontend/src/features/tree/api.ts`

**Interfaces:**
- Consumes: B3의 `card_likes`, `reports`, `random_tree_cards`, F4·F5의 `api.ts`, F5의 `errors.ts`
- Produces (`api.ts`):
  - `fetchMyLike(cardId: string, userId: string): Promise<boolean>`
  - `likeCard(cardId: string): Promise<void>`, `unlikeCard(cardId: string, userId: string): Promise<void>`
  - `fetchLikers(cardId: string): Promise<{ nickname: string; avatarPath: string | null }[]>` (작성자만 결과가 나온다. RLS가 거른다)
  - `report(targetType: 'card' | 'profile', targetId: string): Promise<'ok' | 'already'>`
  - `fetchNextRandomCardId(currentId: string): Promise<string | null>`: `random_tree_cards(2)`에서 현재 카드가 아닌 첫 id

- [ ] **Step 1: 화면 구현** `CardViewPage` (`/cards/:id`, 가드 없음)

- 카드를 탭하면 뒤집혀 편지가 보인다. ‹ › 버튼은 `fetchNextRandomCardId`로 이동한다.
- 작성자 줄: 아이콘·닉네임(누르면 `AuthorSheet`: 큰 사진, 닉네임, "프로필 신고"), ♥ 개수, 신고 버튼.
- 좋아요: 비로그인 → `/login?returnTo=/cards/{id}`. 로그인 → 토글하고 숫자를 ±1로 바로 반영한 뒤, 실패하면 되돌린다.
- 신고(카드·프로필): 비로그인이면 로그인으로 보낸다. `already` → "이미 신고했어요", `ok` → "신고했어요".
- 내 카드면 "수정하기" 버튼(`/cards/{id}/edit`)과 좋아요 누른 사람 목록을 보여준다.
- 카드를 찾지 못하면(없거나 숨김) "카드를 찾을 수 없어요"와 홈 버튼.

- [ ] **Step 2: 로컬 확인**

Expected: 두 계정으로 서로 좋아요·취소·신고가 되고, 같은 대상을 다시 신고하면 "이미 신고했어요"가 나온다. 작성자만 좋아요 목록을 본다. SQL로 `hidden = true`를 하면 다른 계정에서는 "카드를 찾을 수 없어요", 작성자에게는 보인다.

- [ ] **Step 3: 타입·빌드 확인**

Run: `npm run lint && npm run typecheck && npm test && npm run build`
Expected: 모두 통과

- [ ] **Step 4: 커밋**

```bash
git add frontend/src
git commit -m "feat(fe): add card view with likes, reports and author profile"
```

---

## 통합 확인 (11/29, BE·FE 함께)

모든 작업이 `develop`에 머지되고 스테이징에 배포된 뒤 실기기로 확인한다. 결과는 `docs/ops/week1-check.md`에 기록한다.

- [ ] **Step 1: 카카오톡 인앱에서 시작**: 스테이징 주소를 카톡으로 보내고 열기 → "외부 브라우저로 열기" → 외부 브라우저로 넘어간다.
- [ ] **Step 2: 로그인과 토큰**: 카카오 로그인(메시지 동의 포함) → 프로필 설정 → 홈. 스테이징 `kakao_tokens`에 1행.
- [ ] **Step 3: 실제 발송**: 대시보드에서 본인 계정의 `app_metadata`에 `{"role":"admin"}`을 넣고 다시 로그인한 뒤, 브라우저 콘솔에서 `supabase.functions.invoke('send-kakao-test')` → 카톡 "나와의 채팅"에 메시지가 온다. **B0에 이어 우리 코드로 위험 확인 완료.**
- [ ] **Step 4: 공개 트리 흐름**: 카드 걸기 → 다른 계정으로 좋아요 → 신고 → 관리자가 SQL로 숨김 → 다른 계정에서 사라짐(계획의 1주차 시연 시나리오).
- [ ] **Step 5: 구글 로그인**: 외부 브라우저에서 구글 로그인 → 알림 토글이 비활성으로 보인다.
- [ ] **Step 6: 개봉 전 잠금**: `supabase test db`의 `gift_lock` 결과를 시연에서 보여준다(UI는 2주차).
- [ ] **Step 7: 커밋**

```bash
git add docs/ops/week1-check.md
git commit -m "docs: record week 1 integration check"
```
