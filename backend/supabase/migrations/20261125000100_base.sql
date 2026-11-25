-- BE-01 기반: 설정 시각, 관리자 판별, 공개 프로필, 개인 설정, 아바타 버킷
-- Supabase는 public 테이블에 anon·authenticated 전체 권한을 기본으로 준다.
-- 그래서 테이블마다 먼저 전부 회수하고, 필요한 권한만 다시 준다.

-- 설정 시각 (한 행만) ----------------------------------------------------------
create table public.app_config (
  id               boolean primary key default true check (id),
  deadline_at      timestamptz not null,  -- 그룹 생성·참여, 선물 놓기·수정·삭제 마감
  open_at          timestamptz not null,  -- 선물 개봉
  tree_deadline_at timestamptz not null   -- 공개 트리 카드 걸기 마감
);

insert into public.app_config (deadline_at, open_at, tree_deadline_at) values (
  '2026-12-24 23:59:00+09',
  '2026-12-25 12:25:00+09',
  '2026-12-25 23:59:00+09'
);

alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;
grant select on public.app_config to anon, authenticated;
create policy "app_config: anyone reads" on public.app_config
  for select using (true);

-- 관리자 판별 ------------------------------------------------------------------
-- app_metadata는 사용자가 바꿀 수 없다. user_metadata는 바꿀 수 있으니 쓰지 않는다.
create function public.is_admin() returns boolean
  language sql stable
  set search_path = ''
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin';
$$;

-- 공개 프로필 ------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  nickname    text not null
              check (char_length(nickname) between 1 and 12 and btrim(nickname) <> ''),
  avatar_path text,
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to anon, authenticated;
-- 생성은 complete_profile로만 한다(user_settings와 한 트랜잭션). 직접 insert·delete 권한 없음.
grant update (nickname, avatar_path) on public.profiles to authenticated;

create policy "profiles: anyone reads" on public.profiles
  for select using (true);
create policy "profiles: owner updates" on public.profiles
  for update using (id = auth.uid())
  with check (
    id = auth.uid()
    and (avatar_path is null or avatar_path like auth.uid()::text || '/%')
  );

-- 개인 설정 (본인만) -------------------------------------------------------------
create table public.user_settings (
  user_id             uuid primary key references auth.users (id) on delete cascade,
  privacy_agreed_at   timestamptz not null,
  age14_agreed_at     timestamptz not null,
  kakao_notify        boolean not null default false,
  first_home_visit_at timestamptz
);

alter table public.user_settings enable row level security;
revoke all on public.user_settings from anon, authenticated;
grant select on public.user_settings to authenticated;
-- 사용자가 고칠 수 있는 열은 kakao_notify뿐이다. first_home_visit_at은 mark_home_visit으로만.
grant update (kakao_notify) on public.user_settings to authenticated;

create policy "user_settings: owner reads" on public.user_settings
  for select using (user_id = auth.uid());
create policy "user_settings: owner updates" on public.user_settings
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 프로필 완성: profiles·user_settings 두 행을 함께 만든다 ------------------------------
create function public.complete_profile(p_nickname text, p_avatar_path text, p_kakao_notify boolean)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'profile_exists';
  end if;

  if p_avatar_path is not null and p_avatar_path not like v_uid::text || '/%' then
    raise exception 'invalid_photo_path';
  end if;

  insert into public.profiles (id, nickname, avatar_path)
  values (v_uid, p_nickname, p_avatar_path);

  -- 동의 체크는 프론트가 막는다. 서버는 동의한 시각만 기록한다.
  insert into public.user_settings (user_id, privacy_agreed_at, age14_agreed_at, kakao_notify)
  values (v_uid, now(), now(), coalesce(p_kakao_notify, false));
end;
$$;

-- 홈 첫 방문 시각: 비어 있을 때만 채운다 ------------------------------------------------
create function public.mark_home_visit() returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  update public.user_settings
     set first_home_visit_at = now()
   where user_id = auth.uid()
     and first_home_visit_at is null;
end;
$$;

-- 아바타 버킷 (공개, 5MB, JPEG·PNG·WebP) ------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']);

-- 공개 버킷이라 읽기는 공개 URL로 된다. 올리기·바꾸기·지우기는 본인 폴더({user_id}/)만.
create policy "avatars: owner inserts" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars: owner updates" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars: owner deletes" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
