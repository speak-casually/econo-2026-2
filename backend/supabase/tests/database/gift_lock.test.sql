-- BE-02 개봉 전 잠금: 그룹·선물 테이블과 읽기 권한
begin;
select plan(14);

-- 준비 (기본 역할 postgres): a 보낸 사람, b 받는 사람, c 같은 그룹, d 그룹 밖
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.local'),
  ('00000000-0000-0000-0000-00000000000d', 'd@test.local');

-- 멤버·받는 사람·보낸 사람은 profiles를 가리킨다 (FE가 group_members에 profiles를 붙여 조회하므로)
insert into public.profiles (id, nickname) values
  ('00000000-0000-0000-0000-00000000000a', '에이'),
  ('00000000-0000-0000-0000-00000000000b', '비'),
  ('00000000-0000-0000-0000-00000000000c', '씨'),
  ('00000000-0000-0000-0000-00000000000d', '디');

insert into public.groups (id, name, all_manito, created_by) values
  ('20000000-0000-0000-0000-000000000001', '우리 반', false, '00000000-0000-0000-0000-00000000000a');

insert into public.group_members (group_id, user_id) values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a'),
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b'),
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c');

insert into public.gift_boxes (id, group_id, recipient_id, kind, box_color, ribbon_color) values
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-00000000000b', 'designated', 'red', 'gold');

insert into public.gift_box_contents (box_id, sender_id, letter) values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '메리 크리스마스');

-- 제약: 편지·사진·음반이 모두 없는 속은 거부
select throws_ok(
  $$ insert into public.gift_box_contents (box_id, sender_id) values
     ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000c') $$,
  '23514', null, 'contents with no letter, photo or music rejected');

-- 비로그인
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is((select count(*)::int from public.groups), 0, 'anon sees no groups');
select is((select count(*)::int from public.gift_boxes), 0, 'anon sees no boxes');

-- d (그룹 밖)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
select is((select count(*)::int from public.gift_boxes), 0, 'non-member sees no boxes');
select is((select count(*)::int from public.groups), 0, 'non-member sees no groups');

-- c (같은 그룹)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select is((select count(*)::int from public.gift_boxes), 1, 'member sees exterior');
select is((select count(*)::int from public.group_members), 3, 'member sees all members of the group');
select is((select count(*)::int from public.gift_box_contents), 0, 'other member never sees contents');

-- b (받는 사람), 개봉 전
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select is((select count(*)::int from public.gift_box_contents), 0, 'recipient cannot see contents before open');

-- a (보낸 사람)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.gift_box_contents), 1, 'sender always sees contents');
select throws_ok(
  $$ insert into public.gift_boxes (group_id, recipient_id, kind, box_color, ribbon_color) values
     ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000b', 'designated', 'red', 'gold') $$,
  '42501', null, 'client cannot insert boxes directly');

-- 개봉 시각을 과거로 옮긴다
reset role;
update public.app_config set open_at = now() - interval '1 minute';
set local role authenticated;

-- b, 개봉 후
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
select is((select letter from public.gift_box_contents), '메리 크리스마스', 'recipient sees contents after open');

-- c, 개봉 후
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select is((select count(*)::int from public.gift_box_contents), 0, 'other member still cannot see contents after open');

-- a, 개봉 후
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.gift_box_contents), 1, 'sender still sees contents after open');

select * from finish();
rollback;
