import type { Logger } from "../../src/relay/logger";

export interface CapturedEvent {
  level: "debug" | "info" | "warn" | "error";
  message: string;
  [field: string]: unknown;
}

export interface CaptureLogger {
  logger: Logger;
  events: CapturedEvent[];
  /** All captured events with the given message name. */
  named(message: string): CapturedEvent[];
  /** Polls until at least `count` events with the given message exist. */
  waitFor(message: string, count?: number): Promise<CapturedEvent[]>;
}

/** In-memory Logger that records events for assertions instead of printing. */
export function createCaptureLogger(): CaptureLogger {
  const events: CapturedEvent[] = [];
  const record =
    (level: CapturedEvent["level"]) =>
    (message: string, fields: Record<string, unknown> = {}) => {
      events.push({ level, message, ...fields });
    };

  const named = (message: string) => events.filter((event) => event.message === message);

  return {
    events,
    named,
    logger: {
      debug: record("debug"),
      info: record("info"),
      warn: record("warn"),
      error: record("error"),
    },
    async waitFor(message, count = 1) {
      const deadline = Date.now() + 2_000;
      while (named(message).length < count && Date.now() < deadline) {
        await Bun.sleep(10);
      }
      const matched = named(message);
      if (matched.length < count) {
        throw new Error(`Timed out waiting for ${count}x "${message}"; saw ${matched.length}.`);
      }
      return matched;
    },
  };
}
