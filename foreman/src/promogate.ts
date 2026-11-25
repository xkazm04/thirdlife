// H1d of 25 Nov (lane G1's Arsenal job, events 354 to 363): v0.1.3 was promoted although all eight of its promotion
// pictures reported `ok: false`: in a window the skin's commentary throws a script error ("rink audio: no voice for
// commentary line 'faceoff.drop.04'") that the headless checks never meet. A promotion picture is the game in a window,
// as a person meets it: one that reports a script error refuses the promotion, in words. A picture that failed for
// another reason (the graphics driver, no file) says nothing about the pack and is only left out, as before.
import fs from "node:fs";
import type { GateHost } from "./p10gate.js";

interface ShotReport {
  checks?: { id?: string; ok?: boolean; detail?: string }[];
  errors?: { kind?: string; file?: string; line?: number; message?: string }[];
}

/**
 * The script errors the pictures of one promotion (`label`, e.g. "promotion4") reported, in words; undefined when none
 * did. Reads the capture `verify` events of this label and their reports.
 */
export function promotionErrors(h: Pick<GateHost, "events" | "dir">, label: string): string | undefined {
  const shots = new Map<string, string[]>();
  for (const e of h.events) {
    if (e.type !== "verify" || e.verb !== "capture" || e.ok || !e.report.includes(`/${label}-capture-`)) continue;
    let r: ShotReport;
    try {
      r = JSON.parse(fs.readFileSync(h.dir(...e.report.split("/")), "utf8")) as ShotReport;
    } catch {
      continue;
    }
    const errs = (r.errors ?? []).filter((x) => x.kind === "script_error").map((x) => `${(x.message ?? "a script error").replace(/\s*\[frame \d+\]$/, "")}${x.file !== undefined ? ` (${x.file}${x.line !== undefined ? `:${x.line}` : ""})` : ""}`);
    const failedCheck = (r.checks ?? []).some((c) => c.id === "smoke.no_script_errors" && c.ok === false);
    if (errs.length === 0 && !failedCheck) continue;
    const shot = /\/(promotion\d+-capture-.+?)-s\d+\.json$/.exec(e.report)?.[1] ?? e.report;
    shots.set(shot, errs.length > 0 ? errs : ["a script error"]);
  }
  if (shots.size === 0) return undefined;
  const all = [...new Set([...shots.values()].flat())];
  const pictures = h.events.filter((e) => e.type === "verify" && e.verb === "capture" && e.report.includes(`/${label}-capture-`)).map((e) => (e.type === "verify" ? /\/(promotion\d+-capture-.+?)-s\d+\.json$/.exec(e.report)?.[1] : undefined)).filter(Boolean);
  const n = new Set(pictures).size;
  return `in a window, as a person plays it, the game throws script errors in ${shots.size} of ${n} promotion picture(s): ${all.slice(0, 3).join("; ")}${all.length > 3 ? `; and ${all.length - 3} more` : ""}. The headless checks do not meet them, so they passed. A version that errors in front of the player is not promoted`;
}
