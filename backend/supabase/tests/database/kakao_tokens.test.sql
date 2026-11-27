-- BE-04 kakao_tokens: 클라이언트는 읽지도 쓰지도 못한다
begin;
select plan(3);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000a', 'a@test.local');
insert into public.kakao_tokens (user_id, kakao_user_id, enc_refresh_token, iv)
values ('00000000-0000-0000-0000-00000000000a', '12345', 'cipher', 'iv');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select throws_ok($$ select * from public.kakao_tokens $$, '42501', null, 'owner cannot read own token row');
select throws_ok($$ update public.kakao_tokens set iv = 'x' $$, '42501', null, 'owner cannot write token row');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from public.kakao_tokens $$, '42501', null, 'anon cannot read tokens');

select * from finish();
rollback;
