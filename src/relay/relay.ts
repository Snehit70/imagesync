import { verifyPairingProof } from "../shared/auth";
import { PayloadPool } from "./payload-pool";
import { encodedPayloadBytes, isPayloadFrame, type PayloadFrame, type RelayMessage } from "../shared/wire";

interface RelayOptions {
  hostname: string;
  port: number;
  pairingSecret: string;
  maxPayloadBytes: number;
  pool?: PayloadPool;
  heartbeatIntervalMs?: number;
  staleAfterMs?: number;
}

const defaultHeartbeatIntervalMs = 30_000;
const defaultStaleAfterMs = 90_000;

interface DeviceSocketData {
  challenge: string;
  authenticated: boolean;
  deviceId?: string;
  lastSeen: number;
}

type RelaySocket = Bun.ServerWebSocket<DeviceSocketData>;

export interface RelayHandle {
  url: string;
  pool: PayloadPool;
  stop(): Promise<void>;
}

export async function createRelay(options: RelayOptions): Promise<RelayHandle> {
  const pool = options.pool ?? new PayloadPool();
  const devices = new Set<RelaySocket>();
  const heartbeatIntervalMs = options.heartbeatIntervalMs ?? defaultHeartbeatIntervalMs;
  const staleAfterMs = options.staleAfterMs ?? defaultStaleAfterMs;
  const unsubscribe = pool.subscribe((frame, source) => {
    broadcast(devices, source, { v: 1, kind: "payload", frame });
  });

  // Reap sockets whose peer went away without a close frame (WiFi drop,
  // phone killed). Pings keep lastSeen fresh on healthy connections; a
  // socket that stays silent past staleAfterMs is terminated.
  const heartbeat = setInterval(() => {
    const now = Date.now();
    for (const socket of devices) {
      if (now - socket.data.lastSeen > staleAfterMs) {
        devices.delete(socket);
        socket.terminate();
        continue;
      }
      socket.ping();
    }
  }, heartbeatIntervalMs);

  const server = Bun.serve<DeviceSocketData>({
    hostname: options.hostname,
    port: options.port,
    fetch(request, bunServer) {
      if (
        bunServer.upgrade(request, {
          data: {
            challenge: randomBase64(24),
            authenticated: false,
            lastSeen: Date.now(),
          },
        })
      ) {
        return undefined;
      }
      return new Response("ImageSync relay", { status: 200 });
    },
    websocket: {
      open(socket) {
        devices.add(socket);
        send(socket, {
          v: 1,
          kind: "hello",
          challenge: socket.data.challenge,
          maxPayloadBytes: options.maxPayloadBytes,
        });
      },
      async message(socket, rawMessage) {
        socket.data.lastSeen = Date.now();
        const message = parseMessage(rawMessage);
        if (!message) {
          sendError(socket, "bad_message", "Message must be valid JSON.");
          return;
        }

        if (!socket.data.authenticated) {
          await authenticate(socket, message, options.pairingSecret, pool.current);
          return;
        }

        if (message.kind !== "publish" || !isPayloadFrame(message.frame)) {
          sendError(socket, "bad_message", "Authenticated devices may only publish payload frames.");
          return;
        }

        if (encodedPayloadBytes(message.frame) > options.maxPayloadBytes) {
          sendError(socket, "payload_too_large", `Payload exceeds ${options.maxPayloadBytes} bytes.`);
          return;
        }

        await pool.publish(message.frame, socket);
        send(socket, { v: 1, kind: "ack", ts: message.frame.ts });
      },
      pong(socket) {
        socket.data.lastSeen = Date.now();
      },
      close(socket) {
        devices.delete(socket);
      },
    },
  });

  return {
    url: `ws://${server.hostname}:${server.port}`,
    pool,
    async stop() {
      clearInterval(heartbeat);
      unsubscribe();
      server.stop(true);
      devices.clear();
    },
  };
}

async function authenticate(
  socket: RelaySocket,
  message: RelayMessage,
  pairingSecret: string,
  currentPayload: PayloadFrame | undefined,
): Promise<void> {
  if (message.kind !== "auth") {
    sendError(socket, "auth_required", "Device must authenticate before publishing or receiving payloads.");
    socket.close(1008, "auth_required");
    return;
  }

  const valid = await verifyPairingProof(pairingSecret, socket.data.challenge, message.deviceId, message.proof);
  if (!valid) {
    sendError(socket, "auth_failed", "Pairing secret proof was rejected.");
    socket.close(1008, "auth_failed");
    return;
  }

  socket.data.authenticated = true;
  socket.data.deviceId = message.deviceId;
  send(socket, { v: 1, kind: "auth_ok" });
  if (currentPayload) {
    send(socket, { v: 1, kind: "payload", frame: currentPayload });
  }
}

function broadcast(devices: Set<RelaySocket>, publisher: unknown, message: RelayMessage): void {
  for (const device of devices) {
    if (device !== publisher && device.data.authenticated) {
      send(device, message);
    }
  }
}

function send(socket: RelaySocket, message: RelayMessage): void {
  socket.send(JSON.stringify(message));
}

function sendError(socket: RelaySocket, code: string, message: string): void {
  send(socket, { v: 1, kind: "error", code, message });
}

function parseMessage(rawMessage: string | Buffer): RelayMessage | undefined {
  try {
    return JSON.parse(String(rawMessage)) as RelayMessage;
  } catch {
    return undefined;
  }
}

function randomBase64(byteLength: number): string {
  return Buffer.from(crypto.getRandomValues(new Uint8Array(byteLength))).toString("base64");
}
