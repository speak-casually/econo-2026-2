-- 로컬 개발용 데이터. `supabase db reset` 때마다 마이그레이션 뒤에 들어간다. 운영·스테이징에는 넣지 않는다.
-- 테이블을 추가하는 작업(BE-03, BE-06 ...)은 그 테이블의 예시 데이터를 여기에 이어서 넣는다.
--
-- 로그인: 이메일·비밀번호 (카카오 키 없이 로컬에서 바로 로그인하려고 둔다)
--   admin@local.test / password123  (관리자, 닉네임 "산타")
--   user@local.test  / password123  (일반 사용자, 닉네임 "루돌프")
--   new@local.test   / password123  (프로필 없음: 가입 직후 상태)
--
-- id 규칙: seed는 사용자 10…, 그룹 21…, 상자 31…, 카드 41…. pgTAP 테스트는 00…, 20…, 30…을 쓴다.
-- 테스트는 seed가 들어간 DB에서 돌기 때문에 같은 id를 쓰면 pk 충돌로 테스트가 깨진다.

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

-- BE-02 그룹·선물 (산타·루돌프가 멤버인 그룹 1개, 산타 → 루돌프 지정 선물 1개)
-- 루돌프로 로그인하면 겉은 보이고 속은 개봉 시각 전까지 0행이다.
insert into public.groups (id, name, invite_code, all_manito, created_by) values
  ('21000000-0000-0000-0000-000000000001', '로컬 테스트 그룹', 'localtst', false, '10000000-0000-0000-0000-000000000001');

insert into public.group_members (group_id, user_id) values
  ('21000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001'),
  ('21000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002');

insert into public.gift_boxes (id, group_id, recipient_id, kind, box_color, ribbon_color, stickers) values
  ('31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000002', 'designated', 'red', 'gold', '[{"id":"star","x":0.4,"y":0.2}]');

insert into public.gift_box_contents (box_id, sender_id, letter) values
  ('31000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '루돌프야 메리 크리스마스!');

-- BE-03 공개 트리 (산타·루돌프 카드 각 1장, 루돌프가 산타 카드에 좋아요, 금칙어 예시)
-- id 규칙: 카드 41…
insert into public.banned_words (word) values ('나쁜말'), ('바보');

insert into public.tree_cards (id, user_id, template, letter, stickers) values
  ('41000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'snowman',
   '모두 메리 크리스마스! 🎅', '[{"id":"star","x":0.5,"y":0.1}]'),
  ('41000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'tree',
   '썰매 끌 준비 완료 🦌', '[]');

insert into public.card_likes (card_id, user_id) values
  ('41000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002');
