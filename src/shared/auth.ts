import { timingSafeEqual as nodeTimingSafeEqual } from "node:crypto";
import type { RelayMessage } from "./wire";

const textEncoder = new TextEncoder();

export async function createPairingProof(
  pairingSecret: string,
  challenge: string,
  deviceId: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    textEncoder.encode(pairingSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, textEncoder.encode(`${challenge}:${deviceId}`));
  return Buffer.from(signature).toString("base64");
}

export async function verifyPairingProof(
  pairingSecret: string,
  challenge: string,
  deviceId: string,
  proof: string,
): Promise<boolean> {
  const expected = await createPairingProof(pairingSecret, challenge, deviceId);
  return timingSafeEqual(expected, proof);
}

export async function createAuthMessage(
  pairingSecret: string,
  challenge: string,
  deviceId: string,
): Promise<RelayMessage> {
  return {
    v: 1,
    kind: "auth",
    deviceId,
    proof: await createPairingProof(pairingSecret, challenge, deviceId),
  };
}

function timingSafeEqual(left: string, right: string): boolean {
  const leftBytes = Buffer.from(left);
  const rightBytes = Buffer.from(right);
  if (leftBytes.byteLength !== rightBytes.byteLength) return false;
  return nodeTimingSafeEqual(leftBytes, rightBytes);
}
