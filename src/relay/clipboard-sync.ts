import type { ClipboardAdapter } from "./clipboard";
import { noopLogger, type Logger } from "./logger";
import type { PayloadPool } from "./payload-pool";
import { decryptPayload, encryptPayload } from "../shared/crypto";
import { encodedPayloadBytes } from "../shared/wire";

export interface WatchableClipboardAdapter extends ClipboardAdapter {
  watch(onChange: () => Promise<void> | void): () => void;
}

interface ClipboardSyncOptions {
  clipboard: WatchableClipboardAdapter;
  pool: PayloadPool;
  pairingSecret: string;
  origin: string;
  now(): number;
  logger?: Logger;
}

export function startClipboardSync(options: ClipboardSyncOptions): () => void {
  const logger = options.logger ?? noopLogger;
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
    logger.info("clipboard_published", {
      type: frame.type,
      mime: frame.mime,
      bytes: encodedPayloadBytes(frame),
      nonce: frame.nonce,
      frameTs: frame.ts,
    });
    const accepted = await options.pool.publish(frame, options.origin);
    if (!accepted) {
      logger.warn("payload_stale_dropped", {
        origin: "local",
        type: frame.type,
        mime: frame.mime,
        bytes: encodedPayloadBytes(frame),
        nonce: frame.nonce,
        frameTs: frame.ts,
        currentTs: options.pool.current?.ts,
      });
    }
  });

  const unsubscribe = options.pool.subscribe(async (frame, source) => {
    if (source === options.origin || frame.origin === options.origin) return;

    // The pool fans out through Promise.allSettled, which swallows listener
    // rejections — every failure must be caught and logged here.
    let data: Uint8Array;
    try {
      data = await decryptPayload(frame, options.pairingSecret);
    } catch (error) {
      logger.error("clipboard_write_failed", {
        nonce: frame.nonce,
        frameTs: frame.ts,
        stage: "decrypt",
        error: describeError(error),
      });
      return;
    }

    suppressNextChange = true;
    try {
      await options.clipboard.write({
        type: frame.type,
        mime: frame.mime,
        data,
      });
    } catch (error) {
      suppressNextChange = false;
      logger.error("clipboard_write_failed", {
        nonce: frame.nonce,
        frameTs: frame.ts,
        stage: "write",
        error: describeError(error),
      });
      return;
    }
    logger.info("clipboard_write", {
      type: frame.type,
      mime: frame.mime,
      bytes: encodedPayloadBytes(frame),
      nonce: frame.nonce,
      frameTs: frame.ts,
      e2eMs: options.now() - frame.ts,
    });
  });

  return () => {
    stopWatching();
    unsubscribe();
  };
}

function describeError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
