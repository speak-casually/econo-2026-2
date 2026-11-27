// 카카오 refresh token을 DB에 넣기 전에 AES-GCM(256비트)으로 암호화한다.
// 키는 함수 secret TOKEN_ENC_KEY(base64 32바이트). IV는 매번 새로 만든다(같은 키로 IV를 재사용하면 GCM이 깨진다).

function toBase64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function fromBase64(b64: string): Uint8Array<ArrayBuffer> {
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function importKey(keyB64: string): Promise<CryptoKey> {
  return crypto.subtle.importKey("raw", fromBase64(keyB64), "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function encryptToken(plain: string, keyB64: string): Promise<{ ciphertext: string; iv: string }> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await importKey(keyB64);
  const encrypted = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(plain));
  return { ciphertext: toBase64(new Uint8Array(encrypted)), iv: toBase64(iv) };
}

// 키가 틀리거나 암호문이 바뀌었으면 GCM 인증 태그 검사에서 실패해 reject된다.
export async function decryptToken(ciphertext: string, iv: string, keyB64: string): Promise<string> {
  const key = await importKey(keyB64);
  const decrypted = await crypto.subtle.decrypt({ name: "AES-GCM", iv: fromBase64(iv) }, key, fromBase64(ciphertext));
  return new TextDecoder().decode(decrypted);
}
