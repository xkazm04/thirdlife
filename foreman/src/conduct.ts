// What a builder did and said: kit figures, stated deviations, tool use. Pure functions; moved out of foreman.ts in
// P10b, which re-exports them.
import fs from "node:fs";
import path from "node:path";
import { listFiles } from "./scope.js";

/**
 * The start of a `note` the Foreman writes itself (a fallback of the critic's round, a stated kit reason, the
 * pictures after a change). Builders' own notes (their DEVIATIONS) do not start with it; only those are handed to
 * the builders of dependent packages.
 */
export const FOREMAN_NOTE = "[foreman] ";

/** The figures a round may not make worse without saying why (N3 item 3). */
export interface KitFigures {
  /** `composability.bypasses.length` of the pack's lint report: places that do by hand what a primitive exists for. */
  bypasses: number;
  /**
   * Kit parts used, counted by the Foreman because the lint report has no such figure: `"kind": "..."` entries in
   * the pack's data/*.json (layout props and actors) plus `TLKit.` / `TLRigs.` call sites in its scripts.
   */
  kitUse: number;
}

/** Counts kit use in a pack directory (see KitFigures.kitUse). Comments in scripts do not count. */
export function countKitUse(packDir: string): number {
  let n = 0;
  for (const f of listFiles(packDir)) {
    const abs = path.join(packDir, f);
    if (f.startsWith("data/") && f.endsWith(".json")) n += (fs.readFileSync(abs, "utf8").match(/"kind"\s*:\s*"/g) ?? []).length;
    else if (f.endsWith(".gd") && !f.startsWith("tests/")) {
      for (const line of fs.readFileSync(abs, "utf8").split(/\r?\n/)) n += (line.replace(/#.*$/, "").match(/\bTL(Kit|Rigs)\s*\./g) ?? []).length;
    }
  }
  return n;
}

/** True when a builder's DEVIATIONS text says why kit use fell or a bypass was added (a `KIT:` line, or plain words). */
export function statesKitReason(deviations: string | undefined, hints: string[] = []): boolean {
  if (!deviations) return false;
  if (/^\s*[-*]?\s*\**KIT\**\s*:/im.test(deviations)) return true;
  if (/\b(kit|bypass\w*|TLKit|TLRigs|by hand|hand[- ]built|hand[- ]made|kernel primitive)\b/i.test(deviations)) return true;
  return hints.some((h) => h.length >= 4 && deviations.toLowerCase().includes(h.toLowerCase()));
}

/**
 * The deviations a builder states in its answer: everything under a line `DEVIATIONS:` up to a `QUESTION:` line or
 * the end. "none" (or nothing) means there are none.
 */
export function parseDeviations(text: string | undefined): string | undefined {
  if (!text) return undefined;
  const lines = text.split(/\r?\n/);
  let start = -1;
  let first = "";
  for (let i = 0; i < lines.length; i++) {
    const m = /^[\s#>*_-]*DEVIATIONS\**\s*:?\**\s*(.*)$/.exec(lines[i] as string);
    if (m) {
      start = i;
      first = m[1] ?? "";
    }
  }
  if (start < 0) return undefined;
  const body = [first];
  for (let i = start + 1; i < lines.length; i++) {
    if (/^\s*QUESTION:/.test(lines[i] as string)) break;
    body.push(lines[i] as string);
  }
  const out = body.join("\n").trim();
  if (out === "" || /^[-*\s]*(none|no deviations?|nothing|n\/a)[.!]?\s*$/i.test(out)) return undefined;
  return clip(out, 4000);
}

export function clip(s: string, n: number): string {
  return s.length <= n ? s : `${s.slice(0, n)}\n... (${s.length - n} more characters cut)`;
}

/**
   * What a builder did with its tools, read from the adapter's envelope (claude-cli stream-json events): how often
   * each tool was used, the shell commands it ran, and what the permission system refused. Evidence for the report
   * and the site, never an input to a verdict.
   */
export function builderConduct(raw: unknown): { tools: Record<string, number>; bash: string[]; denials: string[]; notes: string[] } {
  const out = { tools: {} as Record<string, number>, bash: [] as string[], denials: [] as string[], notes: [] as string[] };
  const events = (raw as { events?: unknown } | null)?.events;
  if (!Array.isArray(events)) return out;
  for (const ev of events as Record<string, unknown>[]) {
    if (ev?.["type"] === "assistant") {
      const content = (ev["message"] as { content?: unknown } | undefined)?.content;
      if (!Array.isArray(content)) continue;
      for (const c of content as Record<string, unknown>[]) {
        if (c?.["type"] !== "tool_use" || typeof c["name"] !== "string") continue;
        out.tools[c["name"]] = (out.tools[c["name"]] ?? 0) + 1;
        const cmd = (c["input"] as { command?: unknown } | undefined)?.command;
        if (c["name"] === "Bash" && typeof cmd === "string") out.bash.push(cmd.length > 600 ? `${cmd.slice(0, 600)}...` : cmd);
      }
    } else if (ev?.["type"] === "result" && Array.isArray(ev["permission_denials"])) {
      for (const d of ev["permission_denials"] as Record<string, unknown>[]) {
        const input = d?.["tool_input"] as Record<string, unknown> | undefined;
        const what = typeof input?.["command"] === "string" ? input["command"] : typeof input?.["file_path"] === "string" ? input["file_path"] : "";
        out.denials.push(`${String(d?.["tool_name"] ?? "?")}: ${String(what).slice(0, 300)}`);
      }
    }
  }
  return out;
}
