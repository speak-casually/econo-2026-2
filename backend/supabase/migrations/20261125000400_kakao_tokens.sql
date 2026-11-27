-- BE-04 카카오 refresh token 저장소
-- 12/25 알림 때 사용자는 접속해 있지 않으므로, 저장해 둔 refresh token으로 새 access token을 받아 보낸다.
-- 토큰은 Edge Function이 AES-GCM으로 암호화해서 넣는다. DB에는 평문이 남지 않는다.
-- 클라이언트는 읽지도 쓰지도 못한다(정책 없음). Edge Function의 service_role만 RLS를 건너뛰어 접근한다.

create table public.kakao_tokens (
  user_id           uuid primary key references auth.users (id) on delete cascade,  -- 사용자당 1행, 다시 로그인하면 덮어쓴다
  kakao_user_id     text not null,
  enc_refresh_token text not null,
  iv                text not null,
  updated_at        timestamptz not null default now()
);

alter table public.kakao_tokens enable row level security;
revoke all on public.kakao_tokens from anon, authenticated;
