import { describe, expect, test } from "bun:test";
import { decryptPayload, encryptPayload } from "../src/shared/crypto";

describe("payload crypto", () => {
  test("round-trips encrypted text payloads", async () => {
    const secret = "pairing-secret";
    const plaintext = new TextEncoder().encode("clipboard text");

    const frame = await encryptPayload(
      { type: "text", mime: "text/plain", origin: "laptop", ts: 1_800_000_010_000 },
      plaintext,
      secret,
    );

    await expect(decryptPayload(frame, secret)).resolves.toEqual(plaintext);
  });

  test("rejects the wrong pairing secret", async () => {
    const frame = await encryptPayload(
      { type: "text", mime: "text/plain", origin: "laptop", ts: 1_800_000_010_001 },
      new TextEncoder().encode("private clipboard text"),
      "correct-secret",
    );

    await expect(decryptPayload(frame, "wrong-secret")).rejects.toThrow();
  });

  test("rejects tampered metadata", async () => {
    const frame = await encryptPayload(
      { type: "image", mime: "image/png", origin: "phone", ts: 1_800_000_010_002 },
      new Uint8Array([137, 80, 78, 71]),
      "pairing-secret",
    );

    await expect(decryptPayload({ ...frame, mime: "image/jpeg" }, "pairing-secret")).rejects.toThrow();
  });
});
