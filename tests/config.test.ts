import { describe, expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { loadOrCreateRelayConfig } from "../src/relay/config";

describe("relay config", () => {
  test("creates a persistent pairing secret on first run", async () => {
    const dir = await mkdtemp(join(tmpdir(), "imagesync-config-"));
    const path = join(dir, "relay.json");

    const first = await loadOrCreateRelayConfig(path);
    const second = await loadOrCreateRelayConfig(path);

    expect(first.pairingSecret.length).toBeGreaterThan(30);
    expect(second).toEqual(first);

    await rm(dir, { recursive: true, force: true });
  });
});
