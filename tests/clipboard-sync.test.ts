import { describe, expect, test } from "bun:test";
import {
  startClipboardSync,
  type ClipboardHealth,
  type WatchableClipboardAdapter,
} from "../src/relay/clipboard-sync";
import { PayloadPool } from "../src/relay/payload-pool";
import { decryptPayload, encryptPayload } from "../src/shared/crypto";
import type { ClipboardPayload } from "../src/relay/clipboard";

class FakeClipboard implements WatchableClipboardAdapter {
  payload: ClipboardPayload | undefined;
  writes: ClipboardPayload[] = [];
  private onChange: (() => Promise<void> | void) | undefined;
  private onReady: (() => void) | undefined;
  private onFailure: ((error: Error) => void) | undefined;

  async read() {
    return this.payload;
  }

  async write(payload: ClipboardPayload) {
    this.writes.push(payload);
    this.payload = payload;
  }

  watch(
    onChange: () => Promise<void> | void,
    onReady?: () => void,
    onFailure?: (error: Error) => void,
  ) {
    this.onChange = onChange;
    this.onReady = onReady;
    this.onFailure = onFailure;
    return () => {
      this.onChange = undefined;
      this.onReady = undefined;
      this.onFailure = undefined;
    };
  }

  async changeTo(payload: ClipboardPayload) {
    this.payload = payload;
    await this.onChange?.();
  }

  becomeReady() {
    this.onReady?.();
  }

  fail(error: Error) {
    this.onFailure?.(error);
  }
}

describe("clipboard sync", () => {
  test("publishes local clipboard changes into the encrypted pool", async () => {
    const pool = new PayloadPool();
    const clipboard = new FakeClipboard();
    const stop = startClipboardSync({
      clipboard,
      pool,
      pairingSecret: "pairing-secret",
      origin: "laptop",
      now: () => 1_800_000_020_000,
    });

    await clipboard.changeTo({
      type: "text",
      mime: "text/plain",
      data: new TextEncoder().encode("from laptop"),
    });

    expect(pool.current).toMatchObject({
      type: "text",
      mime: "text/plain",
      origin: "laptop",
      ts: 1_800_000_020_000,
    });
    expect(await decryptPayload(pool.current!, "pairing-secret")).toEqual(new TextEncoder().encode("from laptop"));

    stop();
  });

  test("writes incoming device payloads into the laptop clipboard", async () => {
    const pool = new PayloadPool();
    const clipboard = new FakeClipboard();
    const stop = startClipboardSync({
      clipboard,
      pool,
      pairingSecret: "pairing-secret",
      origin: "laptop",
      now: () => 1_800_000_020_001,
    });
    const frame = await encryptPayload(
      { type: "image", mime: "image/png", origin: "phone", ts: 1_800_000_020_002 },
      new Uint8Array([137, 80, 78, 71]),
      "pairing-secret",
    );

    await pool.publish(frame);

    expect(clipboard.writes).toEqual([
      {
        type: "image",
        mime: "image/png",
        data: new Uint8Array([137, 80, 78, 71]),
      },
    ]);

    stop();
  });

  test("reports watcher readiness and degradation", () => {
    const pool = new PayloadPool();
    const clipboard = new FakeClipboard();
    const health: ClipboardHealth[] = [];
    const stop = startClipboardSync({
      clipboard,
      pool,
      pairingSecret: "pairing-secret",
      origin: "laptop",
      now: Date.now,
      onHealthChange: (next) => health.push(next),
    });

    clipboard.becomeReady();
    clipboard.fail(new Error("wl-paste --watch failed: unsupported protocol"));

    expect(health).toEqual([
      { enabled: true, status: "healthy", watcher: "wl-paste --watch" },
      {
        enabled: true,
        status: "degraded",
        watcher: "wl-paste --watch",
        error: "wl-paste --watch failed: unsupported protocol",
      },
    ]);
    stop();
  });
});
