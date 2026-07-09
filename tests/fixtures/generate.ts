// Regenerates crypto-fixtures.json from the TypeScript implementation:
//   bun tests/fixtures/generate.ts
// The Dart suite (app/test/crypto_fixtures_test.dart) verifies the same bytes,
// so both languages must agree on KDF, AAD encoding, nonce, and tag layout.
import { createPairingProof } from "../../src/shared/auth";
import { encryptPayload } from "../../src/shared/crypto";
import type { PayloadMetadata } from "../../src/shared/wire";

interface PayloadVectorInput {
  name: string;
  pairingSecret: string;
  metadata: PayloadMetadata;
  plaintext: Uint8Array;
  nonce: Uint8Array;
}

function nonceOf(seed: number): Uint8Array {
  return new Uint8Array(Array.from({ length: 12 }, (_, i) => (seed + i) & 0xff));
}

const payloadInputs: PayloadVectorInput[] = [
  {
    name: "text-ascii",
    pairingSecret: "fixture-secret-1",
    metadata: { type: "text", mime: "text/plain", origin: "laptop", ts: 1_800_000_000_001 },
    plaintext: new TextEncoder().encode("clipboard text fixture"),
    nonce: nonceOf(1),
  },
  {
    name: "image-binary",
    pairingSecret: "fixture-secret-2",
    metadata: { type: "image", mime: "image/png", origin: "phone", ts: 1_800_000_000_002 },
    plaintext: new Uint8Array(Array.from({ length: 256 }, (_, i) => i)),
    nonce: nonceOf(50),
  },
  {
    name: "text-unicode",
    pairingSecret: "paîring-🔑-secret",
    metadata: { type: "text", mime: "text/plain", origin: "laptop-α-📎", ts: 1_800_000_000_003 },
    plaintext: new TextEncoder().encode("unicode clipboard 📋 ✓ ñ"),
    nonce: nonceOf(100),
  },
  {
    name: "empty-plaintext",
    pairingSecret: "fixture-secret-1",
    metadata: { type: "text", mime: "text/plain", origin: "laptop", ts: 1_800_000_000_004 },
    plaintext: new Uint8Array(0),
    nonce: nonceOf(150),
  },
];

const proofInputs = [
  {
    name: "proof-ascii",
    pairingSecret: "fixture-secret-1",
    challenge: "challenge-123",
    deviceId: "device-abc",
  },
  {
    name: "proof-unicode",
    pairingSecret: "paîring-🔑-secret",
    challenge: "chällenge-456",
    deviceId: "phone-📱",
  },
];

const payloadVectors = await Promise.all(
  payloadInputs.map(async (input) => ({
    name: input.name,
    pairingSecret: input.pairingSecret,
    plaintextBase64: Buffer.from(input.plaintext).toString("base64"),
    frame: await encryptPayload(input.metadata, input.plaintext, input.pairingSecret, input.nonce),
  })),
);

const pairingProofVectors = await Promise.all(
  proofInputs.map(async (input) => ({
    ...input,
    proofBase64: await createPairingProof(input.pairingSecret, input.challenge, input.deviceId),
  })),
);

const outPath = new URL("crypto-fixtures.json", import.meta.url).pathname;
await Bun.write(outPath, `${JSON.stringify({ payloadVectors, pairingProofVectors }, null, 2)}\n`);
console.log(`wrote ${outPath}`);
