// The single spawn door. No shell, ever: an executable and an argument vector.
// Our own timeout, and a kill that takes the whole process tree with it.
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

export interface RunProcessRequest {
  exe: string;
  args: string[];
  cwd?: string;
  env?: NodeJS.ProcessEnv;
  /** Written to the child's stdin, which is then closed. Without it stdin is closed at once. */
  stdin?: string;
  timeoutMs: number;
  /** Stop keeping output beyond this many bytes per stream (the tail is dropped, the fact is reported). */
  maxOutputBytes?: number;
  /** Called with the child's pid as soon as it exists. */
  onStart?: (pid: number) => void;
}

export interface RunProcessResult {
  /** Present only when the child exited by itself. */
  exitCode?: number;
  signal?: string;
  stdout: string;
  stderr: string;
  timedOut: boolean;
  /** Set when the process could not be started at all. */
  spawnError?: string;
  outputCapped: boolean;
  durationMs: number;
  pid?: number;
}

export type SpawnFn = (req: RunProcessRequest) => Promise<RunProcessResult>;

const live = new Set<ChildProcess>();

function systemExe(name: string): string {
  const root = process.env["SystemRoot"] ?? process.env["windir"] ?? "C:\\Windows";
  return path.join(root, "System32", name);
}

/** Kills a process and everything it started. Only ever called on pids this module spawned. */
export function killTree(pid: number): void {
  if (process.platform === "win32") {
    spawnSync(systemExe("taskkill.exe"), ["/T", "/F", "/PID", String(pid)], { stdio: "ignore", windowsHide: true });
  } else {
    try {
      process.kill(-pid, "SIGKILL");
    } catch {
      try {
        process.kill(pid, "SIGKILL");
      } catch {
        /* already gone */
      }
    }
  }
}

/** Kills every child this process still has running. Wired to exit and signals by the CLI. */
export function killAllChildren(): void {
  for (const c of live) if (c.pid !== undefined) killTree(c.pid);
  live.clear();
}

export function liveChildCount(): number {
  return live.size;
}

export const runProcess: SpawnFn = (req) =>
  new Promise<RunProcessResult>((resolve) => {
    const started = Date.now();
    const cap = req.maxOutputBytes ?? 32 * 1024 * 1024;
    const out: Buffer[] = [];
    const err: Buffer[] = [];
    let outBytes = 0;
    let errBytes = 0;
    let capped = false;
    let timedOut = false;
    let settled = false;
    let child: ChildProcess;
    const finish = (r: Partial<RunProcessResult>): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      live.delete(child);
      resolve({
        stdout: Buffer.concat(out).toString("utf8"),
        stderr: Buffer.concat(err).toString("utf8"),
        timedOut,
        outputCapped: capped,
        durationMs: Date.now() - started,
        ...(child?.pid !== undefined ? { pid: child.pid } : {}),
        ...r,
      });
    };
    let timer: NodeJS.Timeout | undefined;
    try {
      child = spawn(req.exe, req.args, {
        cwd: req.cwd,
        env: req.env ?? process.env,
        shell: false,
        windowsHide: true,
        detached: process.platform !== "win32",
        stdio: ["pipe", "pipe", "pipe"],
      });
    } catch (e) {
      resolve({
        stdout: "",
        stderr: "",
        timedOut: false,
        outputCapped: false,
        durationMs: Date.now() - started,
        spawnError: e instanceof Error ? e.message : String(e),
      });
      return;
    }
    live.add(child);
    if (child.pid !== undefined) req.onStart?.(child.pid);
    timer = setTimeout(() => {
      timedOut = true;
      if (child.pid !== undefined) killTree(child.pid);
      // If the kill itself fails the close event never comes: do not hang the caller.
      setTimeout(() => finish({}), 5000).unref();
    }, req.timeoutMs);
    child.stdout?.on("data", (d: Buffer) => {
      outBytes += d.length;
      if (outBytes <= cap) out.push(d);
      else capped = true;
    });
    child.stderr?.on("data", (d: Buffer) => {
      errBytes += d.length;
      if (errBytes <= cap) err.push(d);
      else capped = true;
    });
    child.on("error", (e) => finish({ spawnError: e.message }));
    child.on("close", (code, signal) => {
      finish({
        ...(code !== null && !timedOut ? { exitCode: code } : {}),
        ...(signal ? { signal } : {}),
      });
    });
    const stdin = child.stdin;
    if (stdin) {
      stdin.on("error", () => {
        /* the child closed its stdin early; its exit status tells the story */
      });
      if (req.stdin !== undefined) stdin.end(req.stdin, "utf8");
      else stdin.end();
    }
  });

/**
 * Resolves a command name to a real executable file without a shell. On Windows only .exe and .com count:
 * a .cmd or .bat shim would need a shell, which this module does not use.
 */
export function resolveExe(nameOrPath: string, env: NodeJS.ProcessEnv = process.env): string | undefined {
  const win = process.platform === "win32";
  const exts = win ? [".exe", ".com"] : [""];
  const isFile = (p: string): boolean => {
    try {
      return fs.statSync(p).isFile();
    } catch {
      return false;
    }
  };
  const candidates = (base: string): string[] => {
    if (!win) return [base];
    const lower = base.toLowerCase();
    return exts.some((e) => lower.endsWith(e)) ? [base] : exts.map((e) => base + e);
  };
  if (path.isAbsolute(nameOrPath) || nameOrPath.includes("/") || nameOrPath.includes("\\")) {
    for (const c of candidates(path.resolve(nameOrPath))) if (isFile(c)) return c;
    return undefined;
  }
  const pathVar = env["PATH"] ?? env["Path"] ?? "";
  for (const dir of pathVar.split(path.delimiter)) {
    if (!dir) continue;
    for (const c of candidates(path.join(dir, nameOrPath))) if (isFile(c)) return c;
  }
  return undefined;
}
