-- BE-01 기반: 설정 시각, 프로필, 개인 설정
begin;
select plan(16);

-- 준비: 사용자 a, b (기본 역할 postgres로 넣는다)
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.local');

-- 설정 시각
select is((select count(*)::int from public.app_config), 1, 'app_config has one row');
select is((select deadline_at from public.app_config), '2026-12-24 23:59:00+09'::timestamptz, 'deadline is 12/24 23:59 KST');
select is((select open_at from public.app_config), '2026-12-25 12:25:00+09'::timestamptz, 'open is 12/25 12:25 KST');
select is((select tree_deadline_at from public.app_config), '2026-12-25 23:59:00+09'::timestamptz, 'tree deadline is 12/25 23:59 KST');

-- 비로그인
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*)::int from public.app_config), 1, 'anon can read app_config');
select throws_ok($$ select public.complete_profile('익명', null, true) $$, 'P0001', 'not_authenticated', 'anon cannot complete profile');

-- 사용자 a
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select lives_ok($$ select public.complete_profile('눈사람조아', null, true) $$, 'complete_profile creates rows');
select throws_ok($$ select public.complete_profile('again', null, true) $$, 'P0001', 'profile_exists', 'second call rejected');
select throws_ok($$ update public.profiles set nickname = '1234567890123' where id = auth.uid() $$, '23514', null, '13-char nickname rejected');
select throws_ok($$ update public.profiles set nickname = '   ' where id = auth.uid() $$, '23514', null, 'whitespace-only nickname rejected');
select lives_ok($$ update public.profiles set nickname = '🎄🎄🎄🎄🎄🎄🎄🎄🎄🎄🎄🎄' where id = auth.uid() $$, '12 emoji nickname accepted');
select throws_ok($$ update public.user_settings set privacy_agreed_at = now() where user_id = auth.uid() $$, '42501', null, 'consent time cannot be changed by user');

-- now()는 트랜잭션 안에서 고정이라, 첫 방문 시각을 과거로 옮긴 뒤 다시 불러서 덮어쓰지 않는지 본다
select public.mark_home_visit();
select isnt((select first_home_visit_at from public.user_settings), null, 'mark_home_visit sets the first time');
reset role;
update public.user_settings set first_home_visit_at = '2026-12-01 09:00:00+09'
 where user_id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select public.mark_home_visit();
select is((select first_home_visit_at from public.user_settings), '2026-12-01 09:00:00+09'::timestamptz, 'mark_home_visit keeps the first time');

-- 사용자 b
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select is((select count(*)::int from public.user_settings), 0, 'b cannot read a settings');
select is((select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-00000000000a'), 1, 'b can read a profile');

select * from finish();
rollback;
