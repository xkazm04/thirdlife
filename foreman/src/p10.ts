// P10: the parts of the change path that need nothing of the Foreman's state. foreman.ts re-exports them.
//   - the fixed starts of the details and notes P10 writes (the feedback and the resume read them);
//   - the engine's `starved` verdict and `metrics.starved_stalls`, read from a report;
//   - the present values a change request is measured against.
import fs from "node:fs";
import path from "node:path";
import type { VerifyResult } from "./verifier.js";
import { listFiles, matchesAny } from "./scope.js";
import { stripBom } from "./paths.js";
import { MANIFEST_FILE } from "./manifest.js";

/** P10: the start of the `reason` and `detail` of a package re-opened because the final verification failed. */
export const FINAL_FAILED = "FINAL VERIFICATION FAILED";
/** P10: the start of the note (after FOREMAN_NOTE) of a round refused because a test of the pack failed with its files merged in. */
export const PACK_TEST_FAILED = "PACK TEST FAILED";
/** P10: the start of the note that a pack test fails with and without the round's files (not this merge's doing). */
export const PACK_TEST_NOT_MINE = "pack test fails without this merge too";
/** P10: the start of the detail and note of a run the engine itself reports as starved by the machine. */
export const STARVED = "the machine starved the run";

/**
 * P10 item 5: the runner's own verdict "starved" (RUNNER.md, "Limits count processor time"): exit 2, outcome
 * `not_run`, an error of kind `engine` whose message begins `starved:`. The machine gave the run no processor for
 * 90 s, three times. Never the pack's failure.
 */
export function isStarved(vr: VerifyResult): boolean {
  const r = vr.report;
  return !vr.ok && r !== undefined && r.outcome === "not_run" && r.errors.some((e) => e.kind === "engine" && /^starved:/.test(e.message));
}

/** The calls the machine starved during a run that still finished (`metrics.starved_stalls`, `starved_ms`). */
export function starvedStalls(vr: VerifyResult): { stalls: number; ms: number } {
  const m = (vr.report?.["metrics"] ?? {}) as { starved_stalls?: unknown; starved_ms?: unknown };
  return { stalls: typeof m.starved_stalls === "number" ? m.starved_stalls : 0, ms: typeof m.starved_ms === "number" ? m.starved_ms : 0 };
}

/**
 * P10 item 3: what a change request is measured against. The pack's declared tunable values (`params` of pack.json)
 * with the value each has NOW, then the small scalar values of every data/*.json. No model decides which of them
 * the request means: the builder sees the table and "bigger" has a scale.
 */
