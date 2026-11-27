// POST /functions/v1/send-kakao-test
// 관리자가 자기 카톡으로 테스트 메시지 1통을 보낸다. 저장한 토큰으로 실제 발송이 되는지 확인하는 용도.
import { createClient } from "npm:@supabase/supabase-js@2";
import { decryptToken, encryptToken } from "../_shared/crypto.ts";
import { buildMemoTemplate, refreshKakaoToken, sendKakaoMemo } from "../_shared/kakao.ts";
import { corsHeaders, json } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: { user } } = await admin.auth.getUser(jwt);
  if (!user) return json(401, { error: "unauthorized" });
  // app_metadata는 사용자가 바꿀 수 없다 (DB의 public.is_admin()과 같은 기준)
  if (user.app_metadata?.role !== "admin") return json(403, { error: "forbidden" });

  const { data: row } = await admin.from("kakao_tokens").select("enc_refresh_token, iv").eq("user_id", user.id).maybeSingle();
  if (!row) return json(404, { error: "no_token" });

  const key = Deno.env.get("TOKEN_ENC_KEY")!;
  try {
    const refreshed = await refreshKakaoToken(await decryptToken(row.enc_refresh_token, row.iv, key));
    if (refreshed.refreshToken) {
      const { ciphertext, iv } = await encryptToken(refreshed.refreshToken, key);
      await admin.from("kakao_tokens")
        .update({ enc_refresh_token: ciphertext, iv, updated_at: new Date().toISOString() })
        .eq("user_id", user.id);
    }
    const siteUrl = Deno.env.get("SITE_URL") ?? "http://localhost:5173";
    await sendKakaoMemo(refreshed.accessToken, buildMemoTemplate("Christmas Gift For You 테스트 메시지", siteUrl));
  } catch (e) {
    console.error(e);
    return json(502, { error: "kakao_send_failed" });
  }

  return json(200, { ok: true });
});
