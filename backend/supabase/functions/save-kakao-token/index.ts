// POST /functions/v1/save-kakao-token
// 카카오 로그인 직후 프론트가 provider refresh token을 보내면, 진짜인지 확인하고 암호화해서 저장한다.
import { createClient } from "npm:@supabase/supabase-js@2";
import { encryptToken } from "../_shared/crypto.ts";
import { fetchKakaoUserId, hasTalkMessageScope, refreshKakaoToken } from "../_shared/kakao.ts";
import { corsHeaders, json } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  // 1. 로그인한 사용자인가
  const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: { user } } = await admin.auth.getUser(jwt);
  if (!user) return json(401, { error: "unauthorized" });

  const body = await req.json().catch(() => ({}));
  const refreshToken: unknown = body.refresh_token;
  if (typeof refreshToken !== "string" || refreshToken === "") return json(400, { error: "missing_token" });

  // 2. 이 사용자가 카카오로 로그인했는가 (identity id = 카카오 회원번호)
  const kakaoIdentity = user.identities?.find((i) => i.provider === "kakao");
  if (!kakaoIdentity) return json(403, { error: "kakao_user_mismatch" });

  // 3. 토큰이 진짜인가: 한 번 갱신해 보고, 토큰 주인이 같은 카카오 회원인지 본다
  let refreshed: Awaited<ReturnType<typeof refreshKakaoToken>>;
  let kakaoUserId: string;
  let talkMessage: boolean;
  try {
    refreshed = await refreshKakaoToken(refreshToken);
    kakaoUserId = await fetchKakaoUserId(refreshed.accessToken);
    talkMessage = await hasTalkMessageScope(refreshed.accessToken);
  } catch (e) {
    console.error(e);
    return json(502, { error: "kakao_refresh_failed" });
  }
  if (kakaoUserId !== kakaoIdentity.id) return json(403, { error: "kakao_user_mismatch" });

  // 4. 새 refresh token이 왔으면 그것을, 아니면 받은 것을 암호화해 저장 (사용자당 1행)
  const { ciphertext, iv } = await encryptToken(refreshed.refreshToken ?? refreshToken, Deno.env.get("TOKEN_ENC_KEY")!);
  const { error } = await admin.from("kakao_tokens").upsert(
    { user_id: user.id, kakao_user_id: kakaoUserId, enc_refresh_token: ciphertext, iv, updated_at: new Date().toISOString() },
    { onConflict: "user_id" },
  );
  if (error) {
    console.error(error);
    return json(500, { error: "save_failed" });
  }

  return json(200, { ok: true, talk_message: talkMessage });
});
