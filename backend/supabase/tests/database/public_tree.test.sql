-- BE-03 공개 트리: 카드·좋아요·신고·금칙어
begin;
select plan(24);

-- 준비 (기본 역할 postgres): a·b·c와 각자 프로필, 금칙어 하나
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.local');
insert into public.profiles (id, nickname) values
  ('00000000-0000-0000-0000-00000000000a', '에이'),
  ('00000000-0000-0000-0000-00000000000b', '비'),
  ('00000000-0000-0000-0000-00000000000c', '씨');
-- seed에도 같은 금칙어가 있으므로 이미 있으면 넘어간다
insert into public.banned_words values ('나쁜말') on conflict do nothing;

-- a: 카드 걸기와 쓰기 규칙 -----------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select lives_ok($$ insert into public.tree_cards (template, letter) values ('snowman', '메리 크리스마스') $$, 'a hangs a card');
select throws_ok($$ insert into public.tree_cards (template, letter) values ('tree', '두 번째') $$, '23505', null, 'one card per user');
select throws_ok($$ update public.tree_cards set like_count = 999 where user_id = auth.uid() $$, '42501', null, 'client cannot set like_count');
select throws_ok($$ update public.tree_cards set hidden = false where user_id = auth.uid() $$, '42501', null, 'client cannot set hidden');
select throws_ok($$ update public.tree_cards set letter = '   ' where user_id = auth.uid() $$, '23514', null, 'whitespace-only letter rejected');
select throws_ok($$ update public.tree_cards set letter = '나 쁜 말 이야' where user_id = auth.uid() $$, 'P0001', 'banned_word', 'banned word ignoring spaces');

-- b: 이모지 편지, 좋아요, 신고 --------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select lives_ok($$ insert into public.tree_cards (template, letter) values ('tree', repeat('🎄', 300)) $$, '300 emoji letter accepted');
select lives_ok($$ insert into public.card_likes (card_id) select id from public.tree_cards where letter = '메리 크리스마스' $$, 'b likes a card');
select throws_ok($$ insert into public.card_likes (card_id) select id from public.tree_cards where letter = '메리 크리스마스' $$, '23505', null, 'double like rejected');
select is((select like_count from public.tree_cards where letter = '메리 크리스마스'), 1, 'like_count incremented');
select lives_ok($$ delete from public.card_likes where user_id = auth.uid() $$, 'b cancels like');
select is((select like_count from public.tree_cards where letter = '메리 크리스마스'), 0, 'like_count decremented');
select lives_ok($$ insert into public.card_likes (card_id) select id from public.tree_cards where letter = '메리 크리스마스' $$, 'b likes again');
select lives_ok($$ insert into public.reports (target_type, target_id) select 'card', id from public.tree_cards where letter = '메리 크리스마스' $$, 'b reports card');
select throws_ok($$ insert into public.reports (target_type, target_id) select 'card', id from public.tree_cards where letter = '메리 크리스마스' $$, '23505', null, 'duplicate report rejected');
select is((select count(*)::int from public.reports), 0, 'non-admin cannot read reports');

-- c: 좋아요 누른 사람 목록은 못 본다 ----------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select is((select count(*)::int from public.card_likes), 0, 'c cannot see who liked');

-- a (작성자): 누른 사람 목록을 본다
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.card_likes), 1, 'owner sees likers');

-- 관리자가 a의 카드를 숨긴다 (관리 기능은 BE-13. 여기서는 postgres로 직접 바꾼다)
reset role;
select id as card_id from public.tree_cards where letter = '메리 크리스마스' \gset
update public.tree_cards set hidden = true where id = :'card_id';

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*)::int from public.tree_cards where letter = '메리 크리스마스'), 0, 'hidden card invisible to anon');

-- c는 숨긴 카드의 id를 알고 있다고 가정한다
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select throws_ok(format($$ insert into public.card_likes (card_id) values (%L) $$, :'card_id'), '42501', null, 'cannot like hidden card by id');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.tree_cards where letter = '메리 크리스마스'), 1, 'owner still sees own hidden card');

-- 걸기 마감 후: 새 카드·수정은 거부, 삭제는 허용 ------------------------------------------
reset role;
update public.app_config set tree_deadline_at = now() - interval '1 minute';
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select throws_ok($$ insert into public.tree_cards (template, letter) values ('tree', '늦었다') $$, '42501', null, 'new card rejected after tree deadline');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select throws_ok($$ update public.tree_cards set letter = '고쳐 보기' where user_id = auth.uid() $$, '42501', null, 'edit rejected after tree deadline');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select results_eq(
  $$ with d as (delete from public.tree_cards where user_id = auth.uid() returning 1) select count(*)::int from d $$,
  $$ values (1) $$,
  'delete allowed after tree deadline');

select * from finish();
rollback;
