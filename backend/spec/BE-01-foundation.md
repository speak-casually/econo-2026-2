# BE-01 기반: 설정 시각, 프로필, 개인 설정, 아바타

- 주차: 1주차 (11/25) · 우선순위: P0 · 계획: B1
- 근거: 요구사항 3절·4.2절·13절, 기술 4.1·4.2·5절
- 선행: 없음 · 이 작업을 쓰는 작업: 모든 BE·FE 작업

## 목적

Supabase 프로젝트를 만들고, 모든 기능이 기대는 세 가지를 준비한다. 마감·개봉 시각을 한곳에 두는 설정, 공개 프로필과 본인만 보는 개인 설정, 프로필 사진 저장소다.

## 동작 규칙

- 시각은 `app_config` 한 행에만 둔다: 마감 `2026-12-24 23:59:00+09`, 개봉 `2026-12-25 12:25:00+09`, 걸기 마감 `2026-12-25 23:59:00+09`. 누구나(비로그인 포함) 읽을 수 있다.
- **공개 프로필**(`profiles`): 닉네임과 사진만 둔다. 누구나 읽는다. 본인만 고친다. 닉네임은 1~12자이고 공백만은 안 된다. 중복은 허용한다.
- **개인 설정**(`user_settings`): 필수 동의 두 개의 시각, 카톡 알림 여부, 홈을 처음 연 시각. 본인만 읽는다. 사용자가 고칠 수 있는 열은 `kakao_notify`뿐이다.
- 첫 가입 때 두 테이블의 행이 **함께** 생긴다. 하나만 생기는 경우가 없다.
- 프로필 사진은 공개 버킷 `avatars`에 `{user_id}/{파일명}`으로 저장한다. 본인 폴더에만 올리고 지울 수 있다. 5MB 이하, JPEG·PNG·WebP.

## 인터페이스

```sql
public.app_config(id boolean pk, deadline_at timestamptz, open_at timestamptz, tree_deadline_at timestamptz)
public.is_admin() returns boolean
public.profiles(id uuid pk → auth.users, nickname text, avatar_path text null, created_at timestamptz)
public.user_settings(user_id uuid pk → auth.users, privacy_agreed_at timestamptz, age14_agreed_at timestamptz,
                     kakao_notify boolean, first_home_visit_at timestamptz null)
public.complete_profile(p_nickname text, p_avatar_path text, p_kakao_notify boolean) returns void
  -- 두 행을 한 트랜잭션으로 만든다. 동의 시각은 now(). 이미 있으면 'profile_exists'
public.mark_home_visit() returns void
  -- first_home_visit_at이 비어 있을 때만 now()로 채운다
storage bucket 'avatars' (public)
```

`backend/`에서 `supabase init`으로 `backend/supabase/`를 만든다. 마이그레이션: `backend/supabase/migrations/20261125000100_base.sql`. 로컬 인증 설정(`backend/supabase/config.toml`)에 카카오·구글 provider와 `site_url = http://localhost:5173`, 추가 redirect `http://localhost:5173/auth/callback`.

## 완료 조건

`backend/supabase/tests/database/base.test.sql`:
- [ ] `app_config`는 1행이고 세 시각이 위 값과 같다.
- [ ] `complete_profile` 첫 호출은 성공하고, 두 번째 호출은 `profile_exists`.
- [ ] 닉네임 13자, 공백만 있는 닉네임은 `23514`로 거부된다. 이모지 12개는 통과한다.
- [ ] 다른 사용자는 내 `user_settings`를 0행으로 보고, 내 `profiles`는 볼 수 있다.
- [ ] `user_settings.privacy_agreed_at`을 사용자가 직접 고치려 하면 `42501`.
- [ ] `mark_home_visit`을 두 번 불러도 첫 시각이 유지된다.

CI(`.github/workflows/ci.yml`): `backend/supabase/**` 변경 PR에서 작업 디렉터리 `backend`로 `supabase start` → `supabase test db`가 돈다.

## 범위 밖

- 마이페이지의 프로필 수정 화면(FE-12). 수정 권한 자체는 이 작업에서 만든다.
