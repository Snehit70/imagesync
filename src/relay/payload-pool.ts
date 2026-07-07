import type { PayloadFrame } from "../shared/wire";

export type PoolListener = (frame: PayloadFrame, source: unknown) => void | Promise<void>;

export class PayloadPool {
  #current: PayloadFrame | undefined;
  #listeners = new Set<PoolListener>();

  get current(): PayloadFrame | undefined {
    return this.#current;
  }

  async publish(frame: PayloadFrame, source?: unknown): Promise<boolean> {
    if (this.#current && frame.ts < this.#current.ts) {
      return false;
    }

    this.#current = frame;
    await Promise.allSettled(
      Array.from(this.#listeners, (listener) => Promise.resolve().then(() => listener(frame, source))),
    );
    return true;
  }

  subscribe(listener: PoolListener): () => void {
    this.#listeners.add(listener);
    return () => {
      this.#listeners.delete(listener);
    };
  }
}
