import type { ClipboardAdapter } from "./clipboard";
import type { PayloadPool } from "./payload-pool";
import { decryptPayload, encryptPayload } from "../shared/crypto";

export interface WatchableClipboardAdapter extends ClipboardAdapter {
  watch(onChange: () => Promise<void> | void): () => void;
}

interface ClipboardSyncOptions {
  clipboard: WatchableClipboardAdapter;
  pool: PayloadPool;
  pairingSecret: string;
  origin: string;
  now(): number;
}

export function startClipboardSync(options: ClipboardSyncOptions): () => void {
  let suppressNextChange = false;

  const stopWatching = options.clipboard.watch(async () => {
    if (suppressNextChange) {
      suppressNextChange = false;
      return;
    }

    const payload = await options.clipboard.read();
    if (!payload) return;

    const frame = await encryptPayload(
      {
        type: payload.type,
        mime: payload.mime,
        origin: options.origin,
        ts: options.now(),
      },
      payload.data,
      options.pairingSecret,
    );
    await options.pool.publish(frame, options.origin);
  });

  const unsubscribe = options.pool.subscribe(async (frame, source) => {
    if (source === options.origin || frame.origin === options.origin) return;
    const data = await decryptPayload(frame, options.pairingSecret);
    suppressNextChange = true;
    await options.clipboard.write({
      type: frame.type,
      mime: frame.mime,
      data,
    });
  });

  return () => {
    stopWatching();
    unsubscribe();
  };
}
