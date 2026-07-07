import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { connectDevice } from "../src/relay/client";
import { createRelay } from "../src/relay/relay";
import { encryptPayload } from "../src/shared/crypto";

const secret = "pairing-secret-for-tests";

let relay: Awaited<ReturnType<typeof createRelay>>;

beforeEach(async () => {
  relay = await createRelay({
    hostname: "127.0.0.1",
    port: 0,
    pairingSecret: secret,
    maxPayloadBytes: 1024 * 1024,
  });
});

afterEach(async () => {
  await relay.stop();
});

describe("relay protocol", () => {
  test("rejects a device that cannot prove the pairing secret", async () => {
    await expect(
      connectDevice({ url: relay.url, pairingSecret: "wrong-secret", deviceId: "phone" }),
    ).rejects.toThrow(/auth_failed/);
  });

  test("broadcasts a published payload to another paired device", async () => {
    const laptop = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "laptop" });
    const phone = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "phone" });

    const seen = phone.nextPayload();
    const frame = await encryptPayload(
      {
        type: "text",
        mime: "text/plain",
        origin: "laptop",
        ts: 1_800_000_000_001,
      },
      new TextEncoder().encode("hello from laptop"),
      secret,
    );

    await laptop.publish(frame);

    await expect(seen).resolves.toMatchObject({
      type: "text",
      mime: "text/plain",
      origin: "laptop",
      ts: 1_800_000_000_001,
    });

    laptop.close();
    phone.close();
  });

  test("sends the current pool payload to a paired device that joins late", async () => {
    const laptop = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "laptop" });
    const frame = await encryptPayload(
      {
        type: "text",
        mime: "text/plain",
        origin: "laptop",
        ts: 1_800_000_000_002,
      },
      new TextEncoder().encode("latest payload"),
      secret,
    );

    await laptop.publish(frame);
    const phone = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "phone" });

    const currentPoolPayload = await phone.nextPayload();
    expect(currentPoolPayload).toMatchObject({
      origin: "laptop",
      ts: 1_800_000_000_002,
    });

    laptop.close();
    phone.close();
  });

  test("keeps the latest payload when an older payload arrives later", async () => {
    const laptop = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "laptop" });
    const phone = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "phone" });

    const latest = await encryptPayload(
      {
        type: "text",
        mime: "text/plain",
        origin: "laptop",
        ts: 1_800_000_000_020,
      },
      new TextEncoder().encode("latest"),
      secret,
    );
    const older = await encryptPayload(
      {
        type: "text",
        mime: "text/plain",
        origin: "phone",
        ts: 1_800_000_000_010,
      },
      new TextEncoder().encode("older"),
      secret,
    );

    await laptop.publish(latest);
    await phone.nextPayload();
    await phone.publish(older);

    const lateJoiner = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "tablet" });
    const currentPoolPayload = await lateJoiner.nextPayload();

    expect(currentPoolPayload).toMatchObject({ origin: "laptop", ts: 1_800_000_000_020 });

    laptop.close();
    phone.close();
    lateJoiner.close();
  });

  test("rejects oversized payloads with a clear error", async () => {
    await relay.stop();
    relay = await createRelay({
      hostname: "127.0.0.1",
      port: 0,
      pairingSecret: secret,
      maxPayloadBytes: 8,
    });
    const laptop = await connectDevice({ url: relay.url, pairingSecret: secret, deviceId: "laptop" });
    const frame = await encryptPayload(
      {
        type: "text",
        mime: "text/plain",
        origin: "laptop",
        ts: 1_800_000_000_030,
      },
      new TextEncoder().encode("this payload is too large"),
      secret,
    );

    await expect(laptop.publish(frame)).rejects.toThrow(/payload_too_large/);

    laptop.close();
  });
});
