// 카카오 API 호출 모음. 실패하면 응답 본문을 담아 Error를 던진다.

const KAUTH = "https://kauth.kakao.com";
const KAPI = "https://kapi.kakao.com";
const MEMO_TEXT_LIMIT = 200;

async function failWith(what: string, res: Response): Promise<never> {
  throw new Error(`${what} failed: ${res.status} ${await res.text()}`);
}

// 응답의 refresh_token은 만료 1개월 미만일 때만 온다. 없으면 null이고, 호출한 쪽이 기존 값을 계속 쓴다.
export async function refreshKakaoToken(refreshToken: string): Promise<{ accessToken: string; refreshToken: string | null }> {
  const res = await fetch(`${KAUTH}/oauth/token`, {
    method: "POST",
    body: new URLSearchParams({
      grant_type: "refresh_token",
      client_id: Deno.env.get("KAKAO_REST_API_KEY") ?? "",
      client_secret: Deno.env.get("KAKAO_CLIENT_SECRET") ?? "",
      refresh_token: refreshToken,
    }),
  });
  if (!res.ok) await failWith("kakao token refresh", res);
  const body = await res.json();
  return { accessToken: body.access_token, refreshToken: body.refresh_token ?? null };
}

export async function fetchKakaoUserId(accessToken: string): Promise<string> {
  const res = await fetch(`${KAPI}/v2/user/me`, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!res.ok) await failWith("kakao user/me", res);
  const body = await res.json();
  return String(body.id);
}

export async function hasTalkMessageScope(accessToken: string): Promise<boolean> {
  const url = `${KAPI}/v2/user/scopes?scopes=${encodeURIComponent('["talk_message"]')}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!res.ok) await failWith("kakao user/scopes", res);
  const body = await res.json();
  return body.scopes?.[0]?.agreed === true;
}

// 카카오 기본 텍스트 템플릿은 본문 200자 제한이 있다. 이모지가 반으로 잘리지 않게 코드 포인트 단위로 자른다.
export function buildMemoTemplate(text: string, url: string): string {
  return JSON.stringify({
    object_type: "text",
    text: [...text].slice(0, MEMO_TEXT_LIMIT).join(""),
    link: { web_url: url, mobile_web_url: url },
    button_title: "열어보기",
  });
}

export async function sendKakaoMemo(accessToken: string, templateJson: string): Promise<void> {
  const res = await fetch(`${KAPI}/v2/api/talk/memo/default/send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}` },
    body: new URLSearchParams({ template_object: templateJson }),
  });
  if (!res.ok) await failWith("kakao memo send", res);
  const body = await res.json();
  if (body.result_code !== 0) throw new Error(`kakao memo send failed: ${JSON.stringify(body)}`);
}
