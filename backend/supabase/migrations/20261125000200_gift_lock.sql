-- BE-02 개봉 전 잠금: 그룹·선물 테이블과 읽기 규칙
-- 쓰기는 BE-06·07·08·11의 security definer RPC로만 한다. 여기서는 클라이언트 쓰기 권한·정책을 두지 않는다.
-- 선물은 겉(gift_boxes)과 속(gift_box_contents)으로 나눈다. RLS는 행 단위라 열을 숨길 수 없기 때문이다.
-- 겉에는 보낸 사람 열이 없다. 같은 그룹 멤버는 겉을 보지만, 누가 보냈는지와 내용은 볼 수 없다.

-- 그룹 -------------------------------------------------------------------------
create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 20 and btrim(name) <> ''),
  invite_code text not null unique default substr(md5(gen_random_uuid()::text), 1, 8)
              check (char_length(invite_code) = 8),
  all_manito  boolean not null default false,
  created_by  uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table public.group_members (
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index group_members_user_id_idx on public.group_members (user_id);

-- 정책 안에서 group_members를 다시 조회하면 group_members 정책이 자기 자신을 부르는 재귀가 된다.
-- security definer 함수는 RLS를 건너뛰고 읽으므로 재귀가 생기지 않는다.
create function public.is_group_member(p_group_id uuid) returns boolean
  language sql stable
  security definer
  set search_path = ''
as $$
  select exists (
    select 1 from public.group_members
     where group_id = p_group_id and user_id = auth.uid()
  );
$$;

-- 선물 겉 -----------------------------------------------------------------------
create table public.gift_boxes (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups (id) on delete cascade,
  recipient_id uuid references public.profiles (id) on delete cascade,  -- 마니또는 추첨 전까지 비어 있다
  kind         text not null check (kind in ('designated', 'manito')),
  box_color    text not null,
  ribbon_color text not null,
  stickers     jsonb not null default '[]'::jsonb
               check (jsonb_typeof(stickers) = 'array' and jsonb_array_length(stickers) <= 20),
  opened_at    timestamptz,
  created_at   timestamptz not null default now(),
  check (kind = 'manito' or recipient_id is not null)
);

create index gift_boxes_group_id_idx on public.gift_boxes (group_id);
create index gift_boxes_recipient_id_idx on public.gift_boxes (recipient_id);

-- 선물 속 -----------------------------------------------------------------------
create table public.gift_box_contents (
  box_id      uuid primary key references public.gift_boxes (id) on delete cascade,
  sender_id   uuid not null references public.profiles (id) on delete cascade,
  letter      text check (letter is null or (char_length(letter) between 1 and 1000 and btrim(letter) <> '')),
  photo_paths text[] not null default '{}' check (cardinality(photo_paths) <= 5),
  youtube_id  text check (youtube_id is null or youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  updated_at  timestamptz not null default now(),
  check (letter is not null or cardinality(photo_paths) > 0 or youtube_id is not null)
);

create index gift_box_contents_sender_id_idx on public.gift_box_contents (sender_id);

-- 권한: 네 테이블 모두 읽기만 ---------------------------------------------------------
alter table public.groups            enable row level security;
alter table public.group_members     enable row level security;
alter table public.gift_boxes        enable row level security;
alter table public.gift_box_contents enable row level security;

revoke all on public.groups, public.group_members, public.gift_boxes, public.gift_box_contents
  from anon, authenticated;
-- anon에도 select를 준다. 정책이 authenticated에만 있으므로 비로그인은 에러가 아니라 0행을 받는다
-- (backend/spec/README.md "RLS로 막힌 읽기는 에러가 아니라 0행").
grant select on public.groups, public.group_members, public.gift_boxes, public.gift_box_contents
  to anon, authenticated;

create policy "groups: members read" on public.groups
  for select to authenticated using (public.is_group_member(id));

create policy "group_members: members read" on public.group_members
  for select to authenticated using (public.is_group_member(group_id));

create policy "gift_boxes: members read" on public.gift_boxes
  for select to authenticated using (public.is_group_member(group_id));

-- 속: 보낸 사람은 언제나, 받는 사람은 개봉 시각부터, 그 밖의 사람은 끝까지 못 본다.
create policy "gift_box_contents: sender or opened recipient reads" on public.gift_box_contents
  for select to authenticated using (
    sender_id = auth.uid()
    or exists (
      select 1 from public.gift_boxes b
       where b.id = box_id
         and b.recipient_id = auth.uid()
         and now() >= (select open_at from public.app_config)
    )
  );
