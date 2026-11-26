-- BE-03 공개 트리: 카드·좋아요·신고·금칙어

-- 금칙어 (클라이언트 접근 없음) --------------------------------------------------------
create table public.banned_words (
  word text primary key check (btrim(word) <> '')
);

alter table public.banned_words enable row level security;
revoke all on public.banned_words from anon, authenticated;
-- 정책을 만들지 않는다. 트리거(security definer)만 읽는다.

-- 카드 -------------------------------------------------------------------------
create table public.tree_cards (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null unique default auth.uid() references public.profiles (id) on delete cascade,
  template     text not null,
  drawing_path text,
  stickers     jsonb not null default '[]'::jsonb
               check (jsonb_typeof(stickers) = 'array' and jsonb_array_length(stickers) <= 20),
  letter       text not null check (char_length(letter) between 1 and 300 and btrim(letter) <> ''),
  like_count   int not null default 0 check (like_count >= 0),
  hidden       boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index tree_cards_like_count_idx on public.tree_cards (like_count desc);
create index tree_cards_created_at_idx on public.tree_cards (created_at desc);

alter table public.tree_cards enable row level security;
revoke all on public.tree_cards from anon, authenticated;
grant select on public.tree_cards to anon, authenticated;
-- 클라이언트가 쓸 수 있는 열은 네 개뿐이다. like_count·hidden·user_id는 열 권한으로 막는다.
grant insert (template, drawing_path, stickers, letter),
      update (template, drawing_path, stickers, letter),
      delete
   on public.tree_cards to authenticated;

create policy "tree_cards: visible unless hidden" on public.tree_cards
  for select using (not hidden or user_id = auth.uid() or public.is_admin());

create policy "tree_cards: owner hangs before tree deadline" on public.tree_cards
  for insert to authenticated
  with check (user_id = auth.uid() and now() < (select tree_deadline_at from public.app_config));

create policy "tree_cards: owner edits before tree deadline" on public.tree_cards
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and now() < (select tree_deadline_at from public.app_config));

-- 삭제는 마감과 상관없이 언제든
create policy "tree_cards: owner deletes anytime" on public.tree_cards
  for delete to authenticated
  using (user_id = auth.uid());

-- 금칙어 검사: 편지와 금칙어 모두 소문자로 바꾸고 공백을 지운 뒤 포함 여부를 본다.
-- 어떤 단어에 걸렸는지는 알려주지 않는다.
create function public.check_banned_words() returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if exists (
    select 1 from public.banned_words w
     where position(lower(regexp_replace(w.word, '\s', '', 'g'))
                    in lower(regexp_replace(new.letter, '\s', '', 'g'))) > 0
  ) then
    raise exception 'banned_word';
  end if;
  return new;
end;
$$;

create trigger tree_cards_check_banned_words
  before insert or update of letter on public.tree_cards
  for each row execute function public.check_banned_words();

create function public.touch_updated_at() returns trigger
  language plpgsql
  set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger tree_cards_touch_updated_at
  before update on public.tree_cards
  for each row execute function public.touch_updated_at();

-- 좋아요 ------------------------------------------------------------------------
create table public.card_likes (
  card_id    uuid not null references public.tree_cards (id) on delete cascade,
  user_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (card_id, user_id)
);

create index card_likes_user_id_idx on public.card_likes (user_id);

alter table public.card_likes enable row level security;
revoke all on public.card_likes from anon, authenticated;
grant select on public.card_likes to anon, authenticated;
grant insert (card_id), delete on public.card_likes to authenticated;

-- 누른 사람 목록은 카드 작성자만, 그리고 내가 누른 것은 나도 본다
create policy "card_likes: owner of card or liker reads" on public.card_likes
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.tree_cards t where t.id = card_id and t.user_id = auth.uid())
  );

-- 안쪽 조회에도 tree_cards의 RLS가 걸린다. 그래서 숨긴 카드는 id를 알아도 누를 수 없다.
-- 걸기 마감 후에도 누를 수 있다(시각 조건 없음).
create policy "card_likes: like visible cards" on public.card_likes
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.tree_cards t where t.id = card_id)
  );

create policy "card_likes: liker cancels" on public.card_likes
  for delete to authenticated
  using (user_id = auth.uid());

-- like_count는 좋아요 행이 생기고 지워질 때 트리거가 ±1 한다.
-- 클라이언트는 like_count update 권한이 없으므로 security definer로 바꾼다.
create function public.sync_like_count() returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.tree_cards set like_count = like_count + 1 where id = new.card_id;
  else
    update public.tree_cards set like_count = like_count - 1 where id = old.card_id;
  end if;
  return null;
end;
$$;

create trigger card_likes_sync_like_count
  after insert or delete on public.card_likes
  for each row execute function public.sync_like_count();

-- 신고 ------------------------------------------------------------------------
create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('card', 'profile')),
  target_id   uuid not null,
  created_at  timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);

alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;
grant select on public.reports to anon, authenticated;
grant insert (target_type, target_id) on public.reports to authenticated;

create policy "reports: admin reads" on public.reports
  for select using (public.is_admin());

create policy "reports: logged-in user reports" on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid());

-- 무작위 조회 (비로그인 허용) -------------------------------------------------------
-- security invoker(기본값)라 호출한 사람의 RLS가 그대로 걸린다. 숨김은 명시적으로도 뺀다.
create function public.random_tree_cards(p_limit int default 50)
  returns setof public.tree_cards
  language sql
  volatile
  set search_path = ''
as $$
  select * from public.tree_cards where not hidden order by random() limit p_limit;
$$;

grant execute on function public.random_tree_cards(int) to anon, authenticated;
