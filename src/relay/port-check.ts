import { createConnection } from "node:net";

export async function ensurePortFree(host: string, port: number): Promise<void> {
  if (port === 0) return;
  const inUse = await canConnect(host, port);
  if (inUse) {
    throw new Error(`Relay port ${host}:${port} is already in use; not starting a second relay.`);
  }
}

function canConnect(host: string, port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = createConnection({ host, port });
    socket.once("connect", () => {
      socket.destroy();
      resolve(true);
    });
    socket.once("error", () => {
      socket.destroy();
      resolve(false);
    });
    socket.setTimeout(500, () => {
      socket.destroy();
      resolve(false);
    });
  });
}

