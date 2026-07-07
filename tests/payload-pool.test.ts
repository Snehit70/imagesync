import { describe, expect, test } from "bun:test";
import { PayloadPool } from "../src/relay/payload-pool";
import type { PayloadFrame } from "../src/shared/wire";

const frame: PayloadFrame = {
  v: 1,
  type: "text",
  mime: "text/plain",
  origin: "phone",
  ts: 1_800_000_030_000,
  nonce: "nonce",
  payload: "payload",
};

describe("payload pool", () => {
  test("keeps the published payload even when a subscriber fails", async () => {
    const pool = new PayloadPool();
    pool.subscribe(() => {
      throw new Error("subscriber failed");
    });

    await expect(pool.publish(frame)).resolves.toBe(true);
    expect(pool.current).toEqual(frame);
  });
});
