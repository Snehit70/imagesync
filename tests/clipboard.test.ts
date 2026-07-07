import { describe, expect, test } from "bun:test";
import { createWaylandClipboardAdapter, type ProcessRunner } from "../src/relay/clipboard";

class FakeRunner implements ProcessRunner {
  calls: Array<{ command: string; args: string[]; input?: Uint8Array }> = [];
  watches: Array<{ command: string; args: string[] }> = [];
  outputs = new Map<string, Uint8Array>();
  onWatchChange: (() => void | Promise<void>) | undefined;

  async run(command: string, args: string[], input?: Uint8Array) {
    this.calls.push(input ? { command, args, input } : { command, args });
    const key = [command, ...args].join(" ");
    return {
      exitCode: 0,
      stdout: this.outputs.get(key) ?? new Uint8Array(),
      stderr: "",
    };
  }

  watch(command: string, args: string[], onChange: () => void | Promise<void>) {
    this.watches.push({ command, args });
    this.onWatchChange = onChange;
    return () => {
      this.onWatchChange = undefined;
    };
  }
}

describe("Wayland clipboard adapter", () => {
  test("writes text payloads with wl-copy", async () => {
    const runner = new FakeRunner();
    const clipboard = createWaylandClipboardAdapter(runner);
    const data = new TextEncoder().encode("paste me");

    await clipboard.write({ type: "text", mime: "text/plain", data });

    expect(runner.calls).toEqual([
      {
        command: "wl-copy",
        args: ["--type", "text/plain"],
        input: data,
      },
    ]);
  });

  test("reads the first supported clipboard payload type", async () => {
    const runner = new FakeRunner();
    runner.outputs.set(
      "wl-paste --list-types",
      new TextEncoder().encode("application/octet-stream\nimage/png\ntext/plain\n"),
    );
    runner.outputs.set("wl-paste --type image/png", new Uint8Array([137, 80, 78, 71]));
    const clipboard = createWaylandClipboardAdapter(runner);

    await expect(clipboard.read()).resolves.toEqual({
      type: "image",
      mime: "image/png",
      data: new Uint8Array([137, 80, 78, 71]),
    });
  });

  test("watches clipboard changes with wl-paste", async () => {
    const runner = new FakeRunner();
    const clipboard = createWaylandClipboardAdapter(runner);
    let changes = 0;

    const stop = clipboard.watch(() => {
      changes += 1;
    });
    await runner.onWatchChange?.();
    stop();

    expect(runner.watches).toEqual([
      {
        command: "wl-paste",
        args: ["--watch", "sh", "-c", "printf changed"],
      },
    ]);
    expect(changes).toBe(1);
    expect(runner.onWatchChange).toBeUndefined();
  });
});
