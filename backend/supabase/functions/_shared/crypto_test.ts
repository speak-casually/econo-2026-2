import { assertEquals, assertNotEquals, assertRejects } from "jsr:@std/assert@1";
import { decryptToken, encryptToken } from "./crypto.ts";

function randomKey(): string {
  return btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))));
}

Deno.test("round trip", async () => {
  const key = randomKey();
  const { ciphertext, iv } = await encryptToken("refresh-abc", key);
  assertEquals(await decryptToken(ciphertext, iv, key), "refresh-abc");
});

Deno.test("fresh iv each call", async () => {
  const key = randomKey();
  const first = await encryptToken("same-token", key);
  const second = await encryptToken("same-token", key);
  assertNotEquals(first.iv, second.iv);
  assertNotEquals(first.ciphertext, second.ciphertext);
});

Deno.test("wrong key fails", async () => {
  const { ciphertext, iv } = await encryptToken("refresh-abc", randomKey());
  await assertRejects(() => decryptToken(ciphertext, iv, randomKey()));
});
