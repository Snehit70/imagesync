import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface RelayConfig {
  pairingSecret: string;
  port: number;
  maxPayloadBytes: number;
  deviceId: string;
  logLevel: LogLevel;
}

export const defaultRelayPort = 17321;
export const defaultMaxPayloadBytes = 25 * 1024 * 1024;

export async function loadOrCreateRelayConfig(path: string): Promise<RelayConfig> {
  try {
    return JSON.parse(await readFile(path, "utf8")) as RelayConfig;
  } catch (error) {
    if (!isMissingFile(error)) throw error;
  }

  const config: RelayConfig = {
    pairingSecret: randomSecret(),
    port: defaultRelayPort,
    maxPayloadBytes: defaultMaxPayloadBytes,
    deviceId: "laptop",
    logLevel: "info",
  };
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(config, null, 2)}\n`, { mode: 0o600 });
  return config;
}

function randomSecret(): string {
  return Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString("base64url");
}

function isMissingFile(error: unknown): boolean {
  return Boolean(error && typeof error === "object" && "code" in error && error.code === "ENOENT");
}

