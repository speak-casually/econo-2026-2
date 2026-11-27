import { assertEquals } from "jsr:@std/assert@1";
import { buildMemoTemplate } from "./kakao.ts";

Deno.test("memo template", () => {
  const t = JSON.parse(buildMemoTemplate("선물이 열렸어요", "https://example.com"));
  assertEquals(t.object_type, "text");
  assertEquals(t.text, "선물이 열렸어요");
  assertEquals(t.link.web_url, "https://example.com");
  assertEquals(t.link.mobile_web_url, "https://example.com");
});

Deno.test("memo text cut to 200 chars", () => {
  const t = JSON.parse(buildMemoTemplate("가".repeat(250), "https://x"));
  assertEquals([...t.text].length, 200);
});

Deno.test("memo text cut counts emoji as one char", () => {
  const t = JSON.parse(buildMemoTemplate("🎄".repeat(250), "https://x"));
  assertEquals([...t.text].length, 200);
});
