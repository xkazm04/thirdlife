// Children that outlive a killed Foreman.
// A Foreman that is killed hard does not take its children with it on Windows: a builder could keep editing a
// workspace while the resumed Foreman starts another one in it. Every child is therefore written to a ledger
// file when it starts and when it ends; a Foreman that starts on the same job first kills what is left.
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { killTree, runProcess, type SpawnFn } from "./proc.js";

export const LEDGER_FILE = "children.jsonl";

interface LedgerLine {
  pid: number;
  exe?: string;
  startedAt?: number;
  exited?: boolean;
}

/** A spawn function that records every child in `file` (one JSON line at start, one at exit). */
export function ledgerSpawn(file: string, inner: SpawnFn = runProcess): SpawnFn {
  return async (req) => {
    let pid: number | undefined;
    const r = await inner({
      ...req,
      onStart: (p) => {
        pid = p;
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.appendFileSync(file, JSON.stringify({ pid: p, exe: path.basename(req.exe), startedAt: Date.now() }) + "\n");
        req.onStart?.(p);
      },
    });
    if (pid !== undefined) fs.appendFileSync(file, JSON.stringify({ pid, exited: true }) + "\n");
    return r;
  };
}

export interface ReapResult {
  killed: number[];
  /** Entries that were not killed, with the reason (gone already, or not provably ours). */
  skipped: { pid: number; why: string }[];
}

/**
 * Kills the children a dead Foreman left behind. A pid is killed only if a process with that pid still exists,
 * has the recorded image name and was created within ten seconds of the recorded start: a reused pid is never
 * touched. The identity check is implemented for Windows; elsewhere nothing is killed and the entries are reported.
 */
export function reapOrphans(file: string): ReapResult {
  const res: ReapResult = { killed: [], skipped: [] };
  if (!fs.existsSync(file)) return res;
  const open = new Map<number, LedgerLine>();
  for (const line of fs.readFileSync(file, "utf8").split("\n")) {
    if (!line.trim()) continue;
    try {
      const l = JSON.parse(line) as LedgerLine;
      if (l.exited) open.delete(l.pid);
      else open.set(l.pid, l);
    } catch {
      /* a torn line: ignore */
    }
  }
  if (open.size > 0) {
    if (process.platform !== "win32") {
      for (const pid of open.keys()) res.skipped.push({ pid, why: "identity check is only implemented on Windows" });
    } else {
      const root = process.env["SystemRoot"] ?? process.env["windir"] ?? "C:\\Windows";
      const powershell = path.join(root, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
      const filter = [...open.keys()].map((p) => `ProcessId=${p}`).join(" OR ");
      const script = `Get-CimInstance Win32_Process -Filter '${filter}' | ForEach-Object { "$($_.ProcessId)|$($_.Name)|$($_.CreationDate.ToUniversalTime().ToString('o'))" }`;
      const ps = spawnSync(powershell, ["-NoProfile", "-NonInteractive", "-Command", script], { encoding: "utf8", windowsHide: true, timeout: 30_000 });
      const alive = new Map<number, { name: string; created: number }>();
      for (const row of (ps.stdout ?? "").split(/\r?\n/)) {
        const [p, name, created] = row.trim().split("|");
        if (p && name && created) alive.set(Number(p), { name, created: Date.parse(created) });
      }
      for (const [pid, l] of open) {
        const a = alive.get(pid);
        if (!a) res.skipped.push({ pid, why: "no longer running" });
        else if (a.name.toLowerCase() !== (l.exe ?? "").toLowerCase()) res.skipped.push({ pid, why: `pid now belongs to ${a.name}` });
        else if (Math.abs(a.created - (l.startedAt ?? 0)) > 10_000) res.skipped.push({ pid, why: "pid was reused by a later process" });
        else {
          killTree(pid);
          res.killed.push(pid);
        }
      }
    }
  }
  fs.writeFileSync(file, "");
  return res;
}
