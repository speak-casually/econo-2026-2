-- 로컬 개발용 데이터. `supabase db reset` 때마다 마이그레이션 뒤에 들어간다. 운영·스테이징에는 넣지 않는다.
-- 테이블을 추가하는 작업(BE-03, BE-06 ...)은 그 테이블의 예시 데이터를 여기에 이어서 넣는다.
--
-- 로그인: 이메일·비밀번호 (카카오 키 없이 로컬에서 바로 로그인하려고 둔다)
--   admin@local.test / password123  (관리자, 닉네임 "산타")
--   user@local.test  / password123  (일반 사용자, 닉네임 "루돌프")
--   new@local.test   / password123  (프로필 없음: 가입 직후 상태)

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
   'admin@local.test', extensions.crypt('password123', extensions.gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"],"role":"admin"}', '{}', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
   'user@local.test', extensions.crypt('password123', extensions.gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated',
   'new@local.test', extensions.crypt('password123', extensions.gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}', '{}', '', '', '', '');

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, json_build_object('sub', u.id::text, 'email', u.email), 'email', now(), now(), now()
  from auth.users u
 where u.email like '%@local.test';

-- 프로필이 있는 두 사람 (new@local.test는 프로필 설정 화면 확인용으로 비워 둔다)
insert into public.profiles (id, nickname) values
  ('10000000-0000-0000-0000-000000000001', '산타'),
  ('10000000-0000-0000-0000-000000000002', '루돌프');

insert into public.user_settings (user_id, privacy_agreed_at, age14_agreed_at, kakao_notify, first_home_visit_at) values
  ('10000000-0000-0000-0000-000000000001', now(), now(), true, now()),
  ('10000000-0000-0000-0000-000000000002', now(), now(), false, null);
