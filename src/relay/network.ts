import { networkInterfaces } from "node:os";

export function getLanIPv4Addresses(): string[] {
  return Object.values(networkInterfaces())
    .flatMap((entries) => entries ?? [])
    .filter((entry) => entry.family === "IPv4" && !entry.internal)
    .map((entry) => entry.address);
}

export function getPairingHost(bindHost: string): string {
  if (bindHost !== "0.0.0.0" && bindHost !== "::") return bindHost;
  return getLanIPv4Addresses()[0] ?? "127.0.0.1";
}
