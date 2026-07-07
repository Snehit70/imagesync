import { spawn } from "bun";
import type { PayloadType } from "../shared/wire";

export interface ClipboardPayload {
  type: PayloadType;
  mime: string;
  data: Uint8Array;
}

export interface ProcessResult {
  exitCode: number;
  stdout: Uint8Array;
  stderr: string;
}

export interface ProcessRunner {
  run(command: string, args: string[], input?: Uint8Array): Promise<ProcessResult>;
  watch(command: string, args: string[], onChange: () => void | Promise<void>): () => void;
}

export interface ClipboardAdapter {
  read(): Promise<ClipboardPayload | undefined>;
  write(payload: ClipboardPayload): Promise<void>;
  watch(onChange: () => void | Promise<void>): () => void;
}

const supportedMimeTypes: Array<{ mime: string; type: PayloadType }> = [
  { mime: "image/png", type: "image" },
  { mime: "image/jpeg", type: "image" },
  { mime: "image/webp", type: "image" },
  { mime: "text/plain", type: "text" },
  { mime: "text/plain;charset=utf-8", type: "text" },
];

export function createWaylandClipboardAdapter(runner: ProcessRunner = new BunProcessRunner()): ClipboardAdapter {
  return {
    async read() {
      const typeList = await runner.run("wl-paste", ["--list-types"]);
      ensureProcessOk(typeList, "wl-paste --list-types");
      const availableTypes = new Set(new TextDecoder().decode(typeList.stdout).split(/\r?\n/).filter(Boolean));
      const selected = supportedMimeTypes.find((candidate) => availableTypes.has(candidate.mime));
      if (!selected) return undefined;

      const read = await runner.run("wl-paste", ["--type", selected.mime]);
      ensureProcessOk(read, `wl-paste --type ${selected.mime}`);
      return {
        type: selected.type,
        mime: selected.mime,
        data: read.stdout,
      };
    },
    async write(payload) {
      const result = await runner.run("wl-copy", ["--type", payload.mime], payload.data);
      ensureProcessOk(result, `wl-copy --type ${payload.mime}`);
    },
    watch(onChange) {
      return runner.watch("wl-paste", ["--watch", "sh", "-c", "printf changed"], onChange);
    },
  };
}

class BunProcessRunner implements ProcessRunner {
  async run(command: string, args: string[], input?: Uint8Array): Promise<ProcessResult> {
    const child = spawn([command, ...args], {
      stdin: input ? "pipe" : "ignore",
      stdout: "pipe",
      stderr: "pipe",
    });

    if (input && child.stdin) {
      child.stdin.write(input);
      child.stdin.end();
    }

    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(child.stdout).arrayBuffer(),
      new Response(child.stderr).text(),
      child.exited,
    ]);

    return {
      exitCode,
      stdout: new Uint8Array(stdout),
      stderr,
    };
  }

  watch(command: string, args: string[], onChange: () => void | Promise<void>): () => void {
    const child = spawn([command, ...args], {
      stdin: "ignore",
      stdout: "pipe",
      stderr: "pipe",
    });
    const reader = child.stdout.getReader();
    let stopped = false;

    void (async () => {
      while (!stopped) {
        const chunk = await reader.read();
        if (chunk.done) return;
        await onChange();
      }
    })();

    return () => {
      stopped = true;
      child.kill();
    };
  }
}

function ensureProcessOk(result: ProcessResult, description: string): void {
  if (result.exitCode !== 0) {
    throw new Error(`${description} failed: ${result.stderr || `exit ${result.exitCode}`}`);
  }
}