export function presentValuesText(packDir: string, scope: string[] = []): string {
  const readJson = (rel: string): unknown => {
    try {
      return JSON.parse(stripBom(fs.readFileSync(path.join(packDir, rel), "utf8")));
    } catch {
      return undefined;
    }
  };
  const at = (doc: unknown, dotted: string): unknown => {
    let cur: unknown = doc;
    for (const k of dotted.split(".")) {
      if (cur === null || typeof cur !== "object") return undefined;
      cur = Array.isArray(cur) ? cur[Number(k)] : (cur as Record<string, unknown>)[k];
    }
    return cur;
  };
  const show = (v: unknown): string => (v === undefined ? "(not found in the file)" : JSON.stringify(v));
  const lines: string[] = [];
  const manifest = readJson(MANIFEST_FILE) as { params?: unknown } | undefined;
  const params = Array.isArray(manifest?.params) ? (manifest.params as Record<string, unknown>[]) : [];
  const declared = new Set<string>();
  if (params.length > 0) {
    lines.push("Declared tunable values (`params` of pack.json) and what each is NOW:");
    const docs = new Map<string, unknown>();
    for (const p of params) {
      if (p === null || typeof p !== "object" || typeof p["file"] !== "string" || typeof p["path"] !== "string") continue;
      if (!docs.has(p["file"])) docs.set(p["file"], readJson(p["file"]));
      declared.add(`${p["file"]}|${p["path"]}`);
      const range = [p["min"] !== undefined ? `min ${String(p["min"])}` : "", p["max"] !== undefined ? `max ${String(p["max"])}` : "", p["step"] !== undefined ? `step ${String(p["step"])}` : ""].filter(Boolean).join(", ");
      lines.push(`- ${String(p["label"] ?? p["name"] ?? p["path"])} (\`${String(p["name"] ?? "?")}\`): \`${p["file"]}\` \`${p["path"]}\` = ${show(at(docs.get(p["file"]), p["path"]))}${range ? ` (${range})` : ""}`);
    }
  }
  const small = (v: unknown): boolean =>
    typeof v === "number" || typeof v === "boolean" || (typeof v === "string" && v.length <= 40) || (Array.isArray(v) && v.length > 0 && v.length <= 4 && v.every((x) => typeof x === "number"));
  const PER_FILE = 40;
  const TOTAL = 160;
  let total = 0;
  const dataLines: string[] = [];
  for (const f of listFiles(packDir).filter((x) => x.startsWith("data/") && x.endsWith(".json")).sort()) {
    const doc = readJson(f);
    if (doc === undefined) continue;
    const found: string[] = [];
    const walk = (v: unknown, where: string, depth: number): void => {
      if (small(v)) {
        if (where !== "" && !declared.has(`${f}|${where}`)) found.push(`${where} = ${JSON.stringify(v)}`);
        return;
      }
      if (v === null || typeof v !== "object" || depth >= 5) return;
      if (Array.isArray(v)) {
        // A long list (a layout's props, a wave table) is content, not a dial: only the first entries of a list of
        // objects are walked, and a longer list of plain values is left out.
        if (!v.some((x) => x !== null && typeof x === "object")) return;
        v.slice(0, 3).forEach((x, i) => walk(x, where === "" ? String(i) : `${where}.${i}`, depth + 1));
        return;
      }
      for (const [k, x] of Object.entries(v as Record<string, unknown>)) walk(x, where === "" ? k : `${where}.${k}`, depth + 1);
    };
    walk(doc, "", 0);
    if (found.length === 0) continue;
    const room = Math.max(0, Math.min(PER_FILE, TOTAL - total));
    if (room === 0) {
      dataLines.push(`- \`${f}\`: ${found.length} value(s), not listed (the table is full; read the file)`);
      continue;
    }
    total += Math.min(found.length, room);
    dataLines.push(`- \`${f}\`${scope.length > 0 ? (matchesAny(scope, f) ? " (yours)" : " (another package's: read only)") : ""}: ${found.slice(0, room).join("; ")}${found.length > room ? `; ... (+${found.length - room} more in the file)` : ""}`);
  }
  if (dataLines.length > 0) lines.push(`${params.length > 0 ? "Other small" : "Small"} values in the pack's data files as they are NOW (dotted path = value):`, ...dataLines);
  // Measured on the real hockey pack of 2026-11-11 (promoted 0.1.0): the puck's size was in neither place. It was a
  // literal in the owner's script (`TLKit.build("puck", {"radius": 0.15, "height": 0.08})`). So the figures written
  // in the package's OWN scripts are listed too: a number given to a named key, or a numeric constant.
  const scriptLines: string[] = [];
  const SCRIPT_LINES = 40;
  let moreInScripts = 0;
  for (const f of listFiles(packDir).filter((x) => x.endsWith(".gd") && !x.startsWith("tests/") && (scope.length === 0 || matchesAny(scope, x))).sort()) {
    const body = (() => {
      try {
        return fs.readFileSync(path.join(packDir, f), "utf8");
      } catch {
        return "";
      }
    })();
    body.split(/\r?\n/).forEach((raw, i) => {
      const code = raw.replace(/#.*$/, "").trim();
      if (code === "") return;
      const keyed = /["'][A-Za-z_][A-Za-z0-9_]*["']\s*:\s*-?\d+(\.\d+)?\b/.test(code);
      const constant = /^(const|@export\s+var)\s+[A-Za-z_][A-Za-z0-9_]*\s*(:\s*[A-Za-z0-9_]+\s*)?:?=\s*-?\d+(\.\d+)?\s*$/.test(code);
      if (!keyed && !constant) return;
      if (scriptLines.length < SCRIPT_LINES) scriptLines.push(`- \`${f}:${i + 1}\`: ${code.length > 170 ? `${code.slice(0, 170)}...` : code}`);
      else moreInScripts += 1;
    });
  }
  if (scriptLines.length > 0) {
    lines.push(
      `Figures written in ${scope.length > 0 ? "your own" : "the pack's"} scripts (they are in no data file, so nothing above shows them; when the request is about one of these, change it by the same modest step, and better: move it into a \`data/\` file of yours and declare it in \`params\`):`,
      ...scriptLines,
      ...(moreInScripts > 0 ? [`- ... (+${moreInScripts} more such lines in the scripts)`] : []),
    );
  }
  if (lines.length === 0) return "";
  return [
    "### The values as they are now",
    "A request such as \"bigger\", \"faster\" or \"darker\" is measured from these figures. Unless the player names a figure, change a value by a modest step (as a rule of thumb: up to about half as much again, or down by about a third) and stay inside a declared min and max; a value many times the present one is almost never what the player means. Say under DEVIATIONS which values you changed, from what to what.",
    ...lines,
  ].join("\n");
}

