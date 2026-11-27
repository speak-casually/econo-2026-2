# BE-06 그룹 만들기·초대·참여

- 주차: 2주차 (11/30) · 우선순위: P0
- 근거: 요구사항 6.1·6.2절, 기술 4.2절
- 선행: BE-02 · 이 작업을 쓰는 작업: BE-07, BE-08, FE-07, FE-08, FE-09, FE-12

## 목적

비공개 그룹을 만들고, 초대 링크로 들어오게 한다. 정원과 마감을 DB가 지킨다.

## 동작 규칙

- 그룹 이름 1~20자. 한 사람이 만들 수 있는 그룹 수에 제한이 없다. 만든 사람은 바로 멤버가 되고, 관리 권한은 없다(방장 없음).
- 모두 마니또 여부는 만들 때만 정한다. 바꾸는 방법을 만들지 않는다.
- 마감 후에는 만들기·참여 모두 `deadline_passed`.
- 초대 코드로 그룹 정보를 볼 때는 **이름, 멤버 수, 모두 마니또 여부, 내가 이미 멤버인지**만 돌려준다. 멤버 이름은 주지 않는다. 비로그인도 볼 수 있다. 그룹 id는 이미 멤버일 때만 준다.
- 참여
  - 없는 코드면 `invite_not_found`.
  - 이미 멤버면 에러 없이 그룹 id를 돌려준다(정원 검사보다 먼저).
  - 그룹 행을 `for update`로 잠근 뒤 인원을 센다. 30명이면 `group_full`. 동시에 참여해도 31명이 되지 않는다.
- 한 사람이 여러 그룹에 들어갈 수 있다. 나가기·강퇴는 없다.
- **모두 마니또 그룹**은 이 작업에서 상자 없이 만들거나 참여하려 하면 `manito_box_required`를 낸다. 상자와 함께 만들고 참여하는 기능은 BE-08에서 완성한다.

## 인터페이스

```sql
public.create_group(p_name text, p_all_manito boolean, p_manito_box jsonb default null)
  returns table (group_id uuid, invite_code text)
public.get_invite(p_code text)
  returns table (group_id uuid /* 멤버일 때만, 아니면 null */, name text, member_count int,
                 all_manito boolean, is_member boolean)   -- anon 허용, 없는 코드면 0행
public.join_group(p_code text, p_manito_box jsonb default null) returns uuid  -- group_id
```

멤버 목록, 내 그룹 목록, 그룹별 멤버 수는 BE-02의 읽기 규칙으로 클라이언트가 직접 조회한다(`group_members`에 `profiles` 포함). 마이그레이션: `backend/supabase/migrations/<날짜>_groups_invite.sql`.

## 완료 조건

`backend/supabase/tests/database/groups_invite.test.sql`:
- [ ] `create_group('우리 동아리 크리스마스', false)`는 그룹 1개와 멤버 1명(만든 사람)을 만든다.
- [ ] 이름 21자, 공백만 있는 이름은 거부된다.
- [ ] 비로그인 `get_invite`는 이름과 멤버 수를 돌려주고 `group_id`는 null, 없는 코드는 0행.
- [ ] 다른 사용자가 `join_group`하면 멤버가 2명이 되고, 같은 사용자가 다시 부르면 에러 없이 같은 id.
- [ ] 멤버 30명인 그룹에 31번째 사용자가 참여하면 `group_full`.
- [ ] 마감 후 `create_group`, `join_group`은 `deadline_passed`.
- [ ] 없는 코드로 참여하면 `invite_not_found`.
- [ ] `p_all_manito = true`이고 상자가 없으면 `manito_box_required`, 그룹은 생기지 않는다.
- [ ] 클라이언트가 `groups`·`group_members`에 직접 insert하면 `42501`.

## 범위 밖

- 모두 마니또 그룹의 상자 동반 생성·참여(BE-08)
- 초대 링크 공유 화면(FE-07)
